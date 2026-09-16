<!-- # AWS ECS Fargate Deployment

## Architecture

```text
GitHub Actions
      |
      | OIDC
      v
AWS IAM Role
      |
      v
ECR Repository
      |
      | Docker image
      v
ECS Fargate Service
      |
      v
Application Load Balancer
      |
      v
NestJS application :3000
      |
      v
CloudWatch Logs
```

## Project Values

| Item | Value | value1 |
|---|---|---|
| AWS Account | `831975835566` ||
| AWS Region | `ap-south-1` ||
| ECR Repository | `devops-nestjs-app` ||
| ECS Cluster | `devops-cluster` ||
| ECS Service | `devops-nestjs-service` ||
| Task Definition Family | `devops-nestjs-app` ||
| Container Port | `3000` ||
| CloudWatch Log Group | `/aws/ecs/devops-nestjs-app` ||
| GitHub Actions IAM Role | `github-actions-ecr-push` ||
| ECS Task Execution Role | `ecsTaskExecutionRole` ||

---

# 1. ECR Repository

`AWS Console → ECR → Repositories → Create repository`

| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Visibility** | `Private`                              |
| **Repository name**  | `devops-nestjs-app` |
| **Image tag mutability**      | `Mutable (In future use Immutable instead)`                           |
| **Scan on push**      | `Enabled`                           |
| **Encryption**      | `AES-256`                           |

**The image URI will be:**

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:latest
```

Create repository with:

```text
Repository name: devops-nestjs-app
Tag immutability: Enabled
Encryption: AES-256
Scan on push: Enabled (if available)
```

### Lifecycle policy (keep latest 2 images)
`Amazon ECR -> Repositories -> devops-nestjs-app -> Lifecycle policy`

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
---
---

# 2. GitHub Actions IAM Role

## Proiders
`AWS Console → IAM → Identity providers → Add provider`
| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Provider name** | `OpenID Connect`                              |
| **Provider URL**  | `https://token.actions.githubusercontent.com` |
| **Audience**      | `sts.amazonaws.com`                           |

## Create Role
`AWS Console → IAM → Roles → Create role`

| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Trusted entity type** | `Web identity`                              |
| **Identity provider**  | `token.actions.githubusercontent.com` |
| **Audience**      | `sts.amazonaws.com`                           |
| **GitHub organization**      | `sunny-bhakta`                           |
| **GitHub repository - optional**      | `aws`                           |
|      - |-|
|     -  |-|
| **Role name**      | `github-actions-ecr-push`                           |

## Trust Policy

`AWS Console → IAM → Roles → github-actions-ecr-push -> Trust relationships -> Edit Trust Policy`

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
          "token.actions.githubusercontent.com:sub": "repo:sunny-bhakta@77013204/aws@1361501698:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## ECR permissions
`AWS Console → IAM → Roles → github-actions-ecr-push -> Permissions -> Add Permission -> Create inline policy -> Json`


| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Policy name** | `ecr-push`                              |

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

| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Policy name** | `github-actions-ecs-deploy`                              |

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

---

# 3. ECS Task Execution Role

`AWS Console → IAM → Roles → Create role`

| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Trusted entity** | `AWS service` |
| **Use case** | `Elastic Container Service`                              |
| **Use case type** | `Elastic Container Service Task`                              |
|-|-|
|-|-|
| **Permissions policies** | `AmazonECSTaskExecutionRolePolicy`                              |
|-|-|
|       -       |      -                                    |
| **Policy name** | `ecsTaskExecutionRole`                          

This role allows ECS to:

- Pull the private image from ECR
- Send container logs to CloudWatch

Do not confuse this role with the GitHub Actions role.

---

# 4. Create ECS Cluster

`AWS Console → ECS → Clusters → Create cluster`

| Field             | Value                                         |
| ----------------- | --------------------------------------------- |
| **Cluster name** | `devops-cluster` |
| **Infrastructure - advanced** | `Fargate only` |
.

---

# 5. Create CloudWatch Log Group

Create CloudWatch before creating the ECS task definition.

`AWS Console → CloudWatch → Logs → Log Management → Log groups → Create log group`

| Field          | Value                        |
| -------------- | ---------------------------- |
| **Log group name** | `/aws/ecs/devops-nestjs-app` |
| **Log class**      | `Standard`                   |


## CloudWatch flow

```text
NestJS container
      |
      v
ECS awslogs driver
      |
      v
CloudWatch
      |
      v
/aws/ecs/devops-nestjs-app
```

---

# 6. Create ECS Task Definition

`AWS Console → ECS → Task definitions → Create new task definition`

## Task definition
| Field          | Value                        |
| -------------- | ---------------------------- |
|**Task definition family**|`devops-nestjs-app`|
|**Launch type / infrastructure**|`Fargate`|
|**Memory**|`0.25 vCPU`|
|**Task role**|`None`|
|**Task execution role**|`ecsTaskExecutionRole`|
|**Image URI**| `831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:latest`|
|**Container name**|`devops-nestjs-app`|
|**Container port**|`3000`|
|**Protocol**| `TCP`|
|**Optional port name**| `http`|
|-|-|
|**Log collection**|`Select - Use log collection`|
|**Destination**|`Amazon Cloudwatch`|
|**awslogs-group**|`/aws/ecs/devops-nestjs-app`|
|**awslogs-region**|`ap-south-1`|
|**awslogs-stream-prefix**|`ecs`|
|**awslogs-create-group**|true|

---

# 7. Create Target Group

`AWS Console → EC2 → Target Groups → Create target group`

| Field          | Value                        |
| -------------- | ---------------------------- |
|**Target type**|`IP addresses`|
|**Target group name**|`devops-nestjs-tg`|
|**Protocol**|`HTTP`|
|**Port**|`3000`|
|**VPC**|`default`|
|**Protocol**| `HTTP`|
|**Health check path**| `/health`|
|-|-|
|**Advanced Health Check**|
|**Port**|`traffic-port`|

Do not manually register ECS task IPs in the target group. ECS will register them when the service is created.

---

# 8. Create Application Load Balancer

`AWS Console → EC2 → Load Balancers → Create Load Balancer ( dropdown ) -> Application Load Balancer`

| Field          | Value                        |
| -------------- | ---------------------------- |
|**Load balancer name**|`devops-nestjs-alb`|
| Scheme| `Internet-facing`|
| IP address type| `IPv4`|
|-|-|
|-|-|
| Network Mapping|
|Load balancer name|`devops-nestjs-alb`|
|Availability Zones and subnet| `ap-south-1a , ap-south-1b`|
|-|-|
|-|-|
| Security group|
|Load balancer name|`devops-nestjs-alb`|


## Security group

Create:

```text
ALB-SG
```

Inbound rule:

```text
Type: HTTP
Port: 80
Source: 0.0.0.0/0
```

## Listener

Set:

```text
HTTP : 80
```

Forward traffic to:

```text
devops-nestjs-tg
```

Create the load balancer.

---

# 9. ECS Security Group

Create a security group for the ECS tasks.

`AWS Console → EC2 → Security Groups → Create security group`

Name:

```text
ECS-SG
```

Inbound rule:

```text
Type: Custom TCP
Port: 3000
Source: ALB-SG
```

Important:

Do NOT open port 3000 to:

```text
0.0.0.0/0
```

Only the Application Load Balancer should be allowed to access the NestJS container.

---

# 10. Create ECS Fargate Service

AWS Console → **ECS → Clusters → devops-cluster**

Select:

**Create service**

## Environment

Set:

- Compute options: `Launch type`
- Launch type: `Fargate`
- Task definition family:

```text
devops-nestjs-app
```

Select the latest revision.

## Service

Set:

- Service name:

```text
devops-nestjs-service
```

- Desired tasks:

```text
1
```

---

# 11. Network Configuration

Select the VPC used by the ALB.

Select subnets.

For a simple learning setup, the ECS tasks can use public subnets with public IP enabled.

Set:

```text
Auto-assign public IP: Enabled
```

Security group:

```text
ECS-SG
```

For production, prefer private subnets with NAT Gateway and/or VPC endpoints instead of exposing task public IPs.

---

# 12. Load Balancing

Enable load balancing.

Choose:

```text
Application Load Balancer
```

Select:

```text
devops-nestjs-alb
```

Listener:

```text
HTTP : 80
```

Target group:

```text
devops-nestjs-tg
```

Container:

```text
devops-nestjs-app:3000
```

Create the service.

---

# 13. Verify ECS Deployment
### (check for AWS Console → ECR → Repositories → devops-nestjs-app → Images)

AWS Console → **ECS → Clusters → devops-cluster → Services → devops-nestjs-service**

Check:

```text
Desired tasks: 1
Running tasks: 1
Pending tasks: 0
```

Open the task.

Check that the container is:

```text
Running
```

---

# 14. Verify Target Group

AWS Console → **EC2 → Target Groups → devops-nestjs-tg → Targets**

The ECS task should appear automatically.

Check:

```text
Health status: Healthy
```

If it says `Unhealthy`, check:

1. NestJS application is listening on port `3000`
2. `/health` returns HTTP 200
3. ECS-SG allows TCP `3000` from ALB-SG
4. Container is running
5. Target group uses port `3000`
6. Health check path is `/health`

---
IF above fails
GitHub → sunny-bhakta/aws → Settings → Secrets and variables → Actions → Variables

Under Repository variables, add:

Name	Value
ECS_CLUSTER	devops-cluster
ECS_SERVICE	devops-nestjs-service

Make sure the names are exactly:

ECS_CLUSTER
ECS_SERVICE
---

# 15. Test the Application

AWS Console → **EC2 → Load Balancers → devops-nestjs-alb**

Copy the DNS name.

It will look similar to:

```text
devops-nestjs-alb-xxxxxxxx.ap-south-1.elb.amazonaws.com
```

Open:

```text
http://<ALB-DNS-NAME>/health
```

Expected result:

```text
HTTP 200
```

Then test the NestJS application:

```text
http://<ALB-DNS-NAME>/
```

---

# 16. Check CloudWatch Logs

AWS Console → **CloudWatch → Logs → Log Management → Log groups**

Open:

```text
/aws/ecs/devops-nestjs-app
```

You should see log streams similar to:

```text
ecs/devops-nestjs-app/xxxxxxxxxxxxxxxx
```

Open the stream to see NestJS container logs.

If there are no logs, check:

1. `ecsTaskExecutionRole` is attached to the task definition.
2. `AmazonECSTaskExecutionRolePolicy` is attached to that role.
3. The CloudWatch log group name is correct.
4. The AWS region is `ap-south-1`.
5. The container is actually starting.

---

# 17. GitHub Actions Deployment

GitHub Actions should:

```text
1. Checkout code
2. Install dependencies
3. Run tests
4. Build Docker image
5. Authenticate to AWS using OIDC
6. Login to ECR
7. Push Docker image
8. Deploy the new image to ECS
```

GitHub Actions permissions:

```yaml
permissions:
  contents: read
  id-token: write
```

AWS credentials:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

---

# 18. Recommended Image Tagging

Prefer an immutable Git commit SHA tag:

```text
${{ github.sha }}
```

For example:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:abc123...
```

You can also push:

```text
latest
```

However, ECS deployments are more reliable when the task definition explicitly references the immutable SHA tag.

Recommended flow:

```text
Git commit
    ↓
GitHub Actions
    ↓
Docker image
    ↓
ECR :github-sha
    ↓
New ECS task definition revision
    ↓
ECS service deployment
    ↓
ALB
    ↓
Users
```

---

# 19. Dockerfile

The application Dockerfile should expose port `3000` and start the compiled NestJS application.

Example:

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

# 20. Troubleshooting

## ECS task stops immediately

AWS Console → ECS → Cluster → Service → Tasks → Stopped

Open the stopped task and check:

```text
Stopped reason
```

Then check:

```text
Container → Exit code
```

Also inspect:

```text
CloudWatch Logs
```

---

## Cannot pull image from ECR

Check:

```text
ecsTaskExecutionRole
```

It should have:

```text
AmazonECSTaskExecutionRolePolicy
```

Also verify the image URI:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:latest
```

---

## Target is unhealthy

Check:

```text
ALB-SG
    ↓
allows HTTP 80 from internet

ECS-SG
    ↓
allows TCP 3000 from ALB-SG
```

Also test:

```text
/health
```

inside the application.

---

## GitHub Actions cannot assume AWS role

Check the GitHub OIDC trust policy.

The subject for the main branch is:

```text
repo:sunny-bhakta@77013204/aws@1361501698:ref:refs/heads/main
```

The audience must be:

```text
sts.amazonaws.com
```

---

## GitHub Actions cannot push to ECR

The GitHub Actions IAM role needs:

```text
ecr:GetAuthorizationToken
```

on:

```text
*
```

And these repository permissions:

```text
ecr:BatchCheckLayerAvailability
ecr:CompleteLayerUpload
ecr:InitiateLayerUpload
ecr:PutImage
ecr:UploadLayerPart
```

---

# 21. Cleanup / Tear Down

Delete resources when the environment is no longer required.

Recommended order:

```text
1. ECS Service
2. ECS Cluster, Task Defination, Security
3. Application Load Balancer
4. Target Group
5. CloudWatch Log Group
6. ECR Repository
7. IAM roles if no longer needed
```

If you created a dedicated VPC and its networking resources specifically for this project, delete those only after the resources using them have been removed.

Do not delete shared VPC resources that are used by other applications.

---

# 22. Final Architecture

```text
                         Internet
                            |
                            v
                 +---------------------+
                 | Application Load    |
                 | Balancer :80        |
                 +----------+----------+
                            |
                            | HTTP :3000
                            v
                 +---------------------+
                 | ECS Fargate Service |
                 |                     |
                 | NestJS Container    |
                 | Port 3000           |
                 +----------+----------+
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          CloudWatch Logs            ECR
       /aws/ecs/devops-nestjs-app   Docker Image

GitHub Actions
      |
      | OIDC
      v
github-actions-ecr-push
      |
      v
     ECR
      |
      v
ECS deployment
```

## Important distinction

There are three different AWS IAM responsibilities:

| Role | Used by | Purpose |
|---|---|---|
| `github-actions-ecr-push` | GitHub Actions | Authenticate GitHub Actions and push images to ECR |
| `ecsTaskExecutionRole` | ECS | Pull ECR image and send logs to CloudWatch |
| Task role | NestJS container | AWS API permissions required by the application |

For the current application, the **Task role can remain None**. -->
