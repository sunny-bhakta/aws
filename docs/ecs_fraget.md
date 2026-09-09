**ECS Fargate + ALB step-by-step**
We already have:

* ECR repository: `devops-nestjs-app`
* Region: `ap-south-1`
* AWS account: `831975835566`
* NestJS container port: `3000`
* Health endpoint: `/health`
* GitHub → AWS OIDC: ✅

---

# Step 1 — Create ECS Cluster

Go to:

**AWS Console → ECS → Clusters → Create cluster**

Use:

```text
Cluster name: devops-cluster
```

For infrastructure:

```text
Infrastructure:  Fargate only
```

Leave the remaining settings at their defaults.

Click:

**Create**

You should then see:

```
ECS → Clusters → devops-cluster
```



## Step 2 — Create ECS Task Execution Role


```
AWS Console → IAM → Roles → Create role → ECS Task Execution Role
```


## Step 2 — Create ECS Task Execution Role

### 1. Open IAM

**AWS Console → IAM → Roles**

Then click:

**Create role**

---

### 2. Select Trusted entity

On **Trusted entity type**, select:

> **AWS service**

You should then see **Service or use case**.

Select:

> **Elastic Container Service**

Depending on the current AWS Console wording, you may see an additional option such as:

> **Elastic Container Service Task**

Select the **Task** option.

So it should effectively be:

```
Trusted entity type:
    AWS service

Service or use case:
    Elastic Container Service

Use case:
    Elastic Container Service Task
```

Then click: **Next**

---

## 3. Add permissions

On the **Add permissions** page, search for:

```
AmazonECSTaskExecutionRolePolicy
```

Select:

> **AmazonECSTaskExecutionRolePolicy**

This AWS-managed policy gives ECS permission to do things such as:

* Pull your Docker image from ECR
* Authenticate to ECR
* Send container logs to CloudWatch Logs

You should see something similar to:

```
AmazonECSTaskExecutionRolePolicy
AWS managed
```

✅ Check the box.

Then click:

**Next**

---

## 4. Name the role

For **Role name**, enter exactly:

```text
ecsTaskExecutionRole
```

Description is optional. You can enter:

```text
ECS Fargate task execution role for devops NestJS app
```

Then click:

**Create role**

---

# 5. Verify the role

Go to:

**AWS Console → IAM → Roles → ecsTaskExecutionRole**

You should see the policy:

```text
AmazonECSTaskExecutionRolePolicy
```

And under **Trust relationships**, it should trust:

```text
ecs-tasks.amazonaws.com
```

The trust relationship should effectively contain:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ecs-tasks.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

### Important

Do **not** use your GitHub role here:

```text
github-actions-ecr-push
```

We have two different roles:

| Role                      | Used by        | Purpose                               |
| ------------------------- | -------------- | ------------------------------------- |
| `github-actions-ecr-push` | GitHub Actions | Push Docker image to ECR              |
| `ecsTaskExecutionRole`    | ECS/Fargate    | Pull image from ECR + CloudWatch logs |

Your architecture is becoming:

```text
GitHub Actions
      |
      | OIDC
      v
github-actions-ecr-push
      |
      | docker push
      v
     ECR
      |
      | image
      v
ECS Fargate
      |
      | uses
      v
ecsTaskExecutionRole
```

**Stop here after creating `ecsTaskExecutionRole`.**
