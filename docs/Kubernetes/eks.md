# AWS EKS Concepts (Kubernetes on AWS)

## What is EKS?

**Amazon EKS (Elastic Kubernetes Service)** is AWS-managed Kubernetes.

In simple terms:

- Kubernetes is the platform.
- EKS is AWS running and managing the Kubernetes control plane for you.

You still manage your workloads (Deployments, Services, Ingress, Helm charts), but AWS handles control-plane availability and upgrades.

---

## Core mental model

```text
Users/Apps
	-> Ingress / Load Balancer
		-> Kubernetes Service
			-> Pod(s) in Node(s)

EKS Control Plane (managed by AWS) manages desired state.
```

---

## Kubernetes concepts vs EKS mapping

### Kubernetes pieces (you already know)

- **Pod**: smallest runnable unit
- **Deployment**: desired replica management + rolling updates
- **Service**: stable network endpoint for Pods
- **Ingress**: HTTP/HTTPS routing rules
- **ConfigMap/Secret**: app config and sensitive values

Quick examples for each:

#### 1) Pod example

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: demo-pod
spec:
	containers:
		- name: app
			image: nginx:1.27
			ports:
				- containerPort: 80
```

#### 2) Deployment example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: demo-deployment
spec:
	replicas: 2
	selector:
		matchLabels:
			app: demo
	template:
		metadata:
			labels:
				app: demo
		spec:
			containers:
				- name: app
					image: nginx:1.27
					ports:
						- containerPort: 80
```

#### 3) Service example

```yaml
apiVersion: v1
kind: Service
metadata:
	name: demo-service
spec:
	type: ClusterIP
	selector:
		app: demo
	ports:
		- port: 80
			targetPort: 80
```

This gives a stable DNS name (`demo-service`) for Pods with label `app: demo`.

#### 4) Ingress example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
	name: demo-ingress
spec:
	rules:
		- host: demo.example.com
			http:
				paths:
					- path: /
						pathType: Prefix
						backend:
							service:
								name: demo-service
								port:
									number: 80
```

#### 5) ConfigMap example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
	name: demo-config
data:
	NODE_ENV: production
	LOG_LEVEL: info
```

#### 6) Secret example

```yaml
apiVersion: v1
kind: Secret
metadata:
	name: demo-secret
type: Opaque
stringData:
	DB_USER: appuser
	DB_PASSWORD: super-secret-password
```

`stringData` is convenient for authoring; Kubernetes stores it as base64 in `data`.

#### Combined end-to-end example (all wired together)

Use this as a single sample for real app wiring.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
	name: app-config
data:
	NODE_ENV: production
	LOG_LEVEL: info
---
apiVersion: v1
kind: Secret
metadata:
	name: app-secret
type: Opaque
stringData:
	DB_USER: appuser
	DB_PASSWORD: super-secret-password
---
apiVersion: apps/v1
kind: Deployment
metadata:
	name: app-deployment
spec:
	replicas: 2
	selector:
		matchLabels:
			app: app
	template:
		metadata:
			labels:
				app: app
		spec:
			containers:
				- name: app
					image: nginx:1.27
					ports:
						- containerPort: 80
					envFrom:
						- configMapRef:
								name: app-config
					env:
						- name: DB_USER
							valueFrom:
								secretKeyRef:
									name: app-secret
									key: DB_USER
						- name: DB_PASSWORD
							valueFrom:
								secretKeyRef:
									name: app-secret
									key: DB_PASSWORD
---
apiVersion: v1
kind: Service
metadata:
	name: app-service
spec:
	type: ClusterIP
	selector:
		app: app
	ports:
		- port: 80
			targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
	name: app-ingress
spec:
	rules:
		- host: app.example.com
			http:
				paths:
					- path: /
						pathType: Prefix
						backend:
							service:
								name: app-service
								port:
									number: 80
```

Apply and verify:

```bash
kubectl apply -f app-all-in-one.yaml
kubectl get configmap,secret,deploy,svc,ingress
kubectl rollout status deployment/app-deployment
```

Replace before real use:

- `image: nginx:1.27` -> your app image (for example ECR image)
- `host: app.example.com` -> your domain/ingress host

### EKS/AWS-specific pieces

- **Cluster**: Kubernetes cluster hosted by EKS
- **Node Group**: group of EC2 worker nodes (managed by EKS)
- **Fargate Profile**: run Pods serverless without managing EC2 nodes
- **VPC/Subnets**: network foundation for cluster and nodes
- **IAM**: authN/authZ integration for users, nodes, controllers
- **Security Groups**: network-level firewall rules
- **ECR**: container image registry
- **CloudWatch**: logs/metrics

---

## EKS architecture basics

## 1) Control plane (managed by AWS)

- API server, etcd, scheduler, controllers are managed by EKS.
- Highly available across multiple AZs.
- You do not patch/operate control-plane instances yourself.

## 2) Data plane (you choose)

- **Managed node groups (EC2)**: common option, full node control
- **Fargate**: no node management, pay per workload

Use EC2 node groups when you need daemonsets, special networking, or more control.
Use Fargate for simpler ops and bursty/isolated workloads.

---

## Request flow in EKS

Typical internet app flow:

```text
Client
  -> AWS Load Balancer (ALB/NLB)
	 -> Ingress Controller / Service
		-> Pod (application container)
```

For internal service-to-service traffic:

```text
Pod A -> Kubernetes Service DNS -> Pod B
```

---

## IAM in EKS (important)

Two common IAM needs:

1. **Human/CI access to cluster**
	- IAM principal must be mapped/authorized for Kubernetes API access.

2. **Pod access to AWS services**
	- Use **IRSA** (IAM Roles for Service Accounts).
	- Example: Pod needs S3, SQS, Secrets Manager, DynamoDB access.

Best practice: avoid static AWS keys inside Pods.

---

## Networking concepts in EKS

- Pods get IPs from VPC CNI.
- Services provide stable endpoints over changing Pod IPs.
- Ingress exposes HTTP/HTTPS routes externally.
- Private/public subnets decide exposure pattern.

Common production shape:

- Worker nodes in private subnets
- ALB in public subnets
- NAT for controlled egress

---

## Storage concepts

- **EBS CSI** for block volumes (stateful apps)
- **EFS CSI** for shared file storage (multi-pod read/write patterns)

Kubernetes objects:

- PersistentVolume (PV)
- PersistentVolumeClaim (PVC)
- StorageClass

---

## Deployment concepts (Helm + EKS)

In practice, you deploy via Helm:

- `helm upgrade --install` for idempotent deploy
- values files per env (`dev/stage/prod`)
- rollout check + rollback safety

Key checks after deploy:

- `kubectl get deploy,pods,svc,ingress`
- `kubectl rollout status deployment/<name>`
- `helm history <release>`

---

## Day-2 operations checklist

- Add readiness/liveness probes
- Set CPU/memory requests and limits
- Enable HPA for autoscaling
- Centralize logs/metrics (CloudWatch/Prometheus/Grafana)
- Use PodDisruptionBudget for safer maintenance
- Secure with least-privilege IAM + network policies
- Keep cluster/node versions updated

---

## EKS vs ECS (quick view)

- **ECS**: AWS-native orchestrator, simpler AWS-centric ops
- **EKS**: standard Kubernetes ecosystem, portable manifests/Helm

Choose EKS when:

- You want Kubernetes ecosystem/tooling portability
- Team already uses Kubernetes patterns
- You need advanced k8s primitives/controllers

Choose ECS when:

- You prefer simpler AWS-native container operations
- You don’t need full Kubernetes abstraction surface

---

## Most common beginner confusions

1. **“Is EKS Kubernetes?”**
	- EKS is managed Kubernetes, not a different orchestrator.

2. **“Do I manage masters/control-plane VMs?”**
	- No, AWS manages control plane.

3. **“Do I still need to manage worker compute?”**
	- Yes for EC2 node groups; less/no node management with Fargate.

4. **“Can Pods call AWS services securely?”**
	- Yes, use IRSA with IAM roles bound to service accounts.

---

## What to learn next (recommended order)

1. EKS cluster + node group + VPC basics
2. IAM + IRSA hands-on
3. Ingress Controller + ALB integration
4. Helm deployment pipeline (dev/stage/prod values)
5. Observability + autoscaling + upgrade strategy

---

## Minimal EKS production reference architecture

Use this as a default baseline for small-to-medium production workloads.

### Reference diagram

```text
Internet Users
	-> Route 53 (DNS)
		-> ALB (public subnets, HTTPS)
			-> AWS Load Balancer Controller (Ingress)
				-> Kubernetes Service (ClusterIP)
					-> App Pods (private subnets)
						-> RDS / ElastiCache / other backends

EKS Control Plane (AWS managed, multi-AZ)
Managed Node Group (EC2) in private subnets across 2-3 AZs
NAT Gateway for controlled outbound internet access
```

### Core components checklist

#### Networking

- One VPC across at least 2 AZs
- Public subnets for ALB
- Private subnets for worker nodes and Pods
- NAT Gateway for outbound traffic from private subnets

#### Compute

- EKS cluster (managed control plane)
- Managed node groups spread across AZs
- Cluster Autoscaler or Karpenter for node scaling

#### Ingress and routing

- AWS Load Balancer Controller installed
- Ingress resources mapped to ALB
- TLS certificate from ACM
- Route 53 records pointing to ALB

#### Security

- IRSA for controllers and application service accounts
- Least-privilege IAM policies
- Security groups limited to required ports
- Secrets stored in Kubernetes Secret or external secret manager pattern

#### Observability

- Container logs to CloudWatch
- Metrics via Prometheus/Grafana or AWS-managed alternatives
- Alerting for CPU, memory, restart spikes, 5xx errors

---

## Traffic paths to understand

### External user request

```text
Browser -> Route 53 -> ALB (HTTPS) -> Ingress rule -> Service -> Pod
```

### Pod to AWS service

```text
Pod + ServiceAccount -> IRSA role -> AWS API (S3/SQS/DynamoDB/Secrets Manager)
```

### Pod egress to internet (if needed)

```text
Pod (private subnet) -> NAT Gateway -> Internet
```

---

## Pre-go-live checks (minimum)

- [ ] `replicaCount >= 2` for critical apps
- [ ] readiness/liveness probes configured
- [ ] CPU/memory requests and limits configured
- [ ] HPA configured for variable traffic
- [ ] PodDisruptionBudget added for critical workloads
- [ ] Ingress TLS enforced (HTTPS only)
- [ ] IAM access through IRSA (no static AWS keys)
- [ ] Backups + restore plan for stateful dependencies
- [ ] Rollback tested (`helm rollback`)
- [ ] Basic dashboards and alerts active

---

## When to evolve this baseline

Move beyond this minimal architecture when you need:

- strict multi-team isolation (separate clusters/accounts)
- service mesh (mTLS, traffic policies, advanced telemetry)
- high compliance controls (private endpoints, stricter egress controls)
- very large scale requiring advanced node provisioning strategy

---

## Terraform mapping to this repository (current status)

Important context: your current `terraform/` code provisions an **ECS Fargate** stack, not EKS yet.

### What already exists and can be reused

| Architecture area | Terraform file(s) | Current resource examples | Reuse for EKS? |
|---|---|---|---|
| VPC and subnets (default VPC lookup) | `terraform/vpc.tf` | `data.aws_vpc.default`, `data.aws_subnets.default` | ✅ Partial (works for labs; production EKS usually uses dedicated VPC/subnets) |
| Container registry | `terraform/ecr.tf` | `aws_ecr_repository.app` | ✅ Yes |
| Logging foundation | `terraform/cloudwatch.tf` | `aws_cloudwatch_log_group.app` | ✅ Yes |
| Database layer | `terraform/rds.tf` | `aws_db_instance.postgres`, `aws_db_subnet_group.app` | ✅ Yes (network/security should be reviewed for EKS node SGs) |
| Secrets storage | `terraform/secrets.tf` | `aws_secretsmanager_secret.db` | ✅ Yes |
| Remote state/backend templates | `terraform/backend.tf`, `terraform/backend*.example` | S3 backend config | ✅ Yes |

### What is ECS-specific today (not directly EKS)

| Terraform file(s) | Why ECS-specific |
|---|---|
| `terraform/ecs.tf` | Creates `aws_ecs_cluster`, `aws_ecs_service`, `aws_ecs_task_definition` |
| `terraform/iam.tf` (current roles/policies) | Role trust and policies target ECS tasks/GitHub-to-ECS deploy path |
| `terraform/alb.tf` + `terraform/security-groups.tf` | ALB/target group/listener are wired to ECS service traffic model |

### What needs to be added for EKS

Minimum EKS resource groups to add:

1. **EKS control plane**
	- `aws_eks_cluster`

2. **Worker compute**
	- `aws_eks_node_group` (or Fargate profiles)

3. **IAM for EKS + IRSA**
	- EKS cluster role
	- Node group role
	- OIDC provider + IAM roles for service accounts (IRSA)

4. **Kubernetes ingress integration on AWS**
	- IAM role/policy for AWS Load Balancer Controller
	- Controller installation (typically via Helm)

5. **Kubernetes provider wiring (optional but common)**
	- Terraform `kubernetes`/`helm` providers configured via EKS auth data

### Suggested migration path (safe order)

1. Keep existing ECS Terraform stable (no destructive changes).
2. Add new EKS Terraform files separately (for example `eks-cluster.tf`, `eks-nodegroup.tf`, `eks-iam.tf`).
3. Reuse ECR/Secrets/RDS where appropriate.
4. Deploy app to EKS via Helm.
5. Cut traffic gradually, then retire ECS resources if desired.

