# ARRISE DevOps Terraform Assignment

This README is the runbook I would follow from a fresh checkout. It explains the order of deployment, the AWS access needed, the local values to change, and the commands to run. The stacks create real AWS resources and can incur charges, so review every plan before applying it.

## 1. What this repository creates

The repository has four Terraform stacks:

1. `bootstrap/` creates the S3 bucket and DynamoDB table used for remote state.
2. `ec2/` launches five EC2 instances from one input map. `critical-prod-01` has `prevent_destroy`.
3. `platform/` creates the S3 buckets, ECR repository, and ECS service used by the CI policy.
4. `iam/` creates the requested users, groups, roles, trust policies, and CI permissions in Account A and Account B.

The Account B S3 bucket is included in the platform Terraform. Use credentials that are authorized to create and configure that bucket in Account B. The required access is summarized in section 3. If permissions are restricted by a permissions boundary or organization policy, the account administrator must make sure the Terraform identity is allowed to perform the required actions.

The sample Fargate service starts with desired count zero, so no Fargate tasks run until you scale it up. The sample task definition uses a public NGINX image as a placeholder; replace it with your application image before running the service.

## 2. Before you start

Install and verify:

- Terraform `>= 1.9.0, < 2.0.0`
- AWS CLI
- Two AWS accounts and non-root deployment identities with appropriate permissions
- Access to the AWS regions where you plan to create resources

The example provider profiles are `default` for Account A and `account-b` for Account B. Configure them locally; never put access keys in Terraform files, `.tfvars`, backend files, or this README.

```powershell
aws configure --profile default
aws configure --profile account-b
aws sts get-caller-identity --profile default
aws sts get-caller-identity --profile account-b
```

Check that the `Account` values are different and record them. Use IAM users or assumed roles with the required deployment permissions—not root credentials.

### Permissions needed by the Terraform operator

The Account A identity needs permission to manage the resources in the bootstrap, EC2, IAM, and platform stacks, including S3 state, DynamoDB locking, EC2, IAM users/groups/roles/policies, ECR, ECS, and CloudWatch Logs. The Account B identity needs permission to create and configure the roleC target bucket and to manage roleC and its inline policy. AWS Organizations SCPs and permissions boundaries must not prohibit these actions. The operator does not need to receive the permissions being created for the `ci`, `engine`, or group2 users.

### Bucket names and account-specific values

S3 bucket names are globally unique. Before running the stacks, choose two unused names: one in Account A for CI artifacts and one in Account B for roleC. Names such as `arrise-ci-artifacts-<account-a-id>-<region>` and `arrise-rolec-data-<account-b-id>-<region>` are a useful pattern. Set the same names in `iam/terraform.tfvars` and `platform/terraform.tfvars`. Keep `account_a_id` and `account_b_id` consistent with the profile identity results.

## 3. Set up the stacks

Run each command from the repository root in PowerShell. Copy example `.tfvars` files only when the instructions below request them. These local files are Git-ignored.

### Step 1 — Create remote-state resources

The backend cannot create itself, so bootstrap uses local state:

```powershell
Copy-Item .\bootstrap\terraform.tfvars.example .\bootstrap\terraform.tfvars
notepad .\bootstrap\terraform.tfvars
```

Set `state_bucket_name` to an unused, globally unique bucket name and confirm the region. Then run:

```powershell
Set-Location .\bootstrap
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform output
Set-Location ..
```

Save the output bucket name, DynamoDB table name, and region. Keep `bootstrap/terraform.tfstate` secure; it is the local state for the resources that protect other stacks' remote state.

### Step 2 — Prepare EC2 networking and key pairs

The EC2 stack needs an existing subnet and security group, and five EC2 key pairs in the same region. You can use existing key pairs or create five and import their public keys. If those key pairs do not already exist, this PowerShell loop creates local OpenSSH key files and imports the public keys to Account A. `ssh-keygen` prompts for a private-key passphrase. Keep the private key files private; `ec2/keys/` is Git-ignored.

```powershell
New-Item -ItemType Directory -Force .\ec2\keys | Out-Null
$names = @("critical-prod-key", "app-stage-key", "database-prod-key", "worker-dev-key", "batch-test-key")
foreach ($name in $names) {
    ssh-keygen -q -t ed25519 -C $name -f ".\ec2\keys\$name"
    aws ec2 import-key-pair --key-name $name --public-key-material "fileb://ec2/keys/$name.pub" --profile default --region us-east-1
}
```

Find a subnet and security group in Account A:

```powershell
aws ec2 describe-subnets --profile default --region us-east-1 --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone}" --output table
aws ec2 describe-security-groups --profile default --region us-east-1 --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" --output table
```

Copy and edit the EC2 values:

```powershell
Copy-Item .\ec2\terraform.tfvars.example .\ec2\terraform.tfvars
notepad .\ec2\terraform.tfvars
```

Set `aws_profile`, `aws_region`, `subnet_id`, and `security_group_ids` to match Account A. Keep all five instance map entries, five distinct instance types and sizes, and five key names. Choose instance types and sizes supported by your account and budget. The deployed sample uses `gp2`, `gp3`, and `standard` volumes because this account rejected `io1`/`io2` under its Free Tier launch restriction; this is a documented deviation from the original volume requirements in [NOTES.md](./NOTES.md). Free Tier eligibility does not guarantee that the resources will be free.

### Step 3 — Configure and initialize the EC2 remote backend

Create a local backend file using the values from Step 1. Backend configuration is not a normal Terraform input and should not contain AWS secrets.

```powershell
@'
bucket         = "REPLACE_WITH_BOOTSTRAP_BUCKET"
key            = "arrise-assignment/ec2/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "arrise-terraform-locks"
encrypt        = true
'@ | Set-Content .\ec2\backend.hcl
```

Initialize, inspect, and apply:

```powershell
Set-Location .\ec2
terraform init -backend-config="backend.hcl"
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform output -json instance_ids
terraform output -json private_ips
Set-Location ..
```

Review the plan before applying. `critical-prod-01` has `prevent_destroy`; Terraform will refuse a plan that destroys or replaces it while that lifecycle rule remains in the configuration.

### Step 4 — Set the account IDs and bucket names for IAM

Copy the IAM example and edit it:

```powershell
Copy-Item .\iam\terraform.tfvars.example .\iam\terraform.tfvars
notepad .\iam\terraform.tfvars
```

Set these values:

- `account_a_profile` and `account_a_id` from the Account A identity check.
- `account_b_profile` and `account_b_id` from the Account B identity check.
- `artifact_bucket` to the unused Account A artifact bucket name.
- `target_s3_bucket` to the unused Account B roleC bucket name.
- ECR repository, ECS cluster, service, and task family names to the platform values in Step 5.
- `ecs_task_role_arns` to the task execution role ARN created in Step 5.

Do not use the example account IDs or bucket names without checking and replacing them for your environment.

### Step 5 — Create the S3, ECR, and ECS resources

The platform stack uses a separate remote-state key. Create its local backend file using the bootstrap bucket:

```powershell
@'
bucket         = "REPLACE_WITH_BOOTSTRAP_BUCKET"
key            = "arrise-assignment/platform/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "arrise-terraform-locks"
encrypt        = true
'@ | Set-Content .\platform\backend.hcl
```

Copy and edit the platform example so its profiles, account IDs, bucket names, subnets, and security group match your environment:

```powershell
Copy-Item .\platform\terraform.tfvars.example .\platform\terraform.tfvars
notepad .\platform\terraform.tfvars
```

Replace both example subnet IDs with public subnets in different availability zones and replace the security group ID with one from Account A. These identifiers are account-specific; do not assume the example values exist in your accounts.

Then run:

```powershell
Set-Location .\platform
terraform init -backend-config="backend.hcl"
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform output
Set-Location ..
```

This creates the CI artifacts bucket in Account A, roleC's target bucket in Account B, ECR repository, ECS cluster and service, task definition, and task execution role. The S3 buckets are versioned, encrypted, and blocked from public access. The ECS service is created with zero tasks. Review its network configuration and use a workload-specific security group before increasing its desired count.

Copy the `ecs_task_execution_role_arn` output into `ecs_task_role_arns` in `iam/terraform.tfvars`.

### Step 6 — Apply the IAM configuration

Run IAM after the resources from Step 5 exist:

```powershell
Set-Location .\iam
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform output
Set-Location ..
```

The IAM stack uses local state in this assignment. Protect that state file and do not commit it. For team use, configure a remote backend for this stack as a separate change.

## 4. Test cross-account role assumption

After the IAM apply, configure a local AWS profile for the `engine` user using the organization's approved credential process. Do not put credentials in this README or source files. Add role profiles to `%USERPROFILE%\.aws\config`, replacing account IDs if your accounts differ:

```ini
[profile account-a-engine]
# Configure this profile's source credentials securely outside this file.

[profile role-b-session]
role_arn = arn:aws:iam::ACCOUNT_A_ID:role/roleB
source_profile = account-a-engine
role_session_name = arrise-roleb-test

[profile role-c-session]
role_arn = arn:aws:iam::ACCOUNT_B_ID:role/roleC
source_profile = role-b-session
role_session_name = arrise-rolec-test
```

Verify the resulting caller and the bucket access:

```powershell
aws sts get-caller-identity --profile role-b-session
aws sts get-caller-identity --profile role-c-session
aws s3 ls s3://YOUR_ROLEC_BUCKET --profile role-c-session
```

The final caller identity should be roleC in Account B. RoleC is scoped to its configured bucket and objects; it should not be able to access unrelated buckets.

## 5. Check formatting and validation

Run formatting and validation from the repository root and each stack directory:

```powershell
terraform fmt -check -recursive
foreach ($stack in @("bootstrap", "ec2", "platform", "iam")) {
    terraform -chdir="$PWD\$stack" validate
}
```

For a fresh checkout, initialize each stack before validating it. `ec2/` and `platform/` require their backend configuration files. Optional checks include `tflint` and `checkov`.

## 6. Costs and cleanup

EC2 instances, EBS volumes, ECR image storage, S3 storage, CloudWatch Logs, and Fargate tasks can incur charges. The ECS service starts at zero tasks; scaling it up starts compute charges. Check current AWS pricing and review every plan before applying.

Destroy in this order only when you intend to delete the deployment:

1. `iam/` (remove IAM roles, users, and policies).
2. `platform/` (delete ECS/ECR and the target buckets after removing their contents).
3. `ec2/` (the protected `critical-prod-01` prevents destroy until you intentionally remove its lifecycle protection).
4. `bootstrap/` last, after no other stack uses its state bucket or lock table.

S3 buckets must be empty before Terraform can delete them. Back up state before cleanup.

## 7. Security notes

- `.tfvars`, backend files, Terraform state, `.terraform/`, and private key files are excluded by `.gitignore`.
- Never commit AWS credentials or generated user secrets.
- The group2 initial credentials are stored in Secrets Manager in the deployment environment; retrieve them only with authorized access, reset console passwords at first sign-in, and rotate access keys.
- roleC trusts only roleB and has S3 permissions scoped to one bucket.
- The CI policy scopes ECR, ECS, S3, and `iam:PassRole` permissions to the configured resources.
- roleA has the broad exception policy requested by the assignment (`NotAction = ["iam:*"]`); keep assumption of that role tightly controlled.
- Read [NOTES.md](./NOTES.md) for design decisions and assignment limitations.
