<!-- # AWS ECS Fargate Deployment Guide

Complete deployment of a NestJS application using:

- GitHub Actions
- GitHub OIDC
- AWS IAM
- Amazon ECR
- Amazon ECS Fargate
- Application Load Balancer
- Target Group
- Security Groups
- CloudWatch Logs
- ECR Lifecycle Policy

---

# Architecture

```text
                         DEPLOYMENT FLOW

GitHub Repository
       │
       ▼
GitHub Actions
       │
       │ OIDC
       ▼
AWS IAM Role
github-actions-ecr-push
       │
       ▼
Amazon ECR
devops-nestjs-app
       │
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
NestJS Container :3000


                         RUNTIME FLOW

Internet
   │
   │ HTTP :80
   ▼
Application Load Balancer
devops-nestjs-alb
   │
   │ TCP :3000
   ▼
ECS Fargate Task
devops-nestjs-app
   │
   ▼
NestJS Application


                         LOGGING FLOW

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

| Resource | Value |
|---|---|
| AWS Account | `831975835566` |
| AWS Region | `ap-south-1` |
| GitHub Repository | `sunny-bhakta/aws` |
| Branch | `main` |
| ECR Repository | `devops-nestjs-app` |
| ECS Cluster | `devops-cluster` |
| ECS Service | `devops-nestjs-service` |
| Task Definition Family | `devops-nestjs-app` |
| Container Name | `devops-nestjs-app` |
| Container Port | `3000` |
| Target Group | `devops-nestjs-tg` |
| ALB | `devops-nestjs-alb` |
| ALB Security Group | `ALB-SG` |
| ECS Security Group | `ECS-SG` |
| CloudWatch Log Group | `/aws/ecs/devops-nestjs-app` |
| GitHub IAM Role | `github-actions-ecr-push` |
| ECS Execution Role | `ecsTaskExecutionRole` |
| VPC | Default VPC |
| ALB Subnets | `ap-south-1a`, `ap-south-1b` |

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

### Why enable tag immutability?

With immutable tags, an image tag cannot be overwritten.

For example:

```text
app:abc123
```

cannot later be replaced with a different image.

This is safer for deployments because every image remains identifiable.

### Important

Because tag immutability is enabled, avoid using:

```text
latest
```

as the deployment tag if GitHub Actions pushes `latest` on every deployment.

Instead use a unique Git commit SHA:

```text
devops-nestjs-app:6f95dd5193eae50e9067da560b8d26484bddf70d
```

This gives you:

```text
Git commit
     ↓
Docker image
     ↓
ECR tag
     ↓
ECS deployment
```

and makes rollback much easier.

---

# 2. ECR Lifecycle Policy

To prevent the ECR repository from accumulating old images, configure a lifecycle policy.

Go to:

**Amazon ECR → Repositories → `devops-nestjs-app` → Lifecycle policy**

Add:

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

### What this does

ECR keeps the **2 most recent images** and expires older images.

For example:

```text
Image 1  abc111
Image 2  abc222
Image 3  abc333
Image 4  abc444
```

After the lifecycle policy runs, approximately:

```text
abc333
abc444
```

remain.

### Important consideration

Keeping only 2 images is good for a learning/demo environment.

For production, you may want to keep more images, for example:

```text
5
10
20
```

depending on your rollback requirements.

Also remember that lifecycle expiration is not necessarily instantaneous; ECR applies lifecycle policies asynchronously.

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

This role will be assumed by GitHub Actions.

---

# 5. GitHub Actions Trust Policy

The role trust relationship should restrict access to the intended GitHub repository and branch.

Example:

```json
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:sunny-bhakta/aws:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

This allows GitHub Actions from the `main` branch of the repository to assume the role.

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


```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PassECSTaskExecutionRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::831975835566:role/ecsTaskExecutionRole"
    }
  ]
}
```
Policy name:

```text
github-actions-ecs-passrole
```
---

# 8. ECS Task Execution Role

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

because the application currently does not need to call AWS APIs.

---

# 9. Create ECS Cluster

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

# 10. Create CloudWatch Log Group

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

# 11. Create ECS Task Definition

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

> Important: `0.25 vCPU` is **CPU**, not memory. CPU and memory are separate task-definition settings.

Execution role:

```text
ecsTaskExecutionRole
```

Task role:

```text
None
```

---

## Container

Container name:

```text
devops-nestjs-app
```

Image:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:<IMAGE_TAG>
```

For immutable ECR tags, use the Git SHA:

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

## CloudWatch Logging

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

The resulting log stream will look similar to:

```text
ecs/devops-nestjs-app/<task-id>
```

---

# 12. Target Group

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

### Important

For ECS Fargate:

```text
Target type = IP
```

Do **not** use:

```text
Instance
```

ECS automatically registers the Fargate task IP with the target group.

Do not manually register task IPs.

---

# 13. Security Groups

Create two security groups.

---

## ALB-SG

Go to:

**AWS Console → EC2 → Security Groups → Create security group**

Name:

```text
ALB-SG
```

Inbound rule:

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

Source:
ALB-SG
```

Do not use:

```text
0.0.0.0/0
```

for port 3000.

The security flow is:

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

# 14. Application Load Balancer

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

Select at least two Availability Zones, for example:

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

---

# 15. ECS Service

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

# 16. ECS Network Configuration

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

### Production note

For production, normally use:

```text
Private subnets
+
NAT Gateway and/or VPC endpoints
```

For this learning deployment, public subnets with a public IP keep the setup simpler.

---

# 17. ECS Service Load Balancing

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

The complete connection must be:

```text
ALB
  ↓
HTTP :80
  ↓
devops-nestjs-tg
  ↓
ECS task IP :3000
```

### Why this matters

The ECS service is responsible for registering the running Fargate task with the target group.

If:

```text
ECS Service = 1 running task
```

but the target group shows:

```text
Healthy: 0
Unhealthy: 0
```

that usually means the ECS service has **not registered the task with the target group**.

Do not manually register the target.

Fix the ECS service load-balancing configuration instead.

---

# 18. Verify ECS → Target Group Registration

Go to:

**AWS Console → EC2 → Target Groups → `devops-nestjs-tg` → Targets**

Expected:

```text
Target: <Fargate task IP>
Port: 3000
Health: Initial
```

After the health checks succeed:

```text
Health: Healthy
```

Expected final state:

```text
1 target
1 healthy
0 unhealthy
```

The task IP may change whenever ECS replaces the task. ECS handles registration automatically.

---

# 19. NestJS Health Endpoint

The target group health check calls:

```text
/health
```

Your NestJS application must return HTTP `200`.

For example:

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

# 20. Dockerfile

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

# 21. GitHub Repository Variables

Go to:

**GitHub → Repository → Settings → Secrets and variables → Actions → Variables**

Create:

```text
AWS_ROLE_ARN
AWS_REGION
ECS_CLUSTER
ECS_SERVICE
```

Values:

```text
AWS_ROLE_ARN:
arn:aws:iam::831975835566:role/github-actions-ecr-push

AWS_REGION:
ap-south-1

ECS_CLUSTER:
devops-cluster

ECS_SERVICE:
devops-nestjs-service
```

---

# 22. GitHub Actions

Required permission:

```yaml
permissions:
  contents: read
  id-token: write
```

Configure AWS credentials using OIDC:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

---

## Recommended image tagging

Because ECR tag immutability is enabled, use:

```text
Git commit SHA
```

instead of repeatedly pushing:

```text
latest
```

For example:

```yaml
env:
  ECR_REPOSITORY: devops-nestjs-app
  IMAGE_TAG: ${{ github.sha }}
```

Image:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:${{ github.sha }}
```

This gives:

```text
Git commit
    ↓
SHA tag
    ↓
ECR immutable image
    ↓
ECS deployment
```

---

# 23. Deployment Flow

The intended GitHub Actions flow is:

```text
1. Checkout
      ↓
2. npm install
      ↓
3. Run tests
      ↓
4. Build Docker image
      ↓
5. Authenticate to AWS using GitHub OIDC
      ↓
6. Login to ECR
      ↓
7. Push immutable SHA-tagged image
      ↓
8. Register/update ECS task definition
      ↓
9. Update ECS service
      ↓
10. ECS starts new Fargate task
      ↓
11. ECS registers task IP with target group
      ↓
12. ALB performs /health check
      ↓
13. Target becomes Healthy
```

---

# 24. CloudWatch Logs

Go to:

**AWS Console → CloudWatch → Logs → Log groups**

Open:

```text
/aws/ecs/devops-nestjs-app
```

You should see ECS log streams.

The logging path is:

```text
NestJS
   ↓
stdout / stderr
   ↓
ECS awslogs
   ↓
CloudWatch Logs
```

CloudWatch is **not part of the HTTP request path**.

---

# 25. End-to-End Verification

Verify in this order.

### 1. GitHub Actions

Check:

```text
Workflow = Success
```

### 2. ECR

Go to:

**ECR → Repositories → devops-nestjs-app**

Verify an image exists with the Git SHA tag.

Example:

```text
6f95dd5193eae50e9067da560b8d26484bddf70d
```

### 3. ECS

Go to:

**ECS → Clusters → devops-cluster → Services → devops-nestjs-service**

Verify:

```text
Desired: 1
Running: 1
Pending: 0
```

### 4. Target Group

Go to:

**EC2 → Target Groups → devops-nestjs-tg → Targets**

Verify:

```text
1 target
Port: 3000
Health: Healthy
```

### 5. ALB

Go to:

**EC2 → Load Balancers → devops-nestjs-alb**

Copy the ALB DNS name.

Open:

```text
http://<ALB-DNS-NAME>
```

Your NestJS application should respond.

---

# 26. Troubleshooting

## ECS task is not running

Check:

```text
ECS → Cluster → Service → Tasks
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

## ECR image cannot be pulled

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

## Target Group shows 0 Healthy / 0 Unhealthy

If ECS shows:

```text
Running: 1
```

but target group shows:

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

## Target is Unhealthy

Check all of these:

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

## ALB says Listener port unreachable

Check:

**EC2 → Security Groups → ALB-SG → Inbound rules**

You need:

```text
HTTP
TCP
80
0.0.0.0/0
```

Do not add port 3000 to ALB-SG.

---

# 27. Security Group Architecture

Final security flow:

```text
                     INTERNET
                         │
                         │ HTTP :80
                         ▼
                    ┌─────────┐
                    │   ALB   │
                    │ ALB-SG  │
                    └────┬────┘
                         │
                         │ TCP :3000
                         ▼
                  ┌─────────────┐
                  │ ECS Fargate │
                  │   ECS-SG    │
                  └──────┬──────┘
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

---

# 28. Complete Deployment Architecture

```text
                         GitHub
                           │
                           │ OIDC
                           ▼
                github-actions-ecr-push
                           │
                           ▼
                     Amazon ECR
                 devops-nestjs-app
                           │
                           │ image
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
                          │ registration
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
     ▼
CloudWatch Logs
/aws/ecs/devops-nestjs-app
```

---

# 29. Production Improvements

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
```

---

# 30. Cleanup

If this is a temporary learning environment, delete resources in dependency order.

Recommended order:

```text
1. ECS Service
2. ECS Cluster
3. Load Balancer
4. Target Group
5. CloudWatch Log Group
6. ECR Repository
7. IAM roles/policies if no longer needed
8. Task Defination, Security
```

Be careful with:

```text
Default VPC
Security Groups
Subnets
```

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

IAM
[✓] GitHub OIDC provider
[✓] github-actions-ecr-push
[✓] ECR permissions
[✓] ECS deployment permissions
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

Networking
[✓] ALB-SG
[✓] ECS-SG
[✓] ALB HTTP :80
[✓] ECS TCP :3000 only from ALB-SG

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

Deployment
[✓] GitHub Actions
[✓] OIDC authentication
[✓] SHA-based immutable image tag
[✓] ECR push
[✓] ECS deployment
[✓] Running task
[✓] Healthy target
[✓] ALB DNS accessible
``` -->