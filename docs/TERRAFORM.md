# Terraform Learning Guide — AWS NestJS Project

## 1. Goal

This guide is a practical Terraform learning path built around the AWS NestJS application you already deployed.

Your current architecture is:

```text
GitHub
   ↓
GitHub Actions
   ↓
ECR
   ↓
ECS Fargate
   ↓
ALB
   ↓
NestJS
   ↓
CloudWatch
```

The Terraform goal is eventually to manage this infrastructure as code:

```text
terraform/
├── provider.tf
├── variables.tf
├── outputs.tf
├── ecr.tf
├── iam.tf
├── vpc.tf
├── security-groups.tf
├── alb.tf
├── ecs.tf
├── cloudwatch.tf
├── rds.tf
└── secrets.tf
```

We will **not** write the whole project at once. We will build it resource by resource so you understand what Terraform is doing.

---

# 2. What Terraform Is

Terraform is an Infrastructure as Code (IaC) tool.

Instead of manually creating AWS resources in the console:

```text
AWS Console
   ↓
Create ECR
Create IAM
Create VPC
Create ALB
Create ECS
Create RDS
```

you describe the desired infrastructure in configuration files:

```text
Terraform files
      ↓
terraform plan
      ↓
terraform apply
      ↓
AWS infrastructure
```

Terraform keeps track of infrastructure in a **state**.

The basic workflow is:

| Command | Meaning |
|---|---|
| `terraform init` | Prepare Terraform |
| `terraform plan` | Show what Terraform wants to change |
| `terraform apply` | Make the changes |
| `terraform destroy` | Remove resources managed by Terraform |

---

# 3. Important Concept: Terraform Is Not AWS CLI

AWS CLI tells AWS to perform an action.

Example:

```bash
aws ecr create-repository --repository-name my-app
```

Terraform describes the desired state:

```hcl
resource "aws_ecr_repository" "app" {
  name = "my-app"
}
```

Terraform then determines whether AWS needs to create, modify, or leave the resource alone.

This is one of the most important ideas to understand.

---

# 4. Your Existing AWS Project

We will use these values throughout the learning project.

```text
AWS Region:
ap-south-1

AWS Account:
831975835566

ECR:
devops-nestjs-app

ECS Cluster:
devops-cluster

ECS Service:
devops-nestjs-service

Task Definition:
devops-nestjs-app

Container:
devops-nestjs-app

Container Port:
3000

ALB:
devops-nestjs-alb

Target Group:
devops-nestjs-tg

CloudWatch:
 /aws/ecs/devops-nestjs-app
```

---

# 5. Before Starting

## 5.1 Install Terraform

On Windows, install Terraform using the official HashiCorp installation method.

After installation, open PowerShell:

```powershell
terraform -version
```

You should see a Terraform version.

Also verify AWS CLI:

```powershell
aws --version
```

Then verify that your local AWS credentials work:

```powershell
aws sts get-caller-identity --profile devops-local
```

You should receive your AWS account and identity information.

---

# 6. Create the Terraform Project

Inside your project:

```text
aws/
├── src/
├── Dockerfile
├── package.json
├── .github/
└── terraform/
```

Create the directory:

```powershell
mkdir terraform
cd terraform
```

Initially:

```text
terraform/
```

We will gradually add files.

---

# 7. Lesson 1 — Terraform Provider

Create:

```text
terraform/provider.tf
```

Add:

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
  region = "ap-south-1"
}
```

## What does this mean?

### Terraform block

```hcl
terraform {
}
```

This contains Terraform configuration.

### Required provider

```hcl
required_providers {
  aws = {
    source = "hashicorp/aws"
  }
}
```

Terraform itself does not know how to create an AWS ECR repository or ECS service.

The AWS provider teaches Terraform how to communicate with AWS.

Conceptually:

```text
Terraform
    ↓
AWS Provider
    ↓
AWS API
```

### Provider configuration

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

This tells Terraform which AWS region to use.

---

# 8. Lesson 2 — terraform init

Run:

```powershell
terraform init
```

Terraform will download the required AWS provider.

You should see something similar to:

```text
Terraform has been successfully initialized!
```

A `.terraform` directory will appear.

You may also get:

```text
.terraform.lock.hcl
```

Do not delete the lock file casually.

It helps Terraform use consistent provider versions.

---

# 9. Lesson 3 — Your First Terraform Resource

A Terraform resource represents infrastructure.

Example:

```hcl
resource "aws_ecr_repository" "app" {
  name = "devops-nestjs-app"
}
```

There are two names here.

The AWS resource type:

```text
aws_ecr_repository
```

The Terraform local name:

```text
app
```

Together:

```text
aws_ecr_repository.app
```

This is how Terraform refers to the resource internally.

---

# 10. Very Important: Your ECR Already Exists

Your ECR repository was created manually in AWS.

Therefore, **do not immediately run**:

```bash
terraform apply
```

with:

```hcl
resource "aws_ecr_repository" "app" {
  name = "devops-nestjs-app"
}
```

Terraform would try to create a repository that already exists.

Instead, we need to teach Terraform about the existing resource.


# Import

---

# 11. Lesson 4 — Import Existing ECR

Create:

```text
terraform/ecr.tf
```

Start with:

```hcl
resource "aws_ecr_repository" "app" {
  name                 = "devops-nestjs-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
```

Now import the existing repository:

```powershell
terraform import aws_ecr_repository.app devops-nestjs-app
```

The important part is:

```text
aws_ecr_repository.app
```

This is the Terraform address.

And:

```text
devops-nestjs-app
```

is the existing AWS ECR repository identifier.

---

# 12. What Import Actually Does

Import does not create the AWS resource.

It connects:

```text
Existing AWS resource
        ↓
Terraform state
```

After import:

```text
AWS ECR
   │
   └── devops-nestjs-app
            ↑
            │
      Terraform state
            ↑
            │
       ecr.tf
```

This is a critical Terraform concept.

---

# 13. Lesson 5 — terraform plan

Now run:

```powershell
terraform plan
```

Terraform compares:

```text
Terraform configuration
        ↓
Terraform state
        ↓
Actual AWS infrastructure
```

It determines what would change.

The ideal result is little or no change if your Terraform configuration accurately represents the existing ECR configuration.

If Terraform proposes a change, **do not blindly apply it**.

Read what it wants to change.

---

# 14. The Terraform Mental Model

Always think about three things:

```text
             Terraform configuration
                     │
                     ↓
               Desired state
                     │
                     ↓
Terraform state ←→ Actual AWS infrastructure
```

Terraform is continuously trying to reconcile the desired configuration with real infrastructure.

This is why:

```bash
terraform plan
```

is so important.

---

# 15. terraform apply

Once you understand the plan:

```powershell
terraform apply
```

Terraform will display the proposed changes and ask for confirmation.

You will normally see:

```text
Do you want to perform these actions?
  Enter a value:
```

Enter:

```text
yes
```

Do not make a habit of using:

```bash
terraform apply -auto-approve
```

while learning.

Seeing and approving the plan is useful.

---

# 16. terraform state

Terraform maintains state.

Normally you will see:

```text
terraform.tfstate
```

The state contains Terraform's knowledge about managed infrastructure.

For example:

```text
aws_ecr_repository.app
```

is associated with the real AWS ECR repository.

You can inspect state:

```powershell
terraform state list
```

You should eventually see:

```text
aws_ecr_repository.app
```

You can inspect a specific resource:

```powershell
terraform state show aws_ecr_repository.app
```

---

# 17. State Is Extremely Important

Never casually delete:

```text
terraform.tfstate
```

and never commit sensitive state to a public Git repository.

Terraform state can contain infrastructure information and, depending on resources/configuration, sensitive values.

For a local learning environment:

```text
terraform.tfstate
```

should be ignored by Git.

Add to `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
.terraform.lock.hcl
```

However, the provider lock file is commonly **committed** in real Terraform projects.

A better Gitignore for this project is:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
```

Keep:

```text
.terraform.lock.hcl
```

in Git.

---

# 18. Lesson 6 — Variables

Hard-coding everything is not ideal.

Instead of:

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

we can use a variable.

Create:

```text
variables.tf
```

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}
```

Then:

```hcl
provider "aws" {
  region = var.aws_region
}
```

Terraform variable syntax:

```text
var.aws_region
```

---

# 19. Variable Files

You can create:

```text
terraform.tfvars
```

Example:

```hcl
aws_region = "ap-south-1"
```

But do not put secrets into a file that will be committed.

For this project, infrastructure configuration and secrets should eventually be handled separately.

---

# 20. Lesson 7 — Outputs

Outputs expose useful Terraform information.

Create:

```text
outputs.tf
```

Example:

```hcl
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}
```

Run:

```powershell
terraform apply
```

Then:

```powershell
terraform output
```

You may get something like:

```text
ecr_repository_url = "831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app"
```

Outputs become especially useful for:

```text
ALB DNS name
ECR repository URL
RDS endpoint
VPC ID
Subnet IDs
Security group IDs
```

---

# 21. Resource Dependencies

Terraform can understand dependencies.

For example:

```text
VPC
 ↓
Subnets
 ↓
Security Groups
 ↓
ALB
 ↓
Target Group
 ↓
ECS Service
```

If one resource references another:

```hcl
vpc_id = aws_vpc.main.id
```

Terraform understands:

```text
aws_vpc.main
      ↓
security group
```

and creates resources in the required order.

This is one of Terraform's major advantages over manually executing a long list of CLI commands.

---

# 22. Lesson 8 — Data Sources

Not everything needs to be created by Terraform.

Sometimes AWS already has something that you want Terraform to reference.

For example:

```hcl
data "aws_vpc" "default" {
  default = true
}
```

Then:

```hcl
data.aws_vpc.default.id
```

A useful distinction:

```text
resource = Terraform manages/creates infrastructure

data     = Terraform reads existing infrastructure
```

Example:

```text
resource "aws_vpc" ...
```

means:

> Create/manage this VPC.

While:

```text
data "aws_vpc" ...
```

means:

> Find an existing VPC.

---

# 23. Default VPC vs Terraform-created VPC

Your current learning environment uses the AWS default VPC.

For learning, we can initially reference it.

Later, we should create our own VPC with Terraform.

Production-style architecture:

```text
VPC
├── Public Subnet A
├── Public Subnet B
├── Private Subnet A
├── Private Subnet B
├── Internet Gateway
├── NAT Gateway
└── Route Tables
```

Then:

```text
ALB
 ↓
ECS
 ↓
RDS
```

with appropriate public/private separation.

---

# 24. Lesson 9 — Security Groups

Your current architecture has:

```text
Internet
   ↓
ALB-SG : 80
   ↓
ECS-SG : 3000
   ↓
NestJS
```

The ECS security group should not expose port 3000 to the whole internet.

Conceptually:

```text
ALB-SG
  ↓
TCP 3000
  ↓
ECS-SG
```

Terraform lets us express that relationship.

Current repo implementation (`terraform/security-groups.tf`):

```hcl
resource "aws_security_group" "alb" {
   name        = "devops-nestjs-alb-sg"
   description = "Allow HTTP from internet to ALB"
   vpc_id      = data.aws_vpc.default.id

   ingress {
      description = "HTTP from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
   }

   egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
   }
}

resource "aws_security_group" "ecs" {
   name        = "devops-nestjs-ecs-sg"
   description = "Allow app traffic from ALB only"
   vpc_id      = data.aws_vpc.default.id

  ingress {
      description     = "App traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Dependency source (`terraform/vpc.tf`):

```hcl
data "aws_vpc" "default" {
   default = true
}
```

The important concept is:

```hcl
security_groups = [aws_security_group.alb.id]
```

Instead of allowing:

```text
0.0.0.0/0
```

on ECS port 3000.

---

# 25. Lesson 10 — ALB

Current baseline in this repo (`terraform/alb.tf`):

```hcl
resource "aws_lb" "app" {
   name               = "devops-nestjs-alb"
   internal           = false
   load_balancer_type = "application"
   security_groups    = [aws_security_group.alb.id]
   subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "app" {
   name        = "devops-nestjs-tg"
   port        = 3000
   protocol    = "HTTP"
   target_type = "ip"
   vpc_id      = data.aws_vpc.default.id

   health_check {
      path    = "/health"
      matcher = "200"
   }
}

resource "aws_lb_listener" "http" {
   load_balancer_arn = aws_lb.app.arn
   port              = 80
   protocol          = "HTTP"

   default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
   }
}
```

Note: for ECS Fargate with `target_type = "ip"`, you typically do **not** manage `aws_lb_target_group_attachment` manually. ECS service registration handles target attachments.

Conceptually:

```text
Internet
   ↓
ALB
   ↓
Listener : 80
   ↓
Target Group : 3000
   ↓
ECS Task
```

The health check will be:

```text
/health
```

which matches your NestJS application.

---

# 26. Lesson 11 — ECS Fargate

Terraform will eventually manage:

```text
aws_ecs_cluster
aws_ecs_task_definition
aws_ecs_service
```

The architecture will become:

```text
ALB
 ↓
Target Group
 ↓
ECS Service
 ↓
Fargate Task
 ↓
Container
 ↓
NestJS : 3000
```

Your task definition will contain:

```text
CPU
Memory
Container image
Container port
Environment variables
Execution role
CloudWatch logs
```

Terraform will connect these resources together.

---

# 27. Important ECS Concept — Image Tags

Your ECR repository uses immutable tags.

That means this is a problem:

```text
latest → image A

push another image as latest
```

because `latest` cannot be overwritten.

Your CI/CD workflow should preferably use immutable tags such as:

```text
devops-nestjs-app:<git-sha>
```

Terraform can then reference a specific image.

For example:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:abc123
```

The exact CI/CD design will be handled later.

---

# 28. Lesson 12 — CloudWatch

Your ECS service currently sends logs to:

```text
/aws/ecs/devops-nestjs-app
```

Terraform can manage the log group:

```hcl
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/devops-nestjs-app"
  retention_in_days = 7
}
```

Then the ECS task definition can reference it.

This gives you infrastructure like:

```text
ECS
 ↓
CloudWatch Logs
 ↓
/aws/ecs/devops-nestjs-app
```

---

# 29. Lesson 13 — IAM

Terraform can manage IAM roles and policies.

For example:

```text
GitHub Actions
      ↓
OIDC
      ↓
GitHub Actions IAM Role
      ↓
ECR / ECS permissions
```

And:

```text
ECS Task
      ↓
ecsTaskExecutionRole
      ↓
ECR + CloudWatch
```

Be careful with IAM.

Do not blindly give:

```text
AdministratorAccess
```

to everything.

We will learn least-privilege IAM policies.

## Practical IAM for this repository (OIDC + ECR + ECS)

Your current `terraform/iam.tf` now manages:

- ECS task execution role
- ECS task role
- GitHub Actions deploy role (`github-actions-ecr-push` by default)
- Inline least-privilege policies:
   - `ecr-push`
   - `ecs-deploy`

### Current ECS deploy policy shape (recommended)

For this repository, keep ECS permissions split like this:

- ECS read actions on `*`
   - `ecs:DescribeClusters`
   - `ecs:DescribeServices`
   - `ecs:DescribeTaskDefinition`
- ECS write action scoped to the service ARN
   - `ecs:UpdateService`
- Task definition registration on `*`
   - `ecs:RegisterTaskDefinition`

Service ARN path used by this project:

```text
arn:aws:ecs:ap-south-1:831975835566:service/devops-cluster/devops-nestjs-service
```

Cluster ARN path (if you scope cluster-specific access):

```text
arn:aws:ecs:ap-south-1:831975835566:cluster/devops-cluster
```

### PassRole role-name alignment (important)

Your docs may still refer to `ecsTaskExecutionRole`, but Terraform creates:

```text
devops-nestjs-ecs-task-execution-role
```

So in Terraform-managed IAM, ensure `iam:PassRole` includes Terraform role ARNs (already done in `terraform/iam.tf`).

If your ECS task definition still uses console role name `ecsTaskExecutionRole`, include that ARN as well or switch ECS task definition to the Terraform-managed execution role.

### OIDC trust policy note (important)

GitHub OIDC `sub` can appear in more than one format.

Common format:

```text
repo:sunny-bhakta/aws:ref:refs/heads/main
```

ID-annotated format (seen in this project history):

```text
repo:sunny-bhakta@77013204/aws@1361501698:ref:refs/heads/main
```

To prevent `Could not assume role with OIDC` failures, the Terraform trust policy allows:

- exact repo/branch subject
- ID-based subject pattern

### Import-first workflow for existing IAM resources

If IAM role/provider already exists in AWS, import before apply.

Example:

```powershell
terraform import aws_iam_role.github_actions github-actions-ecr-push
```

Then run:

```powershell
terraform plan
```

Review carefully before apply.

### Inputs you should set for OIDC safety

In Terraform variables (or `terraform.tfvars`), verify:

```hcl
github_owner     = "sunny-bhakta"
github_repo      = "aws"
github_branch    = "main"
github_owner_id  = "77013204"     # optional, recommended if known
github_repo_id   = "1361501698"   # optional, recommended if known
```

This keeps the role trust aligned with your GitHub Actions token claims.

### What to run next (cmd)

From Windows `cmd`, run this in order:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform fmt
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

If apply fails because the GitHub Actions role already exists, import once and retry:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform import aws_iam_role.github_actions github-actions-ecr-push
terraform plan -out tfplan
terraform apply tfplan
```

### Teardown everything managed by Terraform

Use this when you want to remove all resources tracked in your Terraform state.

Preview destroy first:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform plan -destroy
```

Then destroy:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform destroy
```

Non-interactive option:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform destroy -auto-approve
```

Important:

- Terraform destroys only resources present in `terraform.tfstate`.
- Manually created resources that were never imported are not removed by `terraform destroy`.
- Keep your state file until destroy completes successfully.

### Troubleshooting (OIDC / IAM / ALB 503)

If deployment fails, use this quick checklist.

#### 1) OIDC error: `The web identity token provided could not be validated`

Most common reason: trust policy `sub` mismatch.

Your Terraform trust should allow both:

```text
repo:sunny-bhakta/aws:ref:refs/heads/main
repo:sunny-bhakta@77013204/aws@1361501698:ref:refs/heads/main
```

In this repo, `terraform/iam.tf` already handles this with `StringLike` + multiple subject patterns.

After changing IAM in Terraform, always run apply (validate alone is not enough):

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform plan -out tfplan
terraform apply tfplan
```

If the IAM role already existed before Terraform management:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform import aws_iam_role.github_actions github-actions-ecr-push
terraform apply
```

#### 2) "I can’t see IAM role permissions"

Check the correct role:

```text
github-actions-ecr-push
```

Then open:

```text
IAM → Roles → github-actions-ecr-push → Permissions
```

Look under **Inline policies** (not only managed policies).

Terraform creates/updates these inline policies from `terraform/iam.tf`:

- `ecr-push`
- `ecs-deploy`

For `ecs-deploy`, verify this shape:

- Read actions (`Describe*`) allowed on `*`
- `ecs:UpdateService` allowed on:

```text
arn:aws:ecs:ap-south-1:831975835566:service/devops-cluster/devops-nestjs-service
```

`terraform validate` checks syntax only. Policies appear in AWS only after `terraform apply`.

If CI shows `not authorized to perform: ecs:DescribeServices`, this usually means IAM in AWS is stale or scoped differently than `terraform/iam.tf`. Re-apply Terraform and re-run the workflow.

#### 3) ALB returns `503`

`503` usually means target group has no healthy ECS task.

Check ECS service health:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws
aws ecs describe-services --cluster devops-cluster --services devops-nestjs-service --region ap-south-1 --query "services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}" --output table --profile devops-local
```

If `running = 0`, inspect stopped task reasons and CloudWatch logs, fix the root cause, then redeploy.

Only test ALB after ECS is healthy:

```bat
curl http://devops-nestjs-alb-1933074910.ap-south-1.elb.amazonaws.com/health
```

#### 4) Command pack (copy/paste, `cmd`)

Use these when troubleshooting quickly.

Check Terraform is managing GitHub role + policies:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform state list | findstr github_actions
```

Apply IAM changes from Terraform:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform plan -out tfplan
terraform apply tfplan
```

If role already exists, import once then apply:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform import aws_iam_role.github_actions github-actions-ecr-push
terraform apply
```

Check IAM inline policies on role:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws
aws iam list-role-policies --role-name github-actions-ecr-push --profile devops-local
```

Check ECS service health and recent events:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws
aws ecs describe-services --cluster devops-cluster --services devops-nestjs-service --region ap-south-1 --query "services[0].{desired:desiredCount,running:runningCount,pending:pendingCount,events:events[0:5].[createdAt,message]}" --output table --profile devops-local
```

List stopped tasks (to inspect failure reasons):

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws
aws ecs list-tasks --cluster devops-cluster --service-name devops-nestjs-service --desired-status STOPPED --region ap-south-1 --profile devops-local
```

#### 5) Terraform import error: `Resource already managed by Terraform`

Error example:

```text
Terraform is already managing a remote object for aws_iam_role.github_actions.
```

This means the resource already exists in Terraform state, so do **not** import again.

Check current mapping:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform state show aws_iam_role.github_actions
```

If it points to the correct role (`github-actions-ecr-push`), continue normally:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform plan -out tfplan
terraform apply tfplan
```

Use this only if state is mapped to the wrong remote object:

```bat
cd /d c:\Users\sunnykumar.bhakta\sunny-dev\conepts\aws\terraform
terraform state rm aws_iam_role.github_actions
terraform import aws_iam_role.github_actions github-actions-ecr-push
terraform plan
```

---

# 30. Lesson 14 — RDS PostgreSQL

After ECR, networking, ALB and ECS, we can add PostgreSQL.

Architecture:

```text
VPC
├── Public subnets
│   └── ALB
│
└── Private subnets
    ├── ECS
    └── RDS PostgreSQL
```

Terraform can manage:

```text
aws_db_subnet_group
aws_db_instance
```

We will also cover:

```text
DB security group
backup
storage
engine version
parameter groups
```

Do not put database passwords directly into Git.

---

# 31. Lesson 15 — Secrets Manager

Application configuration should eventually look like:

```text
ECS
 ↓
Secrets Manager
 ↓
DATABASE_URL
```

rather than:

```text
GitHub repository
 ↓
hard-coded database password
```

Terraform can create/manage the secret infrastructure, while sensitive secret values should be handled carefully.

---

# 32. Lesson 16 — Modules

Once the infrastructure becomes large, one file is difficult to maintain.

For example:

```text
modules/
├── vpc/
├── alb/
├── ecs/
├── rds/
└── ecr/
```

Then the root project can use:

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

Modules help us reuse infrastructure.

For example:

```text
dev
staging
production
```

can use similar infrastructure definitions with different values.

Do **not** start with modules.

First understand resources, variables, outputs, state and dependencies.

---

# 33. Lesson 17 — Remote State

Initially:

```text
terraform.tfstate
```

can be local.

For team/production usage, state should normally be stored remotely.

A common AWS architecture is:

```text
Terraform
   ↓
S3
   ↓
Remote Terraform State
```

with appropriate locking/state-management configuration.

Benefits:

```text
Team collaboration
Centralized state
State durability
CI/CD integration
```

We will introduce this only after understanding local state.

---

# 34. Lesson 18 — Terraform + GitHub Actions

Eventually your pipeline can become:

```text
Developer
   ↓
Git push
   ↓
GitHub Actions
   ↓
Terraform plan
   ↓
Approval
   ↓
Terraform apply
   ↓
AWS
```

This is separate from your application image deployment.

A mature pipeline may look like:

```text
               GitHub
                  │
          ┌───────┴────────┐
          ↓                ↓
   Terraform workflow   App workflow
          ↓                ↓
 Infrastructure          Docker
          ↓                ↓
       AWS ECR ←───────────┘
          ↓
       ECS Fargate
```

We will learn this after Terraform fundamentals.

---

# 35. Terraform File Structure — Final Target

Eventually:

```text
terraform/
│
├── provider.tf
├── variables.tf
├── outputs.tf
│
├── ecr.tf
├── iam.tf
│
├── vpc.tf
├── security-groups.tf
│
├── alb.tf
├── ecs.tf
├── cloudwatch.tf
│
├── rds.tf
└── secrets.tf
```

Later, if the project becomes more advanced:

```text
terraform/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── modules/
    ├── vpc/
    ├── alb/
    ├── ecs/
    ├── rds/
    └── ecr/
```

---

# 36. Terraform Commands You Should Know

## Initialize

```bash
terraform init
```

## Validate configuration

```bash
terraform validate
```

## Format files

```bash
terraform fmt
```

## Show execution plan

```bash
terraform plan
```

## Apply

```bash
terraform apply
```

## Show outputs

```bash
terraform output
```

## List state resources

```bash
terraform state list
```

## Inspect state resource

```bash
terraform state show aws_ecr_repository.app
```

## Destroy Terraform-managed resources

```bash
terraform destroy
```

---

# 37. Very Important Rule About terraform destroy

`terraform destroy` destroys resources managed by Terraform.

It does **not** mean:

> Delete everything in my AWS account.

It operates against Terraform's managed state.

Still, always inspect the plan carefully before destructive operations.

For the learning project:

```text
terraform plan
```

before:

```text
terraform apply
```

and understand what Terraform is going to change.

---

# 38. Terraform Lifecycle

The normal development cycle is:

```text
1. Write .tf
       ↓
2. terraform fmt
       ↓
3. terraform validate
       ↓
4. terraform plan
       ↓
5. Review
       ↓
6. terraform apply
       ↓
7. Verify AWS
```

When changing infrastructure:

```text
Edit
 ↓
fmt
 ↓
validate
 ↓
plan
 ↓
review
 ↓
apply
```

This workflow should become second nature.

---

# 39. Common Terraform Mistakes

## Mistake 1 — Creating an existing resource

Example:

```text
ECR already exists
        ↓
terraform apply
        ↓
AlreadyExists
```

Solution:

```bash
terraform import ...
```

---

## Mistake 2 — Skipping plan

Avoid:

```bash
terraform apply
```

without understanding the proposed changes.

Use:

```bash
terraform plan
```

first.

---

## Mistake 3 — Hard-coding secrets

Never do:

```hcl
password = "MyPassword123"
```

in a committed Terraform file.

Use appropriate secret management.

---

## Mistake 4 — Committing state

Avoid committing:

```text
terraform.tfstate
```

to Git.

---

## Mistake 5 — Starting with modules

Do not begin with:

```text
20 modules
100 variables
```

before understanding:

```text
resource
variable
output
data
state
dependency
```

---

## Mistake 6 — Terraforming everything immediately

Do not convert your entire AWS account to Terraform on day one.

Build gradually.

---

# 40. Recommended Learning Order

Follow this exact sequence.

```text
PHASE 1 — Fundamentals

1. Terraform installation
2. Provider
3. terraform init
4. Resource
5. terraform plan
6. terraform apply
7. terraform destroy
8. Variables
9. Outputs
10. Data sources
11. State
12. Import
```

Then:

```text
PHASE 2 — Your AWS Infrastructure

13. ECR
14. IAM
15. VPC
16. Subnets
17. Internet Gateway
18. Route tables
19. Security groups
20. ALB
21. Target group
22. ECS cluster
23. Task definition
24. ECS service
25. CloudWatch
```

Then:

```text
PHASE 3 — Application Infrastructure

26. RDS PostgreSQL
27. RDS networking
28. Secrets Manager
29. ECS secrets
30. HTTPS / ACM
31. Route 53
```

Then:

```text
PHASE 4 — Terraform Production Skills

32. Modules
33. Environments
34. Remote state
35. State locking
36. Workspaces
37. Terraform CI/CD
38. GitHub Actions
39. Plan/apply approval
40. Terraform security
```

Then:

```text
PHASE 5 — Kubernetes

41. Kubernetes fundamentals
42. Deployments
43. Services
44. Ingress
45. ConfigMaps
46. Secrets
47. Helm
```

This sequence gives you a strong DevOps/IaC foundation before Kubernetes.

---

# 41. Your First Practical Exercise

Start only with:

```text
terraform/
├── provider.tf
└── ecr.tf
```

### provider.tf

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
  region = "ap-south-1"
}
```

### ecr.tf

```hcl
resource "aws_ecr_repository" "app" {
  name                 = "devops-nestjs-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
```

Then:

```powershell
terraform init
```

Then:

```powershell
terraform validate
```

Then import:

```powershell
terraform import aws_ecr_repository.app devops-nestjs-app
```

Then:

```powershell
terraform plan
```

**Do not continue to ECS yet.**

The purpose of this exercise is to understand:

```text
Provider
   ↓
Resource
   ↓
Init
   ↓
Import
   ↓
State
   ↓
Plan
```

Once this makes sense, we move to the next resource.

---

# 42. What You Should Understand Before Moving On

You should be able to explain these without memorizing syntax:

### What is a provider?

```text
Plugin that lets Terraform communicate with a platform such as AWS.
```

### What is a resource?

```text
Infrastructure Terraform manages.
```

### What is a data source?

```text
Existing information Terraform reads.
```

### What is state?

```text
Terraform's record of the infrastructure it manages.
```

### What is import?

```text
Connect an existing resource to Terraform state.
```

### What is plan?

```text
Preview of infrastructure changes Terraform proposes.
```

### What is apply?

```text
Execute the approved infrastructure changes.
```

### What is destroy?

```text
Remove resources managed by Terraform.
```

---

# 43. Final Architecture We Are Building Toward

At the end of this Terraform learning path:

```text
                    GitHub
                       │
              GitHub Actions
                       │
              ┌────────┴────────┐
              │                 │
        Terraform            Docker
              │                 │
              ↓                 ↓
             AWS               ECR
              │                 │
      ┌───────┴────────┐        │
      │                │        │
     VPC               IAM      │
      │                         │
 ┌────┴─────┐                   │
 │          │                   │
 ALB       ECS ◄────────────────┘
 │           │
 │           └── Fargate
 │
 └── Target Group

 ECS
  │
  ├── CloudWatch
  │
  ├── Secrets Manager
  │
  └── RDS PostgreSQL
```

The important transformation is:

```text
Before:

AWS Console
   ↓
Manually created infrastructure


After:

Terraform
   ↓
Infrastructure as Code
   ↓
Repeatable AWS infrastructure
```

---

# 44. Learning Checklist

## Terraform fundamentals

- [ ] Install Terraform
- [ ] Configure AWS provider
- [ ] Run `terraform init`
- [ ] Understand resources
- [ ] Run `terraform validate`
- [ ] Run `terraform fmt`
- [ ] Understand `terraform plan`
- [ ] Understand `terraform apply`
- [ ] Understand `terraform destroy`
- [ ] Understand state
- [ ] Understand import
- [ ] Understand variables
- [ ] Understand outputs
- [ ] Understand data sources

## AWS

- [ ] Import/manage ECR
- [ ] IAM
- [ ] VPC
- [ ] Subnets
- [ ] Route tables
- [ ] Internet Gateway
- [ ] Security Groups
- [ ] ALB
- [ ] Target Group
- [ ] ECS Cluster
- [ ] ECS Task Definition
- [ ] ECS Service
- [ ] CloudWatch
- [ ] RDS PostgreSQL
- [ ] Secrets Manager
- [ ] ACM
- [ ] Route 53

## Advanced Terraform

- [ ] Modules
- [ ] Environment separation
- [ ] S3 backend for Terraform state
- [ ] Remote state
- [ ] State locking
- [ ] CI/CD
- [ ] GitHub Actions
- [ ] Terraform security
- [ ] Terraform testing

## Kubernetes

- [ ] Kubernetes fundamentals
- [ ] Deployments
- [ ] Services
- [ ] Ingress
- [ ] ConfigMaps
- [ ] Secrets
- [ ] Helm

---

# 45. Our Working Method

We will learn this **hands-on**, not by copying a large Terraform repository.

For each resource:

```text
1. Understand the AWS resource
2. Write the Terraform resource
3. Run terraform fmt
4. Run terraform validate
5. Run terraform plan
6. Understand the plan
7. Apply
8. Verify in AWS
9. Understand Terraform state
10. Move to the next resource
```

The first milestone is:

```text
Terraform
   ↓
AWS Provider
   ↓
Existing ECR
   ↓
Import
   ↓
State
   ↓
Plan
```

After that, we will progressively Terraform your **actual ECR → VPC → ALB → ECS Fargate → CloudWatch → RDS → Secrets** architecture.

---

# 46. Terraform File Order Reference (Current Project)

Use this as a quick map for both learning and troubleshooting. Terraform executes by dependency graph, but this order is best for understanding.

## 46.1 Ordered walkthrough

1. `provider.tf`
   - Pins Terraform and provider versions (`aws`, `random`)
   - Configures AWS region/profile

2. `variables.tf`
   - Central input contract (naming, ECS sizing, RDS/secrets toggles, GitHub OIDC values)

3. `vpc.tf`
   - Reads default VPC and default subnets using data sources

4. `security-groups.tf`
   - Defines ALB and ECS security groups
   - Allows Internet → ALB (80) and ALB → ECS (app port)

5. `ecr.tf`
   - Creates ECR repository for container images

6. `iam.tf`
   - Creates ECS execution/task roles
   - Creates GitHub Actions OIDC role and policies for ECR push + ECS deploy

7. `cloudwatch.tf`
   - Creates log group used by ECS task logs

8. `alb.tf`
   - Creates ALB, target group, and HTTP listener
   - Health check path: `/health`

9. `ecs.tf`
   - Creates ECS cluster, task definition, and Fargate service
   - Connects service to ALB target group

10. `rds.tf` (optional)
    - Created only when `enable_rds = true`
    - Creates DB SG, subnet group, random password, and PostgreSQL instance

11. `secrets.tf` (optional)
    - Created only when `enable_secrets = true`
    - Stores DB config in Secrets Manager

12. `outputs.tf`
    - Exposes key values (ECR URL, ALB DNS, ECS names, log group, optional RDS/secret values)

## 46.2 Important dependency notes

- `hashicorp/random` is required because `rds.tf` uses `random_password.db`.
- `ecs.tf` depends on resources from `ecr.tf`, `iam.tf`, `cloudwatch.tf`, `security-groups.tf`, and `alb.tf`.
- `secrets.tf` can consume values from both `rds.tf` and variable overrides.
- File names do not force runtime order; resource references do.

## 46.3 Practical apply strategy

- Start with core app path:
  `provider.tf` → `variables.tf` → `vpc.tf` → `security-groups.tf` → `ecr.tf` → `iam.tf` → `cloudwatch.tf` → `alb.tf` → `ecs.tf`
- Enable optional layers later:
  `rds.tf` and then `secrets.tf`
- Use `outputs.tf` to verify what was created and to feed CI/CD.

## 46.4 File dependency matrix (quick debug view)

| File | Depends on | Creates / Defines |
|---|---|---|
| `provider.tf` | `variables.tf` (`aws_region`, `aws_profile`) | Terraform/provider requirements and AWS provider config |
| `variables.tf` | None | Input variable contract |
| `vpc.tf` | Provider only | `data.aws_vpc.default`, `data.aws_subnets.default` |
| `security-groups.tf` | `vpc.tf`, `variables.tf` | `aws_security_group.alb`, `aws_security_group.ecs` |
| `ecr.tf` | `variables.tf` | `aws_ecr_repository.app` |
| `iam.tf` | `ecr.tf`, `variables.tf` | ECS task roles, GitHub OIDC role, ECR/ECS deploy policies |
| `cloudwatch.tf` | `variables.tf` | `aws_cloudwatch_log_group.app` |
| `alb.tf` | `vpc.tf`, `security-groups.tf`, `variables.tf` | `aws_lb.app`, `aws_lb_target_group.app`, `aws_lb_listener.http` |
| `ecs.tf` | `ecr.tf`, `iam.tf`, `cloudwatch.tf`, `security-groups.tf`, `alb.tf`, `vpc.tf`, `variables.tf` | `aws_ecs_cluster.app`, `aws_ecs_task_definition.app`, `aws_ecs_service.app` |
| `rds.tf` (optional) | `vpc.tf`, `security-groups.tf`, `variables.tf`, `provider.tf` (`random`) | RDS SG, DB subnet group, `random_password.db`, `aws_db_instance.postgres` |
| `secrets.tf` (optional) | `variables.tf`, and optionally `rds.tf` | DB locals, `aws_secretsmanager_secret.db`, `aws_secretsmanager_secret_version.db` |
| `outputs.tf` | Most resource files | Exported values for CI, verification, and integrations |

### Reading this table correctly

- “Depends on” means **logical reference dependency** in Terraform graph.
- Terraform still resolves final apply order automatically from references.
- Optional files participate only when their toggle variables are enabled.

## 46.5 Auth modes (Local vs GitHub Actions)

This project uses two different authentication paths. Keep them separate.

### Local Terraform (your machine)

- Uses AWS CLI profile via provider config:
   - `provider "aws" { profile = var.aws_profile }`
- Default local profile in this project:
   - `aws_profile = "devops-local"`
- Use this mode for:
   - `terraform init`, `terraform plan`, `terraform apply`, `terraform destroy` run from local terminal.

### GitHub Actions deploy (CI/CD)

- Uses OIDC web identity assumption (no long-lived AWS keys in GitHub).
- Trust policy is defined in `iam.tf` (`github_actions_assume_role`).
- ECR push and ECS deploy permissions are attached to `aws_iam_role.github_actions`.

### Important rule

- **Local Terraform does not use OIDC**.
- **GitHub Actions does not use your local `devops-local` profile**.

### Quick troubleshooting hint

If you see:

`Could not assume role with OIDC`

then the issue is in GitHub OIDC trust/configuration (role ARN, provider, `aud`/`sub` claims), not in local Terraform profile authentication.

## 46.6 GitHub Actions Terraform implementation (no local Terraform required)

This repository includes a dedicated workflow:

- `.github/workflows/terraform.yml`

It supports:

- Pull request / push validation (`fmt` + `validate`)
- Manual Terraform actions (`plan`, `apply`, `destroy`) using `workflow_dispatch`

### Required GitHub repository variables

Set these in **GitHub → Settings → Secrets and variables → Actions → Variables**:

- `AWS_ROLE_ARN` = IAM role to assume via OIDC
- `AWS_REGION` = `ap-south-1` (or your target region)
- `TF_STATE_BUCKET` = S3 bucket name for Terraform state
- `TF_STATE_KEY` = state object key (example: `aws/devops-nestjs/terraform.tfstate`)
- `TF_STATE_LOCK_TABLE` = optional DynamoDB table for state locking

### How to run

1. Open **Actions** tab in GitHub.
2. Select workflow **Terraform**.
3. Click **Run workflow**.
4. Choose action:
    - `plan`
    - `apply`
    - `destroy`
5. Run and review logs.

### CI authentication behavior

- Workflow uses OIDC role assumption (`aws-actions/configure-aws-credentials`).
- Terraform in CI passes `aws_profile=""` intentionally.
- AWS provider config supports this by using:
   - `profile = var.aws_profile != "" ? var.aws_profile : null`

This keeps local profile auth and GitHub OIDC auth both working cleanly.

