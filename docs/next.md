# AWS DevOps — Next Learning Steps

Now that the following deployment is working:

```text
GitHub
   ↓
GitHub Actions
   ↓
OIDC + IAM
   ↓
ECR
   ↓
ECS Fargate
   ↓
Target Group
   ↓
Application Load Balancer
   ↓
NestJS
   ↓
CloudWatch Logs
```

the next goal is to move from a **working AWS deployment** to a **production-style architecture**.

---

# 1. Docker — Go Deeper

You already have a working multi-stage Dockerfile. Next, understand Docker beyond simply building images.

## Learn

* Multi-stage builds
* Docker image layers
* Docker build cache
* `.dockerignore`
* Environment variables
* Docker networking
* Container-to-container communication
* Volumes
* Container health checks
* Image size optimization
* Container security
* Docker Compose
* Debugging containers

## Practical Project

Run:

```text
NestJS
PostgreSQL
Redis
```

using Docker Compose.

Example:

```text
┌──────────────┐
│   NestJS     │
│   Container  │
└──────┬───────┘
       │
 ┌─────┴─────┐
 │           │
 ▼           ▼
PostgreSQL  Redis
```

### Goal

Understand how multiple containers communicate with each other before moving deeper into AWS networking.

---

# 2. AWS Networking — Most Important Next Step

This should be your **next major AWS topic**.

You have already used:

* VPC
* Subnets
* Security Groups
* ALB
* Internet access

Now understand how they actually work together.

## Learn

### VPC

* VPC
* CIDR
* Subnets
* Availability Zones
* Public subnet
* Private subnet

### Routing

* Route tables
* Internet Gateway
* NAT Gateway
* Default routes
* Public vs private routing

### Security

* Security Groups
* NACLs
* Inbound rules
* Outbound rules
* Security-group-to-security-group communication

## Understand This Architecture

Your current learning setup is roughly:

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public ALB
   │
   ▼
ECS Fargate
   │
   ▼
Application
```

The production-style architecture you should understand is:

```text
                    Internet
                       │
                       ▼
                ┌─────────────┐
                │ Public ALB  │
                └──────┬──────┘
                       │
              ┌────────▼────────┐
              │ Private Subnets │
              │                 │
              │   ECS Fargate   │
              │       │         │
              │       ▼         │
              │      RDS        │
              └─────────────────┘
```

### Goal

Be able to explain:

> Why is the ALB public while ECS and RDS should normally be private?

This is one of the most important AWS networking concepts for real projects.

---

# 3. Amazon RDS PostgreSQL

Since your application already uses PostgreSQL knowledge, the next step is deploying PostgreSQL properly on AWS.

## Learn

* RDS
* DB subnet groups
* Security groups for RDS
* PostgreSQL configuration
* Automated backups
* Snapshots
* Multi-AZ
* Encryption
* Storage
* Connection limits
* Connection pooling
* Database migrations

## Architecture

```text
Internet
   │
   ▼
ALB
   │
   ▼
ECS Fargate
   │
   │ TCP 5432
   ▼
RDS PostgreSQL
```

Security should be:

```text
Internet
   X
   │
   X
RDS

ECS-SG
   │
   │ PostgreSQL 5432
   ▼
RDS-SG
```

RDS should **not** be publicly accessible for this architecture.

## Practical Project

Deploy:

```text
NestJS → ECS Fargate → RDS PostgreSQL
```

Then configure:

* Database migrations
* Connection pooling
* Environment configuration
* Security groups

---

# 4. AWS Secrets Manager / Parameter Store

Do not keep database passwords and application secrets directly in:

```text
GitHub repository
Dockerfile
source code
ECS task definition
```

Instead learn:

* AWS Secrets Manager
* Systems Manager Parameter Store
* ECS secret injection
* IAM permissions
* Secret rotation concepts

## Example

Instead of:

```env
DATABASE_PASSWORD=my-password
JWT_SECRET=my-secret
```

use:

```text
AWS Secrets Manager
        │
        ▼
ECS Task
        │
        ▼
NestJS
```

### Goal

Understand how applications securely receive secrets at runtime.

---

# 5. ECS Fargate — Production Architecture

You already know how to get a task running.

Now learn how ECS behaves in production.

## Learn

* Desired count
* Running count
* Task placement
* Task health
* Deployment strategies
* Rolling deployments
* Minimum healthy percentage
* Maximum percentage
* CPU
* Memory
* Health checks
* Service Auto Scaling
* Target tracking
* ECS Exec
* Service discovery
* Task failures
* Deployment failures

## Move Toward

```text
                    ALB
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
       ECS Task              ECS Task
          │                     │
          └──────────┬──────────┘
                     │
                     ▼
                    RDS
```

Instead of:

```text
1 ECS Task
```

learn how to run:

```text
2+ ECS Tasks
```

across multiple Availability Zones.

---

# 6. HTTPS with ACM

After HTTP works, learn HTTPS.

## Learn

* AWS Certificate Manager
* TLS/SSL certificates
* HTTPS listeners
* HTTP → HTTPS redirect
* ALB certificates

Architecture:

```text
User
 │
 │ HTTPS :443
 ▼
ALB
 │
 │ HTTP :3000
 ▼
ECS
```

The TLS termination happens at the ALB.

---

# 7. Route 53

Once HTTPS is working, connect a domain.

## Learn

* Hosted zones
* DNS records
* A records
* Alias records
* CNAME
* Domain → ALB
* DNS propagation

Final flow:

```text
myapp.com
    │
    ▼
Route 53
    │
    ▼
ALB
    │
    ▼
ECS
    │
    ▼
RDS
```

---

# 8. Terraform — Major Next Skill

Once you understand AWS manually, learn Infrastructure as Code.

Terraform should come **after you understand the AWS resources**, not before.

## Learn

### Terraform Fundamentals

* Providers
* Resources
* Variables
* Outputs
* Data sources
* Locals
* Modules
* State
* `terraform init`
* `terraform plan`
* `terraform apply`
* `terraform destroy`

## Rebuild Your Project Using Terraform

Eventually Terraform should create:

```text
VPC
├── Subnets
├── Route Tables
├── Internet Gateway
├── NAT Gateway
│
├── ALB
├── Target Group
├── Security Groups
│
├── ECS Cluster
├── ECS Service
├── Task Definition
│
├── ECR
├── RDS
├── IAM
├── CloudWatch
└── Secrets Manager
```

Instead of manually clicking through AWS Console.

### Goal

You should be able to destroy the environment and recreate it with:

```bash
terraform apply
```

---

# 9. Improve CI/CD

Your GitHub Actions pipeline already works.

Next, make it more production-oriented.

## Current

```text
Git Push
   ↓
GitHub Actions
   ↓
Test
   ↓
Build
   ↓
Docker Build
   ↓
ECR Push
   ↓
ECS Deploy
```

## Improve It

Add:

* Unit tests
* Linting
* Docker image scanning
* Security scanning
* Immutable image tags
* Git SHA tags
* Deployment verification
* ECS rollout monitoring
* Automatic rollback concepts
* Environment separation

## Add DevSecOps Scanning (Windows + Linux)

To make CI/CD consulting-ready, add a dedicated **DevSecOps security stage**.

### Security/quality tools to include

* **GitHub Advanced Security / CodeQL** (SAST code scanning)
* **Snyk** (SCA dependency + container + IaC scan)
* **GitGuardian** (secrets detection)
* **SonarQube / SonarCloud** (code quality + security hotspots)
* **CAST Highlight** (software risk + architecture/technical debt insights)
* **Copilot error analysis** (faster triage and fix suggestions for CI failures)

### Windows scan support

Keep at least one security job runnable on:

* `ubuntu-latest` (primary CI)
* `windows-latest` (Windows compatibility/security validation)

This helps catch OS-specific dependency and tooling issues before release.

### Recommended CI/CD security gates

Use these as policy gates before deployment:

1. Secret scan must pass (GitGuardian / secret scanning)
2. SAST must pass (CodeQL/Sonar) with no new critical issues
3. Dependency scan must pass (Snyk) with no critical vulns
4. Container image scan must pass (Snyk/Trivy) before ECR push
5. IaC scan must pass (`terraform/` checks) before `terraform apply`

### Minimal rollout plan

Phase 1 (quick win):

* Add GitGuardian + Snyk dependency scan + CodeQL

Phase 2:

* Add Sonar analysis and quality gate
* Add container scan and Terraform IaC scan

Phase 3:

* Add CAST Highlight monthly trend reporting
* Add Copilot-based error triage workflow for failed pipelines

### Example enhanced pipeline flow

```text
Git Push
   ↓
Build + Unit Test + Lint
   ↓
Secret Scan (GitGuardian)
   ↓
SAST (CodeQL / Sonar)
   ↓
SCA + Container + IaC Scan (Snyk)
   ↓
Docker Build
   ↓
ECR Push (only if gates pass)
   ↓
ECS Deploy
   ↓
Post-deploy health verification
```

### Operational note

Treat findings by severity:

* **Critical/High**: block deployment
* **Medium**: allow with tracked ticket + SLA
* **Low**: backlog and fix in regular hardening sprints

Use image tags such as:

```text
devops-nestjs-app:<git-sha>
```

rather than relying on:

```text
latest
```

This fits well with the immutable ECR setup you already created.

---

# 10. CloudWatch & Observability

You already have CloudWatch logs working.

Now go deeper.

## Learn

* CloudWatch Logs
* CloudWatch Metrics
* CloudWatch Alarms
* Dashboards
* ECS metrics
* ALB metrics
* CPU utilization
* Memory utilization
* Request count
* Target response time
* HTTP 4xx
* HTTP 5xx

## Example

Create alarms for:

```text
CPU > 70%
Memory > 80%
HTTP 5xx > threshold
Unhealthy targets > 0
```

Then understand:

```text
Application
    │
    ├── Logs ──────► CloudWatch Logs
    │
    └── Metrics ───► CloudWatch Metrics
                         │
                         ▼
                      Alarms
```

---

# 11. Application Observability

After basic CloudWatch, learn application-level observability.

## Learn

* Structured logging
* Correlation IDs
* Request IDs
* Metrics
* Distributed tracing
* OpenTelemetry
* AWS X-Ray concepts

For example:

```text
Request
   │
   ▼
ALB
   │
   ▼
ECS
   │
   ├── NestJS
   │
   ├── PostgreSQL
   │
   └── Redis
```

You should eventually be able to trace a request through the system.

---

# 12. AWS Security

This should become increasingly important as you move toward consulting work.

## Learn

### IAM

* Users
* Roles
* Policies
* Trust policies
* Least privilege
* `iam:PassRole`
* Service roles
* Resource-based policies

### AWS Security

* Security Groups
* NACLs
* KMS
* Secrets Manager
* VPC endpoints
* CloudTrail
* GuardDuty
* ECR scanning
* Container security
* Dependency scanning

### Important Principle

Avoid:

```text
0.0.0.0/0
```

unless public access is actually required.

For example:

```text
Internet
   │
   ▼
ALB-SG
   │
   │ only ALB-SG
   ▼
ECS-SG
   │
   │ only ECS-SG
   ▼
RDS-SG
```

---

# 13. Kubernetes — Learn Later

Do not jump into Kubernetes immediately.

First become comfortable with:

```text
Docker
   ↓
AWS Networking
   ↓
ECS
   ↓
RDS
   ↓
Terraform
   ↓
CI/CD
   ↓
Observability
   ↓
Security
```

Then learn Kubernetes.

## Kubernetes Topics

* Pods
* Deployments
* Services
* Ingress
* ConfigMaps
* Secrets
* Namespaces
* Probes
* Resource requests/limits
* Horizontal Pod Autoscaler
* Helm
* Kubernetes networking

Then compare:

```text
ECS Fargate
    vs
Kubernetes
```

This will make Kubernetes much easier to understand.

---

# Recommended Learning Order

Follow this order:

```text
1. Docker Deep Dive
        ↓
2. AWS VPC & Networking
        ↓
3. RDS PostgreSQL
        ↓
4. Secrets Manager
        ↓
5. ECS Production Architecture
        ↓
6. HTTPS + ACM
        ↓
7. Route 53
        ↓
8. Terraform
        ↓
9. CI/CD Improvements
        ↓
10. CloudWatch & Observability
        ↓
11. AWS Security
        ↓
12. Kubernetes
```

---

# Main Portfolio Project

Instead of creating many unrelated projects, build one strong end-to-end project.

## Target Architecture

```text
                       GitHub
                          │
                          ▼
                  GitHub Actions
                          │
                 ┌────────┴────────┐
                 │                 │
                 ▼                 ▼
              Testing          Docker Build
                                   │
                                   ▼
                                  ECR
                                   │
                                   ▼
                              ECS Fargate
                                   │
                         ┌─────────┴─────────┐
                         │                   │
                         ▼                   ▼
                        ALB                 RDS
                         │                PostgreSQL
                         │
                         ▼
                      NestJS
                         │
                         ▼
                       Redis
```

Add:

```text
Terraform
Secrets Manager
CloudWatch
Auto Scaling
ACM
Route 53
IAM
Security Groups
```

---

# Final Target

Eventually your project should look like:

```text
                         ┌─────────────┐
                         │   GitHub    │
                         └──────┬──────┘
                                │
                                ▼
                       ┌────────────────┐
                       │ GitHub Actions │
                       └───────┬────────┘
                               │
                ┌──────────────┴──────────────┐
                ▼                             ▼
             Testing                        ECR
                                              │
                                              ▼
                                      ┌──────────────┐
                                      │ ECS Fargate  │
                                      └──────┬───────┘
                                             │
                                      ┌──────┴──────┐
                                      ▼             ▼
                                    RDS           Redis
                                  PostgreSQL
                                            

                 Internet
                    │
                    ▼
             ┌─────────────┐
             │     ALB     │
             └──────┬──────┘
                    │
                    ▼
              ECS Fargate
                    │
                    ├── Secrets Manager
                    │
                    ├── CloudWatch
                    │
                    └── RDS
```

Infrastructure should eventually be managed by:

```text
                    Terraform
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
       AWS            IAM           CloudWatch
        │
        ├── VPC
        ├── ALB
        ├── ECS
        ├── ECR
        ├── RDS
        └── Secrets
```

## The Most Important Next Step

**Start with AWS VPC and networking.**

You already have a working ALB → ECS deployment, so now the best exercise is to understand exactly what happens between:

```text
Internet
   ↓
ALB
   ↓
Subnet
   ↓
Security Group
   ↓
ECS Task
```

and then redesign it as:

```text
Internet
   ↓
Public ALB
   ↓
Private ECS
   ↓
Private RDS
```

That will give you the networking foundation needed for the rest of the roadmap.
