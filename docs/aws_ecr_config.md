# AWS ECR Setup (Quick Guide)

This guide configures GitHub Actions OIDC + Amazon ECR push for `sunny-bhakta/devops`.

## 1) Fill these values first

```text
AWS_ACCOUNT_ID=831975835566
OWNER=sunny-bhakta
REPO=devops
AWS_REGION=ap-south-1

ECR_REPOSITORY=devops-nestjs-app

AWS_ROLE_NAME=github-actions-ecr-push
AWS_ROLE_ARN=arn:aws:iam::831975835566:role/github-actions-ecr-push
```

---

## 2) Console paths (where to configure)

- OIDC provider:
  `AWS Console -> IAM -> Identity providers -> Add provider`
- IAM role:
  `AWS Console -> IAM -> Roles -> Create role`
- ECR repository:
  `AWS Console -> Amazon ECR -> Repositories -> Create repository`
- ECR lifecycle policy:
  `Amazon ECR -> Repositories -> devops-nestjs-app -> Lifecycle policy`
- GitHub variables:
  `GitHub -> sunny-bhakta/devops -> Settings -> Secrets and variables -> Actions -> Variables`

---

## 3) Create OIDC provider

Use:

```text
Provider type: OpenID Connect
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
```

---

## 4) Create IAM role

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
      "Action": [
        "sts:AssumeRoleWithWebIdentity",
        "sts:TagSession"
      ],
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

> Keep `sub` restricted to your repo + `main` branch.

### Inline policy (`ecr-push`)

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
        "ecr:CompleteLayerUpload",
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

## 5) Create ECR repository

Create repository with:

```text
Repository name: devops-nestjs-app
Tag immutability: Enabled
Encryption: AES-256
Scan on push: Enabled (if available)
```

### Lifecycle policy (keep latest 2 images)

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

- **ECR access denied**
  - Verify role has `ecr:GetAuthorizationToken`
  - Verify repo ARN matches region/account/repo exactly

- **Image not in ECR**
  - Check GitHub Actions job `push-to-ecr`
  - Confirm AWS auth, ECR login, build, and push all succeeded

---

## 9) Final checklist

- [ ] OIDC provider created
- [ ] IAM role `github-actions-ecr-push` created
- [ ] Trust policy restricted to `repo:sunny-bhakta/devops:ref:refs/heads/main`
- [ ] Inline policy `ecr-push` attached
- [ ] ECR repo `devops-nestjs-app` created in `ap-south-1`
- [ ] Lifecycle policy keeps only 2 images
- [ ] GitHub variables configured
- [ ] Push to `main` succeeds and images appear in ECR