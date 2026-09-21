# Terraform Lab Guide (Create → Verify in AWS → Destroy)

This guide is for learning Terraform **one step at a time** in your repo.

---

## 1) Lab approach (safe)

Use separate folders per lab so you only create a small set of resources.

```text
terraform-labs/
└── 01-ecr/
    ├── provider.tf
    ├── variables.tf
    ├── ecr.tf
    └── outputs.tf
```

For each lab, use this cycle:

```text
Write .tf
→ terraform init
→ terraform fmt
→ terraform validate
→ terraform plan
→ terraform apply
→ verify in AWS Console
→ terraform destroy
```

---

## 2) Lab 01: ECR only

### Step A: create files in `terraform-labs/01-ecr`

### `provider.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
```

### `variables.tf`

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "Local AWS profile"
  type        = string
  default     = "devops-local"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "devops-nestjs-app"
}
```

### `ecr.tf`

```hcl
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
```

### `outputs.tf` (optional)

```hcl
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}
```

---

## 3) Run commands (`cmd.exe`)

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\01-ecr
terraform init
terraform fmt
terraform validate
terraform plan -out tfplan
```

If ECR **already exists** in AWS, import first:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\01-ecr
terraform import aws_ecr_repository.app devops-nestjs-app
terraform plan -out tfplan
```

Apply:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\01-ecr
terraform apply tfplan
```

---

## 4) Verify in AWS Console

Go to:

```text
AWS Console → ECR → Repositories → devops-nestjs-app
```

Check:

- Repository exists
- Tag immutability = Enabled
- Scan on push = Enabled
- Encryption = AES-256

---

## 5) Destroy lab resources

If resource was **created by this lab**, destroy with:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\01-ecr
terraform destroy
```

If you imported an existing real ECR and do **not** want to delete it, do this instead:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\01-ecr
terraform state rm aws_ecr_repository.app
```

Then remove `terraform-labs/01-ecr` files if you want to reset the lab.

---

## 6) Next labs (recommended order)

```text
02-iam
03-security-groups
04-alb
05-cloudwatch
06-ecs
07-rds
08-secrets
```

Keep each lab isolated and follow the same create → verify → destroy loop.

---

## 7) Common mistakes to avoid

- Running `terraform apply` from the main `terraform/` folder when you only intended a lab
- Importing and then running `terraform destroy` on real shared resources by mistake
- Skipping `terraform plan`
- Mixing `PowerShell` syntax and `cmd` syntax in same terminal session

---

## 8) Quick checklist

- [ ] I am in the correct lab folder
- [ ] `terraform plan` looks expected
- [ ] I know whether resource is new or imported
- [ ] I verified changes in AWS Console
- [ ] I destroyed or removed state safely

---

## 9) Lab 02: IAM for GitHub Actions (OIDC + ECR + ECS + PassRole)

### Step A: create files in `terraform-labs/02-iam`

Folder already prepared:

```text
terraform-labs/02-iam/
├── provider.tf
├── variables.tf
├── iam.tf
└── outputs.tf
```

### Step B: understand what this lab creates/manages

- IAM role: `github-actions-ecr-push`
- Inline policy: `ecr-push`
- Inline policy: `ecs-deploy`
- OIDC trust for GitHub repo/branch
- `iam:PassRole` for both:
  - Terraform role names (`devops-nestjs-ecs-task-execution-role`, `devops-nestjs-ecs-task-role`)
  - Optional console-style role name (`ecsTaskExecutionRole`) only if you still use it

### Step C: Terraform file templates (manual copy/paste)

#### `provider.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
```

#### `variables.tf`

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "Local AWS profile"
  type        = string
  default     = "devops-local"
}

variable "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions OIDC"
  type        = string
  default     = "github-actions-ecr-push"
}

variable "github_owner" {
  description = "GitHub owner/org"
  type        = string
  default     = "sunny-bhakta"
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
  default     = "aws"
}

variable "github_branch" {
  description = "Allowed GitHub branch"
  type        = string
  default     = "main"
}

variable "github_owner_id" {
  description = "Optional GitHub owner id"
  type        = string
  default     = "77013204"
}

variable "github_repo_id" {
  description = "Optional GitHub repo id"
  type        = string
  default     = "1361501698"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "devops-nestjs-app"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "devops-cluster"
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "devops-nestjs-service"
}

variable "ecs_task_execution_role_name" {
  description = "Terraform-managed ECS task execution role name"
  type        = string
  default     = "devops-nestjs-ecs-task-execution-role"
}

variable "ecs_task_role_name" {
  description = "Terraform-managed ECS task role name"
  type        = string
  default     = "devops-nestjs-ecs-task-role"
}

variable "console_ecs_task_execution_role_name" {
  description = "Optional console/manual ECS task execution role name (leave empty if unused)"
  type        = string
  default     = ""
}
```

#### `iam.tf`

```hcl
data "aws_caller_identity" "current" {}

locals {
  github_oidc_provider_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  ecr_repository_arn                  = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
  ecs_service_arn                     = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  ecs_task_execution_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ecs_task_execution_role_name}"
  ecs_task_role_arn                   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ecs_task_role_name}"
  console_ecs_task_execution_role_arn = var.console_ecs_task_execution_role_name != "" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.console_ecs_task_execution_role_name}" : ""

  github_sub_plain        = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
  github_sub_ids_wildcard = "repo:${var.github_owner}@*/${var.github_repo}@*:ref:refs/heads/${var.github_branch}"
  github_sub_with_ids     = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}"

  github_sub_claims = compact([
    local.github_sub_plain,
    local.github_sub_ids_wildcard,
    local.github_sub_with_ids,
  ])
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_sub_claims
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid     = "GetAuthToken"
    effect  = "Allow"
    actions = ["ecr:GetAuthorizationToken"]

    resources = ["*"]
  }

  statement {
    sid    = "PushToRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]

    resources = [local.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecr.json
}

data "aws_iam_policy_document" "github_actions_ecs" {
  statement {
    sid    = "EcsReadForDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "UpdateService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
    ]

    resources = [local.ecs_service_arn]
  }

  statement {
    sid    = "RegisterTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PassEcsTaskRoles"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]

    resources = compact([
      local.ecs_task_execution_role_arn,
      local.ecs_task_role_arn,
      local.console_ecs_task_execution_role_arn,
    ])

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions_ecs" {
  name   = "ecs-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecs.json
}
```

#### `outputs.tf`

```hcl
output "github_actions_role_arn" {
  description = "GitHub Actions role ARN"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "GitHub Actions role name"
  value       = aws_iam_role.github_actions.name
}
```

### Step D: run commands (`cmd.exe`)

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\02-iam
terraform init
terraform fmt
terraform validate
terraform plan -out tfplan
```

If role already exists, import before apply:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\02-iam
terraform import aws_iam_role.github_actions github-actions-ecr-push
terraform plan -out tfplan
```

Apply:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\02-iam
terraform apply tfplan
```

### Step E: verify in AWS Console

Open:

```text
IAM → Roles → github-actions-ecr-push
```

Check:

- Trust relationship includes GitHub OIDC provider + repo/branch `sub`
- Inline policy `ecr-push` exists
- Inline policy `ecs-deploy` exists
- `ecs-deploy` includes:
  - `ecs:DescribeServices` on `*`
  - `ecs:UpdateService` on service ARN path
  - `iam:PassRole` with `iam:PassedToService = ecs-tasks.amazonaws.com`

### Step F: destroy options (important)

If this IAM role/policies are used by active CI/CD, **do not destroy**.

If you only want to stop Terraform tracking (keep role in AWS):

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\02-iam
terraform state rm aws_iam_role_policy.github_actions_ecr
terraform state rm aws_iam_role_policy.github_actions_ecs
terraform state rm aws_iam_role.github_actions
```

If this is a throwaway sandbox and safe to delete:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform-labs\02-iam
terraform destroy
```
