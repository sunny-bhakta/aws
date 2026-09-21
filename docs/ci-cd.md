# AWS ECS Fargate Deployment Guide

Complete deployment of a NestJS application using:

* GitHub Actions
* GitHub OIDC
* AWS IAM
* Amazon ECR
* Amazon ECS Fargate
* Application Load Balancer
* Target Group
* Security Groups
* CloudWatch Logs
* ECR Lifecycle Policy

---

# Architecture

## CI Flow
```text
Developer
   │
   ▼
GitHub Repository
   │
   │ Push to main
   ▼
GitHub Actions
   │
   ├── npm ci
   ├── npm run lint
   ├── npm run build
   ├── npm test
   │
   ├── Docker build
   │
   ▼
Amazon ECR
   │
   │ Docker image
   ▼
Amazon ECS Fargate
   │
   ├── ECS Task
   │     └── NestJS :3000
   │
   ▼
Application Load Balancer
   │
   │ HTTP :80
   ▼
Target Group
   │
   │ HTTP :3000
   ▼
NestJS Application
   │
   └── /health → HTTP 200

CloudWatch Logs
   ▲
   │
ECS Task
```

## Deployment Flow

```text
GitHub Repository
       │
       │ Push to main
       ▼
GitHub Actions
       │
       │ OIDC
       ▼
AWS IAM
github-actions-ecr-push
       │
       ▼
Amazon ECR
devops-nestjs-app
       │
       │ Docker image
       ▼
Amazon ECS
devops-cluster
       │
       ▼
ECS Service
devops-nestjs-service
       │
       ▼
Fargate Task
devops-nestjs-app :3000
```

## Runtime Flow

```text
Internet
   │
   │ HTTP :80
   ▼
Application Load Balancer
devops-nestjs-alb
   │
   │ HTTP :3000
   ▼
Target Group
devops-nestjs-tg
   │
   ▼
ECS Fargate Task
devops-nestjs-app
   │
   ▼
NestJS Application
```

## Logging Flow

```text
NestJS Container
       │
       │ stdout / stderr
       ▼
ECS awslogs driver
       │
       ▼
CloudWatch Logs
/aws/ecs/devops-nestjs-app
```

---

# Project Values

| Resource               | Value                        |
| ---------------------- | ---------------------------- |
| AWS Account            | `831975835566`               |
| AWS Region             | `ap-south-1`                 |
| GitHub Repository      | `sunny-bhakta/aws`           |
| Branch                 | `main`                       |
| ECR Repository         | `devops-nestjs-app`          |
| ECS Cluster            | `devops-cluster`             |
| ECS Service            | `devops-nestjs-service`      |
| Task Definition Family | `devops-nestjs-app`          |
| Container Name         | `devops-nestjs-app`          |
| Container Port         | `3000`                       |
| Target Group           | `devops-nestjs-tg`           |
| ALB                    | `devops-nestjs-alb`          |
| ALB Security Group     | `ALB-SG`                     |
| ECS Security Group     | `ECS-SG`                     |
| CloudWatch Log Group   | `/aws/ecs/devops-nestjs-app` |
| GitHub IAM Role        | `github-actions-ecr-push`    |
| ECS Execution Role     | `ecsTaskExecutionRole`       |
| VPC                    | Default VPC                  |
| ALB Subnets            | `ap-south-1a`, `ap-south-1b` |

---

# 1. Create ECR Repository

Go to:

**AWS Console → ECR → Repositories → Create repository**

Configure:

```text
Repository name: devops-nestjs-app

Visibility: Private

Tag immutability: Enabled

Encryption: AES-256

Scan on push: Enabled
```

## Why enable tag immutability?

With immutable tags, an image tag cannot be overwritten.

For example:

```text
app:6f95dd5193eae50e9067da560b8d26484bddf70d
```

cannot later be replaced with a different image.

This makes deployments traceable because each image corresponds to a specific Git commit.

## Important: Do not use `latest`

Because tag immutability is enabled, repeatedly pushing:

```text
latest
```

will eventually fail with an error similar to:

```text
The image tag 'latest' already exists
and cannot be overwritten because the tag is immutable
```

Use the Git commit SHA instead:

```text
devops-nestjs-app:6f95dd5193eae50e9067da560b8d26484bddf70d
```

Deployment becomes:

```text
Git commit
    ↓
Docker image
    ↓
Immutable ECR tag
    ↓
ECS task definition
    ↓
ECS deployment
```

This also makes rollback easier.

---

# 2. ECR Lifecycle Policy

To prevent the repository from accumulating old images:

**AWS Console → ECR → Repositories → `devops-nestjs-app` → Lifecycle policy**

Example:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep only 2 most recent images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 2
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

This keeps approximately the two most recent images and expires older images.

Example:

```text
abc111
abc222
abc333
abc444
```

Eventually:

```text
abc333
abc444
```

remain.

### Important

Lifecycle expiration is asynchronous. Old images may not disappear immediately.

Keeping only two images is suitable for a learning/demo environment.

For production, consider retaining:

```text
5
10
20
```

or more images depending on rollback requirements.

---

# 3. GitHub OIDC Provider

Go to:

**AWS Console → IAM → Identity providers → Add provider**

Select:

```text
Provider type:
OpenID Connect

Provider URL:
https://token.actions.githubusercontent.com

Audience:
sts.amazonaws.com
```

Create the provider.

GitHub Actions can now authenticate to AWS without storing a long-lived AWS access key in GitHub.

---

# 4. Create GitHub Actions IAM Role

Go to:

**AWS Console → IAM → Roles → Create role**

Choose:

```text
Trusted entity type:
Web identity
```

Select:

```text
Identity provider:
token.actions.githubusercontent.com

Audience:
sts.amazonaws.com
```

Role name:

```text
github-actions-ecr-push
```

This role is assumed by GitHub Actions.

---

# 5. GitHub Actions Trust Policy

The role trust relationship should restrict access to the intended GitHub repository and branch.

Example:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::831975835566:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
               "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
            },
            "StringLike": {
               "token.actions.githubusercontent.com:sub": [
                  "repo:sunny-bhakta/aws:ref:refs/heads/main",
                  "repo:sunny-bhakta@*/aws@*:ref:refs/heads/main",
                  "repo:sunny-bhakta@77013204/aws@1361501698:ref:refs/heads/main"
               ]
        }
      }
    }
  ]
}
```

This allows the `main` branch of:

```text
sunny-bhakta/aws
```

to assume the role.

---

# 6. ECR Permissions

Attach a policy to:

```text
github-actions-ecr-push
```

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GetAuthToken",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PushToRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:831975835566:repository/devops-nestjs-app"
    }
  ]
}
```

---

# 7. ECS Deployment Permissions

The same GitHub Actions role needs permission to deploy to ECS.

Policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition"
      ],
      "Resource": "*"
    }
  ]
}
```

Policy name:

```text
github-actions-ecs-deploy
```

---

# 8. IAM PassRole Permission

This permission is required because GitHub Actions registers an ECS task definition that uses:

```text
ecsTaskExecutionRole
```

The GitHub Actions role must be allowed to pass that role to ECS.

Attach this policy to:

```text
github-actions-ecr-push
```

Policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PassECSTaskExecutionRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::831975835566:role/ecsTaskExecutionRole",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
```

This can be attached as a separate policy, or included in the same inline policy as ECS deploy actions.

## Why is this needed?

There are two different roles:

```text
GitHub Actions
      │
      ▼
github-actions-ecr-push
      │
      │ iam:PassRole
      ▼
ecsTaskExecutionRole
      │
      ▼
ECS Fargate Task
```

`github-actions-ecr-push` is used by GitHub Actions.

`ecsTaskExecutionRole` is used by the ECS task.

Having `ecsTaskExecutionRole` in IAM is not sufficient. The GitHub Actions role must explicitly be allowed to pass it.

---

# 9. ECS Task Execution Role

Go to:

**AWS Console → IAM → Roles → Create role**

Trusted entity:

```text
AWS service
```

Use case:

```text
Elastic Container Service
→ Elastic Container Service Task
```

Role name:

```text
ecsTaskExecutionRole
```

Attach:

```text
AmazonECSTaskExecutionRolePolicy
```

Purpose:

```text
ECS Task
   │
   ├── Pull image from ECR
   │
   └── Send container logs to CloudWatch
```

The application **Task Role** can remain:

```text
None
```

because the current application does not need to call AWS APIs.

---

# 10. Create ECS Cluster

Go to:

**AWS Console → ECS → Clusters → Create cluster**

Configure:

```text
Cluster name:
devops-cluster
```

Use:

```text
AWS Fargate / Serverless
```

Create the cluster.

---

# 11. Create CloudWatch Log Group

Go to:

**AWS Console → CloudWatch → Logs → Log groups → Create log group**

Name:

```text
/aws/ecs/devops-nestjs-app
```

Log class:

```text
Standard
```

---

# 12. Create ECS Task Definition

Go to:

**AWS Console → ECS → Task definitions → Create new task definition**

Configure:

```text
Family:
devops-nestjs-app

Launch type:
Fargate

CPU:
0.25 vCPU

Memory:
0.5 GB
```

> Important: `0.25 vCPU` is CPU, not memory. CPU and memory are separate task-definition settings.

Execution role:

```text
ecsTaskExecutionRole
```

Task role:

```text
None
```

---

# 13. ECS Container

Container name:

```text
devops-nestjs-app
```

Image:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:<IMAGE_TAG>
```

For immutable ECR tags:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:6f95dd5193eae50e9067da560b8d26484bddf70d
```

Container port:

```text
3000
```

Protocol:

```text
TCP
```

Optional port name:

```text
http
```

---

# 14. CloudWatch Container Logging

Enable:

```text
Use log collection
```

Log driver:

```text
Amazon CloudWatch Logs
```

Configure:

```text
Log group:
/aws/ecs/devops-nestjs-app

Region:
ap-south-1

Stream prefix:
ecs
```

The resulting stream will look similar to:

```text
ecs/devops-nestjs-app/<task-id>
```

Logging flow:

```text
NestJS
   ↓
stdout / stderr
   ↓
ECS awslogs driver
   ↓
CloudWatch Logs
```

CloudWatch is not part of the HTTP request path.

---

# 15. Target Group

Go to:

**AWS Console → EC2 → Target Groups → Create target group**

Configure:

```text
Target type:
IP addresses

Protocol:
HTTP

Port:
3000

VPC:
Default VPC
```

Target group name:

```text
devops-nestjs-tg
```

Health check:

```text
Protocol:
HTTP

Path:
/health

Port:
traffic-port
```

## Important for Fargate

For ECS Fargate:

```text
Target type = IP
```

Do not use:

```text
Instance
```

ECS automatically registers the Fargate task IP with the target group.

Do not manually register task IPs.

---

# 16. Security Groups

Create two security groups:

```text
ALB-SG
ECS-SG
```

---

## ALB-SG

Go to:

**AWS Console → EC2 → Security Groups → Create security group**

Name:

```text
ALB-SG
```

Inbound:

```text
Type: HTTP
Protocol: TCP
Port: 80
Source: 0.0.0.0/0
```

Do not add port `3000` to the ALB security group.

---

## ECS-SG

Create:

```text
ECS-SG
```

Inbound:

```text
Type: Custom TCP
Port: 3000
Source: ALB-SG
```

Do not use:

```text
0.0.0.0/0
```

for port 3000.

Final security flow:

```text
Internet
   │
   │ TCP 80
   ▼
ALB-SG
   │
   │ TCP 3000
   ▼
ECS-SG
   │
   ▼
NestJS
```

---

# 17. Application Load Balancer

Go to:

**AWS Console → EC2 → Load Balancers → Create Load Balancer**

Select:

```text
Application Load Balancer
```

Name:

```text
devops-nestjs-alb
```

Scheme:

```text
Internet-facing
```

IP address type:

```text
IPv4
```

VPC:

```text
Default VPC
```

Select at least two Availability Zones:

```text
ap-south-1a
ap-south-1b
```

Security group:

```text
ALB-SG
```

---

## Listener

Configure:

```text
Protocol:
HTTP

Port:
80
```

Default action:

```text
Forward to:
devops-nestjs-tg
```

Traffic path:

```text
Internet
   ↓
ALB :80
   ↓
Target Group
   ↓
ECS :3000
```

---

# 18. ECS Service

Go to:

**AWS Console → ECS → Clusters → `devops-cluster` → Services → Create**

Configure:

```text
Service name:
devops-nestjs-service

Launch type:
Fargate

Task definition:
devops-nestjs-app
```

Desired tasks:

```text
1
```

---

# 19. ECS Network Configuration

Select the same VPC used by the ALB.

For this learning setup:

```text
Subnets:
Public subnets

Auto-assign public IP:
Enabled
```

Security group:

```text
ECS-SG
```

## Production note

For production, normally use:

```text
Private subnets
+
NAT Gateway and/or VPC endpoints
```

For this learning deployment, public subnets with a public IP keep the setup simpler.

---

# 20. ECS Service Load Balancing

This is a critical configuration.

While creating or updating the ECS service, find:

**Load balancing**

Configure:

```text
Load balancer type:
Application Load Balancer

Load balancer:
devops-nestjs-alb

Listener:
HTTP :80

Target group:
devops-nestjs-tg

Container:
devops-nestjs-app

Container port:
3000
```

Complete connection:

```text
ALB
 ↓
HTTP :80
 ↓
devops-nestjs-tg
 ↓
ECS task IP :3000
```

## Why this matters

The ECS service is responsible for registering the running Fargate task with the target group.

If ECS shows:

```text
Running: 1
```

but the target group shows:

```text
Healthy: 0
Unhealthy: 0
```

check the ECS service **Load balancing** configuration.

Do not manually register the target.

---

# 21. Verify ECS → Target Group Registration

Go to:

**EC2 → Target Groups → `devops-nestjs-tg` → Targets**

Initially you may see:

```text
Target: <Fargate task IP>
Port: 3000
Health: Initial
```

After successful health checks:

```text
Health: Healthy
```

Expected final state:

```text
1 target
1 healthy
0 unhealthy
```

The task IP may change whenever ECS replaces the task.

ECS automatically handles target registration.

---

# 22. NestJS Health Endpoint

The target group health check calls:

```text
/health
```

Your NestJS application must return HTTP `200`.

Example:

```text
GET /health

HTTP 200
```

The ALB effectively checks:

```text
http://<task-ip>:3000/health
```

You do not need to expose port 3000 publicly.

---

# 23. Dockerfile

Example production Dockerfile:

```dockerfile
FROM node:22-alpine AS deps

WORKDIR /app

COPY package*.json ./

RUN npm ci


FROM node:22-alpine AS build

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

COPY . .

RUN npm run build

RUN npm prune --omit=dev


FROM node:22-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

COPY --from=build /app/package*.json ./

COPY --from=build /app/node_modules ./node_modules

COPY --from=build /app/dist ./dist

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "dist/main"]
```

---

# 24. GitHub Repository Variables

Go to:

**GitHub → Repository → Settings → Secrets and variables → Actions → Variables**

Create:

```text
AWS_ROLE_ARN
AWS_REGION
ECR_REPOSITORY
ECS_CLUSTER
ECS_SERVICE
```

Values:

```text
AWS_ROLE_ARN:
arn:aws:iam::831975835566:role/github-actions-ecr-push

AWS_REGION:
ap-south-1

ECR_REPOSITORY:
devops-nestjs-app

ECS_CLUSTER:
devops-cluster

ECS_SERVICE:
devops-nestjs-service
```

---

# 25. GitHub Actions OIDC Configuration

Required workflow permission:

```yaml
permissions:
  contents: read
  id-token: write
```

Configure AWS credentials:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

This uses GitHub OIDC instead of storing long-lived AWS access keys.

---

# 26. Recommended Image Tagging

Because ECR tag immutability is enabled, use:

```text
Git commit SHA
```

instead of repeatedly pushing:

```text
latest
```

Example:

```yaml
env:
  ECR_REPOSITORY: devops-nestjs-app
  IMAGE_TAG: ${{ github.sha }}
```

Resulting image:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:${{ github.sha }}
```

Deployment flow:

```text
Git commit
    ↓
SHA tag
    ↓
Immutable ECR image
    ↓
ECS task definition
    ↓
ECS deployment
```

---

# 27. GitHub Actions Deployment Flow

The intended workflow is:

```text
1. Checkout repository
       ↓
2. Setup Node.js
       ↓
3. npm ci
       ↓
4. npm run lint
       ↓
5. npm run build
       ↓
6. npm test
       ↓
7. Configure AWS credentials using OIDC
       ↓
8. Login to ECR
       ↓
9. Build Docker image
       ↓
10. Push immutable SHA-tagged image
       ↓
11. Register/update ECS task definition
       ↓
12. Update ECS service
       ↓
13. ECS starts new Fargate task
       ↓
14. ECS registers task IP with target group
       ↓
15. ALB performs /health check
       ↓
16. Target becomes Healthy
```

---

# 28. CloudWatch Logs

Go to:

**AWS Console → CloudWatch → Logs → Log groups**

Open:

```text
/aws/ecs/devops-nestjs-app
```

You should see ECS log streams.

Example:

```text
ecs/devops-nestjs-app/<task-id>
```

Logging path:

```text
NestJS
   ↓
stdout / stderr
   ↓
ECS awslogs
   ↓
CloudWatch Logs
```

---

# 29. End-to-End Verification

Verify in this order.

## 1. GitHub Actions

Check:

```text
Workflow = Success
```

---

## 2. ECR

Go to:

**ECR → Repositories → `devops-nestjs-app`**

Verify an image exists with the Git SHA tag.

Example:

```text
6f95dd5193eae50e9067da560b8d26484bddf70d
```

---

## 3. ECS Service

Go to:

**ECS → Clusters → `devops-cluster` → Services → `devops-nestjs-service`**

Verify:

```text
Desired: 1
Running: 1
Pending: 0
```

---

## 4. ECS Task

Open the running task.

Verify:

```text
Task status:
RUNNING

Container:
RUNNING
```

---

## 5. CloudWatch

Go to:

**CloudWatch → Log groups → `/aws/ecs/devops-nestjs-app`**

Verify application logs are appearing.

---

## 6. Target Group

Go to:

**EC2 → Target Groups → `devops-nestjs-tg` → Targets**

Verify:

```text
1 target
Port: 3000
Health: Healthy
```

---

## 7. ALB

Go to:

**EC2 → Load Balancers → `devops-nestjs-alb`**

Copy the ALB DNS name.

Test:

```text
http://<ALB-DNS-NAME>/health
```

Expected:

```text
HTTP 200
```

You can also test:

```text
http://<ALB-DNS-NAME>/
```

or another application endpoint.

---

# 30. Troubleshooting

## ECS Task Is Not Running

Check:

```text
ECS
→ Cluster
→ Service
→ Tasks
```

Open the stopped task and inspect:

```text
Stopped reason
```

Also check:

```text
CloudWatch Logs
```

---

## ECR Image Cannot Be Pulled

Check:

```text
ECR repository
```

and confirm the exact image tag exists.

Also verify:

```text
ecsTaskExecutionRole
```

has:

```text
AmazonECSTaskExecutionRolePolicy
```

---

## GitHub Actions: `GetAuthorizationToken` AccessDenied

Verify the GitHub Actions role has:

```text
ecr:GetAuthorizationToken
```

with:

```text
Resource: *
```

---

## GitHub Actions: `RegisterTaskDefinition` AccessDenied

Verify:

```text
ecs:RegisterTaskDefinition
```

exists on:

```text
github-actions-ecr-push
```

---

## GitHub Actions: `DescribeServices` AccessDenied

If you see:

```text
is not authorized to perform: ecs:DescribeServices
```

verify all of the following:

1. Workflow uses the correct role ARN:

```text
arn:aws:iam::831975835566:role/github-actions-ecr-push
```

2. The role has an inline/attached policy allowing:

```text
ecs:DescribeServices
ecs:UpdateService
ecs:DescribeTaskDefinition
ecs:RegisterTaskDefinition
```

If the policy is currently scoped to a specific ECS service ARN and this error still occurs, allow ECS **read** actions on `*`:

```json
{
   "Effect": "Allow",
   "Action": [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition"
   ],
   "Resource": "*"
}
```

Keep write access (`ecs:UpdateService`) scoped to your service ARN.

Example service ARN path for this project:

```text
arn:aws:ecs:ap-south-1:831975835566:service/devops-cluster/devops-nestjs-service
```

If you also scope cluster reads, use:

```text
arn:aws:ecs:ap-south-1:831975835566:cluster/devops-cluster
```

3. IAM changes were actually applied (not only validated in Terraform).

4. Re-run workflow after policy update (new session picks updated permissions).

---

## GitHub Actions: `iam:PassRole` AccessDenied

If you see:

```text
not authorized to perform:
iam:PassRole
```

verify the policy:

```text
github-actions-ecs-passrole
```

is attached to:

```text
github-actions-ecr-push
```

and allows:

```text
iam:PassRole
```

on:

```text
arn:aws:iam::831975835566:role/ecsTaskExecutionRole
```

---

## Target Group Shows 0 Healthy / 0 Unhealthy

If ECS shows:

```text
Running: 1
```

but the target group shows:

```text
Healthy: 0
Unhealthy: 0
```

check:

**ECS → Service → Update → Load balancing**

Verify:

```text
ALB:
devops-nestjs-alb

Listener:
HTTP :80

Target group:
devops-nestjs-tg

Container:
devops-nestjs-app

Port:
3000
```

ECS should automatically register the task.

---

## Target Is Unhealthy

Check:

```text
NestJS listens on port 3000
        ↓
/health returns HTTP 200
        ↓
Target group port = 3000
        ↓
Health check path = /health
        ↓
ECS-SG allows TCP 3000 from ALB-SG
        ↓
Container is running
```

---

## ALB Listener Port Is Unreachable

Check:

**EC2 → Security Groups → ALB-SG → Inbound rules**

You need:

```text
HTTP
TCP
80
0.0.0.0/0
```

Do not add port `3000` to ALB-SG.

---

# 31. Security Group Architecture

```text
                    INTERNET
                       │
                       │ HTTP :80
                       ▼
                 ┌───────────┐
                 │    ALB    │
                 │   ALB-SG  │
                 └─────┬─────┘
                       │
                       │ TCP :3000
                       ▼
                ┌──────────────┐
                │ ECS Fargate  │
                │    ECS-SG    │
                └──────┬───────┘
                       │
                       ▼
                    NestJS
```

Security rules:

```text
ALB-SG
  inbound:
    TCP 80 from 0.0.0.0/0

ECS-SG
  inbound:
    TCP 3000 from ALB-SG
```

This prevents direct public access to the NestJS container port.

---

# 32. Complete Deployment Architecture

```text
                         GitHub
                           │
                           │ OIDC
                           ▼
                github-actions-ecr-push
                           │
                           │
                           ▼
                      Amazon ECR
                 devops-nestjs-app
                           │
                           │ Docker image
                           ▼
                    ECS Fargate
                   devops-cluster
                           │
                           ▼
                devops-nestjs-service
                           │
                           ▼
                  ┌────────────────┐
                  │ Fargate Task   │
                  │ NestJS :3000   │
                  └───────┬────────┘
                          │
                          │ automatic registration
                          ▼
                  devops-nestjs-tg
                          ▲
                          │
                          │ HTTP :80
                          │
                   ALB :80
                devops-nestjs-alb
                          ▲
                          │
                       Internet


Logs:

Fargate Task
     │
     │ stdout / stderr
     ▼
CloudWatch Logs
/aws/ecs/devops-nestjs-app
```

---

# 33. Production Improvements

For a learning deployment, the current configuration is sufficient.

For production, consider:

```text
Immutable ECR tags
        ✓

Git SHA deployments
        ✓

ECR lifecycle policy
        ✓

Private ECS subnets
        →

NAT Gateway / VPC endpoints

HTTPS
        →

ACM certificate + ALB HTTPS listener

Secrets
        →

AWS Secrets Manager / SSM Parameter Store

Multiple ECS tasks
        →

2+

Autoscaling
        →

CPU / memory / request based

Monitoring
        →

CloudWatch alarms

Deployment strategy
        →

Rolling / blue-green

ECR retention
        →

Keep more than 2 images

Infrastructure as Code
        →

Terraform / AWS CDK / CloudFormation
```

---

# 34. Cleanup

If this is a temporary learning environment, delete resources in dependency order.

Recommended order:

```text
1. ECS Service

2. ECS Cluster

3. Load Balancer

4. Target Group

5. CloudWatch Log Group

6. ECR Repository

7. IAM policies/roles if no longer needed
```

Be careful with:

```text
Default VPC
Security Groups
Subnets
```
```
### Step 1 — Delete ECS Service

Go to:

```text
ECS
→ Clusters
→ devops-cluster
→ Services
→ devops-nestjs-service
```

Delete the service.

If prompted, scale the service down to:

```text
Desired count: 0
```

before deletion.

---

### Step 2 — Delete ECS Cluster

After the service has been deleted:

```text
ECS
→ Clusters
→ devops-cluster
→ Delete
```

---

### Step 3 — Delete Load Balancer

Go to:

```text
EC2
→ Load Balancers
→ devops-nestjs-alb
→ Delete
```

---

### Step 4 — Delete Target Group

Go to:

```text
EC2
→ Target Groups
→ devops-nestjs-tg
→ Delete
```

---

### Step 5 — Delete CloudWatch Log Group

Go to:

```text
CloudWatch
→ Logs
→ Log groups
→ /aws/ecs/devops-nestjs-app
```

Delete the log group if you no longer need the logs.

---

### Step 6 — Delete ECR Repository

Go to:

```text
ECR
→ Repositories
→ devops-nestjs-app
→ Delete
```

This removes the repository and its container images.

---

### Step 7 — Remove IAM Resources if No Longer Needed

Only do this if the resources are not used by another project.

Potential resources:

```text
github-actions-ecr-push
ecsTaskExecutionRole
```

For `github-actions-ecr-push`, remove the role only if no other GitHub Actions workflow uses it.

For `ecsTaskExecutionRole`, remove it only if no other ECS task uses it.

---

### Step 8 — Remove Security Groups if No Longer Needed

You can remove:

```text
ALB-SG
ECS-SG
```

only if they are not attached to or referenced by other resources.

---

## Do NOT Delete These

Do not delete the following just because this project is being torn down:

```text
Default VPC
Subnets
Route tables
Internet Gateway
NAT Gateway
```

They may be shared by other AWS resources.

---

Do not delete shared VPC resources unless you are certain they are not being used by anything else.

---

# Final Checklist

```text
ECR
[✓] Private repository
[✓] devops-nestjs-app
[✓] Tag immutability enabled
[✓] AES-256 encryption
[✓] Scan on push enabled
[✓] Lifecycle policy configured
[✓] SHA-based image tags

IAM
[✓] GitHub OIDC provider
[✓] github-actions-ecr-push
[✓] GitHub trust policy
[✓] ECR permissions
[✓] ECS deployment permissions
[✓] iam:PassRole
[✓] github-actions-ecs-passrole
[✓] ecsTaskExecutionRole
[✓] AmazonECSTaskExecutionRolePolicy

ECS
[✓] devops-cluster
[✓] Fargate
[✓] devops-nestjs-app task definition
[✓] CPU = 0.25 vCPU
[✓] Memory = 0.5 GB
[✓] Container port = 3000
[✓] CloudWatch logging
[✓] Task execution role configured

Networking
[✓] ALB-SG
[✓] ECS-SG
[✓] ALB HTTP :80
[✓] ECS TCP :3000 only from ALB-SG
[✓] Public IP enabled for learning setup

Load Balancing
[✓] devops-nestjs-alb
[✓] devops-nestjs-tg
[✓] Target type = IP
[✓] Health check = /health
[✓] ECS service connected to target group
[✓] Target automatically registered
[✓] Target = Healthy

Application
[✓] NestJS listens on 3000
[✓] /health returns HTTP 200
[✓] Docker health check configured

Deployment
[✓] GitHub Actions
[✓] OIDC authentication
[✓] Docker build
[✓] ECR push
[✓] Immutable SHA-tagged image
[✓] ECS task definition deployment
[✓] ECS service update
[✓] Running task
[✓] Healthy target
[✓] CloudWatch logs
[✓] ALB DNS accessible
[✓] /health accessible through ALB

Teardown
[✓] Delete ECS service
[✓] Delete ECS cluster
[✓] Delete ALB
[✓] Delete target group
[✓] Delete CloudWatch log group
[✓] Delete ECR repository
[✓] Remove GitHub IAM role if unused
[✓] Remove ECS execution role if unused
[✓] Remove ALB-SG if unused
[✓] Remove ECS-SG if unused
[✓] Keep default VPC/networking resources
```

## Final Result

The complete deployment path is:

```text
GitHub
   ↓
GitHub Actions
   ↓
OIDC
   ↓
AWS IAM
   ↓
ECR
   ↓
ECS Fargate
   ↓
Target Group
   ↓
Application Load Balancer
   ↓
NestJS :3000
   ↓
/health → HTTP 200
```

The application is now deployed through a complete **GitHub → AWS ECR → ECS Fargate → ALB** CI/CD pipeline with immutable container images, automatic target registration, health checks, and CloudWatch logging.
