# AWS GitHub Actions: next steps

You already have CI + Docker + ECR push in place. The next step is automated ECS deployment after image push.

## What now happens in `.github/workflows/ci.yml`

On push to `main`:

1. `build-and-test` runs lint, build, unit tests.
2. `docker` builds and smoke-tests the container.
3. `push-to-ecr` pushes `${GITHUB_SHA}` and `latest` image tags.
4. `deploy-to-ecs` forces a new ECS deployment and waits until service is stable.

## Required GitHub repository variables

Add these under **Settings → Secrets and variables → Actions → Variables**:

- `AWS_REGION` (example: `ap-south-1`)
- `AWS_ROLE_ARN` (IAM role assumed by GitHub OIDC)
- `ECR_REPOSITORY` (example: `devops-nestjs-app`)
- `ECS_CLUSTER` (example: `my-prod-cluster`)
- `ECS_SERVICE` (example: `nestjs-api-service`)

## AWS IAM role for GitHub OIDC

Your `AWS_ROLE_ARN` role should trust GitHub OIDC and allow:

- ECR push/pull permissions for your repo image
- `ecs:UpdateService`
- `ecs:DescribeServices`
- `ecs:DescribeClusters`

### Minimal trust policy idea

Scope `sub` to your repository and branch:

- `repo:<ORG>/<REPO>:ref:refs/heads/main`

## ECS prerequisites

Before first automated deploy, ensure:

- ECS service exists and is healthy.
- Task definition uses your ECR image repo.
- Service deployment controller is the default ECS rolling update.

## Triggering deployment

- Merge/push to `main` to run full pipeline and deploy.
- You can also run workflow manually with **Run workflow**.

## Troubleshooting

- **Missing variable errors** in deploy job: confirm `ECS_CLUSTER` and `ECS_SERVICE` variable names exactly.
- **ECR access denied**: verify ECR permissions on `AWS_ROLE_ARN`.
- **ECS service not stabilizing**: check task logs, security groups, target group health checks, and container port mapping.

## Fill-and-run checklist (Console)

Use this as your one-page execution sheet.

### Console navigation paths (quick access)

Use these exact paths in each console:

- **ECR repository**
	- `AWS Console -> Amazon ECR -> Repositories -> Create repository`

- **ECS cluster**
	- `AWS Console -> Amazon ECS -> Clusters -> Create cluster`

- **ECS task definition**
	- `AWS Console -> Amazon ECS -> Task definitions -> Create new task definition`

- **ECS service**
	- `AWS Console -> Amazon ECS -> Clusters -> <your-cluster> -> Services -> Create`

- **OIDC provider for GitHub Actions**
	- `AWS Console -> IAM -> Identity providers -> Add provider`
	- Provider URL: `https://token.actions.githubusercontent.com`
	- Audience: `sts.amazonaws.com`

- **IAM role for GitHub Actions**
	- `AWS Console -> IAM -> Roles -> Create role -> Web identity`
	- After create:
		- `IAM -> Roles -> <role-name> -> Trust relationships`
		- `IAM -> Roles -> <role-name> -> Permissions`

- **GitHub repository variables**
	- `GitHub -> <ORG>/<REPO> -> Settings -> Secrets and variables -> Actions -> Variables -> New repository variable`

### A) Fill these 6 values first

```text
ORG=<your-github-org-or-username>
REPO=aws
AWS_REGION=<example: ap-south-1>
AWS_ACCOUNT_ID=<12-digit-account-id>
ECS_CLUSTER=<example: my-prod-cluster>
ECS_SERVICE=<example: nestjs-api-service>
```

Optional (recommended defaults used in this repo):

```text
ECR_REPOSITORY=devops-nestjs-app
AWS_ROLE_NAME=github-actions-ecr-ecs-role
```

### B) AWS Console checklist

- [ ] **ECR repository created**
	- Service: **Amazon ECR**
	- Name: `${ECR_REPOSITORY}` (example: `devops-nestjs-app`)

- [ ] **ECS cluster created**
	- Service: **Amazon ECS -> Clusters**
	- Name: `${ECS_CLUSTER}`

- [ ] **ECS task definition created**
	- Launch type: **Fargate**
	- Container image:
		`${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:latest`
	- Container port: `3000`

- [ ] **ECS service created**
	- Cluster: `${ECS_CLUSTER}`
	- Service name: `${ECS_SERVICE}`
	- Desired tasks: `1`
	- Health check path: `/health` (if behind ALB)

- [ ] **OIDC identity provider added**
	- Service: **IAM -> Identity providers**
	- Provider URL: `https://token.actions.githubusercontent.com`
	- Audience: `sts.amazonaws.com`

- [ ] **IAM role for GitHub Actions created**
	- Role name: `${AWS_ROLE_NAME}`
	- Trusted entity: Web identity (GitHub OIDC)
	- Trust scope: `repo:${ORG}/${REPO}:ref:refs/heads/main`
	- Permissions: ECR push + ECS update/describe

### C) GitHub Console checklist

Repository: `${ORG}/${REPO}`

- [ ] Go to **Settings -> Secrets and variables -> Actions -> Variables**
- [ ] Add `AWS_REGION=${AWS_REGION}`
- [ ] Add `AWS_ROLE_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}`
- [ ] Add `ECR_REPOSITORY=${ECR_REPOSITORY}`
- [ ] Add `ECS_CLUSTER=${ECS_CLUSTER}`
- [ ] Add `ECS_SERVICE=${ECS_SERVICE}`

### D) Final verification checklist

- [ ] Push/merge to `main` (or run workflow manually)
- [ ] `build-and-test` job passes
- [ ] `docker` job passes
- [ ] `push-to-ecr` job passes
- [ ] `deploy-to-ecs` job passes
- [ ] ECS service reaches stable state

## Copy-paste value templates

Use this section as a quick-fill template for your own account/repo values.

### 1) Master values (fill once)

```text
ORG=your-github-org-or-username
REPO=aws
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=123456789012

ECR_REPOSITORY=devops-nestjs-app
ECS_CLUSTER=my-prod-cluster
ECS_SERVICE=nestjs-api-service

AWS_ROLE_NAME=github-actions-ecr-ecs-role
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-ecr-ecs-role
```

### 2) GitHub Actions variables (copy these exact keys)

Set in: **GitHub -> Settings -> Secrets and variables -> Actions -> Variables**

```text
AWS_REGION=ap-south-1
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-ecr-ecs-role
ECR_REPOSITORY=devops-nestjs-app
ECS_CLUSTER=my-prod-cluster
ECS_SERVICE=nestjs-api-service
```

### 3) IAM trust policy template (OIDC)

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
			},
			"Action": "sts:AssumeRoleWithWebIdentity",
			"Condition": {
				"StringEquals": {
					"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
				},
				"StringLike": {
					"token.actions.githubusercontent.com:sub": "repo:your-github-org-or-username/aws:ref:refs/heads/main"
				}
			}
		}
	]
}
```

### 4) IAM permissions policy template (ECR + ECS)

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "ECRAuth",
			"Effect": "Allow",
			"Action": "ecr:GetAuthorizationToken",
			"Resource": "*"
		},
		{
			"Sid": "ECRPushPull",
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
			"Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/devops-nestjs-app"
		},
		{
			"Sid": "ECSDeploy",
			"Effect": "Allow",
			"Action": [
				"ecs:UpdateService",
				"ecs:DescribeServices",
				"ecs:DescribeClusters"
			],
			"Resource": [
				"arn:aws:ecs:ap-south-1:123456789012:cluster/my-prod-cluster",
				"arn:aws:ecs:ap-south-1:123456789012:service/my-prod-cluster/nestjs-api-service"
			]
		}
	]
}
```

### 5) ECS image URI template

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:latest
```
