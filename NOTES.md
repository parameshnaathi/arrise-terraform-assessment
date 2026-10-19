## Task 1 — Multi-instance EC2 provisioning

### 1.a Protected instance and `prevent_destroy`

I chose `critical-prod-01` for `prevent_destroy` because it represents the production instance in this configuration. Terraform does not let me turn `prevent_destroy` on for only one instance inside a single `for_each` resource. I use two generic EC2 resources instead: one for the protected instance and one for the other four. Both resources get their settings from the same input map.

### 1.b Instance configuration and volume limitation

The configuration checks that there are five instances and that each has a different instance type, volume size, and key pair. The EC2 instances are running, but their volume types are not all different. AWS rejected `io1` and `io2` volumes under the account's Free Tier launch restriction, so I used `gp2`, `gp3`, and `standard` volumes instead. This means the deployed configuration does not meet the original `io1`/`io2` or unique-volume-type requirements. I have kept the reason clear rather than suggesting those requirements were met.

## Task 2 — Remote state and locking

### 2.a Local state risk

If two people apply Terraform from separate local state files, neither person's state records the other's changes. Their plans can be based on old information, which can lead to conflicting updates or unexpected infrastructure changes. For shared work, I use a shared state location and state locking.

### 2.b S3 remote state

I created the backend bucket in a separate bootstrap stack because Terraform needs a backend to exist before it can use that backend. The bucket has versioning, encryption, and public access blocked. The EC2 stack stores its state in a separate key in this bucket. Backend settings are supplied when Terraform is initialized, rather than through ordinary Terraform variables.

The IAM stack still uses local state. The EC2 remote backend does not protect the IAM stack's state, so that state should be stored and shared securely before using the stack as a team.

### 2.c DynamoDB locking

The bootstrap stack creates a DynamoDB table with a string partition key called `LockID`. Terraform uses it to prevent two operations on the shared state from running at the same time. I kept DynamoDB locking because it is specifically required by the assignment.

## Task 3 — Multi-account IAM and cross-account access

### 3.a IAM users and credential approach

I would avoid permanent IAM user access keys for people or CI in a production setup. Keys can be copied or exposed, and they remain usable until they are disabled or rotated. I would normally use IAM Identity Center for people and temporary role credentials or OIDC federation for workloads and CI.

For this assignment, I created the requested IAM users. I also created initial console passwords and CLI access keys for `operations.admin` and `platform.admin` outside Terraform, then stored them in Account A Secrets Manager:

- `arrise-devops-assignment/group2/operations.admin`
- `arrise-devops-assignment/group2/platform.admin`

The initial console passwords require a reset at first sign-in. I have not included the secret values in this repository. Access to those Secrets Manager entries should be limited and audited; the access keys should be rotated or replaced with temporary credentials when possible.

The assignment asks for console and CLI access for group2 but does not say what AWS services those users should be allowed to use. I have not guessed at that permission level. The group has only a small self-service policy that allows its members to change their own console passwords and read the account password policy. It has no AWS service permissions.

The `engine` user can assume only `roleB`. The `ci` user has the custom CI policy described below. Neither has a Terraform-managed access key or console password.

### 3.b roleC trust: roleB instead of Account A root

An Account A root principal in a role trust policy represents the account as a whole: Account A identity policies can then delegate access to roles or users in that account. That gives administrators more flexibility, but it is a wider trust boundary.

I configured roleC to trust only the specific `roleB` role ARN in Account A. This means other Account A users are not directly trusted by roleC. The assignment's example ARN uses placeholder account IDs; the deployed roles use the actual account IDs configured for this environment.

The assignment does not say who should be allowed to assume roleB, so I chose the specifically named `engine` user. Its policy allows it to assume only roleB. Separately, roleB's own permissions allow it to assume only roleC.

## Task 4 — Least-privilege CI policy

### 4.a CI permissions and `iam:PassRole`

I attached a custom policy to `ci` for the requested deployment tasks: get an ECR login token, push images to one repository, register and read the configured task definition, update and inspect one ECS service, and read from one artifacts bucket.

ECR requires `ecr:GetAuthorizationToken` to use `"*"` for its resource. ECS task-definition registration also uses `"*"` because a new task definition does not have an existing ARN when it is registered. The other supported permissions are scoped to the configured ECR repository, ECS service or task-definition family, and S3 bucket or objects.

The platform stack creates an ECS task execution role. I included `iam:PassRole` for that exact role only, with a condition that it can be passed only to `ecs-tasks.amazonaws.com`. The policy does not allow passing arbitrary roles.

### 4.b Permissions I left out

The CI user does not have IAM administration, EC2 administration, S3 write or delete, ECR repository deletion, ECS cluster deletion, arbitrary role assumption, or unrestricted `iam:PassRole`. I used a wildcard resource only where the AWS action or assignment requires it: ECR login-token retrieval, task-definition registration, and the specifically requested roleA policy that excludes IAM actions.

## Task 5 — Find and fix the supplied bugs

### 5.a Wrong IAM principal

The broken trust policy names `arn:aws:iam::000000000000:user/roleB`. That ARN refers to a user, but `roleB` is a role. A roleC trust policy decides who is allowed to assume roleC, so the wrong principal prevents roleB from matching the trust policy. I corrected the principal to the Account A role ARN for roleB. In the deployed configuration, that ARN uses the actual Account A ID.

### 5.b Overly broad S3 access

The broken policy grants `s3:*` on `"*"`, which could apply to buckets and objects outside the assignment's target. I kept the requested full S3 action set for roleC, but restricted its resources to the target bucket ARN and that bucket's object ARN. The bucket ARN covers bucket-level actions; the `/*` ARN covers objects.

The two policies have different purposes. The roleC trust policy says **who can assume roleC**: only roleB. The roleC permissions policy says **what roleC can do after it is assumed**: use S3 actions on the configured bucket and its objects. For cross-account assumption to work, roleB also needs its own identity policy allowing `sts:AssumeRole` on roleC.

## Deployment-specific notes

- The assignment lists example account IDs `000000000000` and `111111111111`. I used the real accounts configured for this deployment: Account A `593602868022` (`default`) and Account B `795346865572` (`account-b`). If the evaluator uses different accounts, the local Terraform inputs and ARNs need to match those accounts.
- The EC2 module finds an Amazon Linux 2023 AMI through an AWS data source rather than pinning an AMI ID.
- All EC2 root volumes are encrypted. The instances use different types, sizes, and key pairs, but the volume types repeat because this account rejected the required `io1`/`io2` types under its Free Tier launch restriction.
- The EC2 resources were applied in stages after AWS rejected some initial launches. The final Terraform state contains all five instances; Terraform outputs report their IDs and private IPs.
- The group2 credentials are stored in Secrets Manager, not Terraform state. The custom group2 policy only supports password changes; it does not grant AWS service access.
- The platform stack created the Account A artifacts bucket, ECR repository, ECS cluster and service, task definition, and task execution role. The service starts with desired count zero, so it does not run Fargate tasks until scaled up. The sample task definition uses a public NGINX image as a starting point, not as the assignment's application image.
- The platform stack defines the Account B roleC target bucket and configures encryption, versioning, and public-access blocking. The identity used for the platform apply must be permitted to create and configure this bucket in Account B.
- The configured resource names are `arrise-ci-artifacts-593602868022-us-east-1`, `arrise-rolec-data-795346865572-us-east-1`, `arrise-application`, `arrise-cluster`, `arrise-service`, and `arrise-task`. The platform stack stores state at `arrise-assignment/platform/terraform.tfstate`.
