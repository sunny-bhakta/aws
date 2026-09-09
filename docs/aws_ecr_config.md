# AWS ECR Setup

GitHub Actions OIDC + Amazon ECR push for `sunny-bhakta/aws`.

JSON template (quick edit): `docs/aws_setup_values.template.json`

## 1) Fill these values first

```text
AWS_ACCOUNT_ID=831975835566
OWNER=sunny-bhakta
REPO=aws
AWS_REGION=ap-south-1

ECR_REPOSITORY=devops-nestjs-app

AWS_ROLE_NAME=github-actions-ecr-push
AWS_ROLE_ARN=arn:aws:iam::831975835566:role/github-actions-ecr-push
```


---

## 3) Create OIDC provider
`AWS Console -> IAM -> Identity providers -> Add provider`

Use:

```text
Provider type: OpenID Connect
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
```

---

## 4) Create IAM role
  `AWS Console -> IAM -> Roles -> Create role`

Create a **new dedicated role** — do not reuse an existing one. The trust policy pins this role to a single repo + branch, so reusing a role with broader trust widens the blast radius.

Use **inline** policies (not customer-managed) because these permissions belong to this one role and should be deleted with it. Switch to customer-managed only if a second role later needs the same permissions.

Create role with:

```text
Trusted entity: Web identity
Identity provider: token.actions.githubusercontent.com
Audience: sts.amazonaws.com
GitHub organization: sunny-bhakta (required)
GitHub repository: aws (optional, recommended)
Role name: github-actions-ecr-push
```
### Trust policy (replace existing)

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

> Keep `sub` restricted to your repo + `main` branch.

### Inline policy (`ecr-push`)

`IAM -> Roles -> github-actions-ecr-push -> Permissions -> Add permissions -> Create inline policy -> JSON`

Pick **Create inline policy**, not *Use existing policy* — these policies don't exist as managed policies, and the closest managed option (`AmazonEC2ContainerRegistryPowerUser`) grants access to every repo in the account.

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

`BatchGetImage` and `GetDownloadUrlForLayer` let Docker check which layers already exist before uploading. Without them a push can fail on layer reuse even though `PutImage` is allowed.

## 4.0) ECS cluster
- `AWS Console -> Amazon ECS -> Clusters -> Create cluster`

### Inline policy (`ecs-deploy`) ( Do it next )

Only needed if you also run the `deploy-to-ecs` job. Same click path as above — add a second inline policy on the same role. Replace `<ECS_CLUSTER>` and `<ECS_SERVICE>` with your real names.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescribeClusters",
      "Effect": "Allow",
      "Action": "ecs:DescribeClusters",
      "Resource": "arn:aws:ecs:ap-south-1:831975835566:cluster/<ECS_CLUSTER>"
    },
    {
      "Sid": "UpdateAndDescribeService",
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": "arn:aws:ecs:ap-south-1:831975835566:service/<ECS_CLUSTER>/<ECS_SERVICE>"
    }
  ]
}
```

Name it `ecs-deploy` and attach it to the same role.

---

## 5) Create ECR repository
  `AWS Console -> Amazon ECR -> Repositories -> Create repository`
 
  
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

## 6) Add GitHub repository variables
 `GitHub -> sunny-bhakta/aws -> Settings -> Secrets and variables -> Actions -> Variables`

Set these values:

```text
AWS_REGION=ap-south-1
AWS_ROLE_ARN=arn:aws:iam::831975835566:role/github-actions-ecr-push
ECR_REPOSITORY=devops-nestjs-app
```

---

## 7) Trigger and verify

Push/merge to `main`. Your workflow should run ECR push after CI steps.

Expected image tags in ECR:

```text
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:latest
831975835566.dkr.ecr.ap-south-1.amazonaws.com/devops-nestjs-app:<GITHUB_SHA>
```

---

## 8) Quick troubleshooting

- **OIDC assume-role failure**
  - Check role trust policy `aud` and `sub`
  - Ensure `sts:AssumeRoleWithWebIdentity` and `sts:TagSession` are present

- **`Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`**
  - This is a **trust policy** problem, not a permissions problem
  - The `sub` claim must match the trigger exactly:
    - push to main -> `repo:OWNER/REPO:ref:refs/heads/main`
    - pull request -> `repo:OWNER/REPO:pull_request`
    - other branch -> `repo:OWNER/REPO:ref:refs/heads/<branch>`
  - Confirm the OIDC identity provider exists: `IAM -> Identity providers -> token.actions.githubusercontent.com`
  - Confirm `AWS_ROLE_ARN` in GitHub matches the role ARN character-for-character
  - Confirm the job has `permissions: id-token: write`
  - To isolate, temporarily swap `StringEquals` for `StringLike` with `repo:OWNER/REPO:*`, then narrow it back

- **ECR access denied**
  - Verify role has `ecr:GetAuthorizationToken`
  - Verify repo ARN matches region/account/repo exactly

- **`is not authorized to perform: ecr:GetAuthorizationToken on resource: *`**
  - Cause: the `ecr-push` inline policy is missing on the role
  - Fix: `IAM -> Roles -> github-actions-ecr-push -> Permissions -> Add permissions -> Create inline policy -> JSON`
  - Paste the `ecr-push` policy from section 4, name it `ecr-push`, save
  - `ecr:GetAuthorizationToken` must use `"Resource": "*"` (it cannot be scoped to a repo ARN)
  - Confirm `AWS_ROLE_ARN` in GitHub points to the same role you edited, then re-run the job

- **Image not in ECR**
  - Check GitHub Actions job `push-to-ecr`
  - Confirm AWS auth, ECR login, build, and push all succeeded

- **`is not authorized to perform: ecs:UpdateService` / `ecs:DescribeServices`**
  - Cause: the `ecs-deploy` inline policy is missing on the role
  - Fix: attach the `ecs-deploy` policy from section 4
  - Check the service ARN format is `service/<ECS_CLUSTER>/<ECS_SERVICE>` (cluster name is part of the path)
  - Confirm `ECS_CLUSTER` and `ECS_SERVICE` GitHub variables match the real AWS names exactly
---

## 9) Final checklist

- [ ] OIDC provider created
- [ ] IAM role `github-actions-ecr-push` created
- [ ] Trust policy restricted to `repo:sunny-bhakta/aws:ref:refs/heads/main`
- [ ] Inline policy `ecr-push` attached
- [ ] Inline policy `ecs-deploy` attached (only if using `deploy-to-ecs`)
- [ ] ECR repo `devops-nestjs-app` created in `ap-south-1`
- [ ] Lifecycle policy keeps only 2 images
- [ ] GitHub variables configured
- [ ] Push to `main` succeeds and images appear in ECR