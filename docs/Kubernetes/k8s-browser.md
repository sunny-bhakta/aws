# Kubernetes Basics (No Local Setup)

## What is Kubernetes?

Kubernetes (often written as **K8s**) is a container orchestration platform.

In simple words:

- You give Kubernetes your app definition (image, ports, replicas, config)
- Kubernetes runs and maintains your app automatically

It helps with:

#### 1) Scheduling containers on servers

- You declare a Pod/Deployment.
- Kubernetes Scheduler picks a suitable node automatically (CPU/memory/constraints).

Quick check:

```bash
kubectl create deployment sched-demo --image=nginx
kubectl get pods -o wide
```

See the `NODE` column to know where the Pod was scheduled.

#### 2) Auto-restarting failed containers

- If a container process exits, kubelet restarts it (based on Pod restart policy).
- Deployment also ensures desired replicas stay running.

Quick check:

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

Look for restart count and recent events.

#### 3) Scaling up/down based on demand

- Manual scaling: set desired replicas.
- Auto scaling: HPA adjusts replicas using metrics (CPU/memory/custom).

Manual scale example:

```bash
kubectl scale deployment sched-demo --replicas=3
kubectl get pods
kubectl scale deployment sched-demo --replicas=1
kubectl get pods
```

HPA mini-demo (auto scale):

```bash
kubectl autoscale deployment sched-demo --cpu-percent=50 --min=1 --max=5
kubectl get hpa
kubectl describe hpa sched-demo
```

Optional quick load to trigger scaling:

```bash
kubectl run loadgen --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://sched-svc; done"
kubectl get hpa -w
```

Stop load and clean HPA:

```bash
kubectl delete pod loadgen --ignore-not-found
kubectl delete hpa sched-demo
```

Note: HPA needs cluster metrics (usually Metrics Server) to scale by CPU.

#### 4) Service discovery and networking

- Service gives Pods a stable DNS name and virtual IP.
- Pods can call each other via service name instead of Pod IP.

Quick check:

```bash
kubectl expose deployment sched-demo --name=sched-svc --port=80 --target-port=80 --type=ClusterIP
kubectl run curlpod --image=curlimages/curl:8.9.1 -it --rm --restart=Never -- sh
```

Inside shell:

```sh
curl -I http://sched-svc
exit
```

Cleanup:

```bash
kubectl delete svc sched-svc
kubectl delete deploy sched-demo
```

---

## Why do we need Kubernetes?

Without Kubernetes, managing many containers manually becomes hard:

- Which server should run each container?
- What happens if a container crashes?
- How do we scale from 1 instance to 10?
- How do we update app versions safely?

Kubernetes solves these with declarative configuration.

You describe desired state, Kubernetes continuously tries to keep actual state equal to desired state.

---

## Goal of this guide

Learn Kubernetes + Ingress + Helm using only a browser.

```text
Your laptop
   ↓ (Browser)
Online Kubernetes Lab
   ↓
kubectl + Kubernetes + Ingress + Helm
```

---

## Core Kubernetes concepts (must know first)

### 1) Pod

- Smallest deployable unit in Kubernetes
- Usually contains one app container

### 2) Deployment

- Manages Pods
- Keeps desired replica count
- Handles rolling updates

### 3) Service

- Stable network endpoint for Pods
- Decouples traffic from changing Pod IPs

### 4) ConfigMap

- Non-sensitive configuration (env values, settings)

### 5) Secret

- Sensitive values (passwords, tokens, keys)

### 6) Ingress

- HTTP/HTTPS routing from outside cluster to Services
- Works with an Ingress Controller

### 7) Helm

- Package manager for Kubernetes
- Helps templatize and version deployments

---

## How to start in browser (quick start)

1. Open `https://killercoda.com`
2. Sign in (free account is enough)
3. Open a Kubernetes scenario (search for `Kubernetes` / `K8s basics`)
4. Wait until the browser terminal is ready

Verify cluster access:

```bash
kubectl cluster-info
kubectl get nodes
```

Expected:

- Cluster endpoints are shown
- At least one node is in `Ready` state

Run first commands:

```bash
kubectl create deployment nginx --image=nginx
kubectl get deployments
kubectl get pods -o wide
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP
kubectl get svc
```

Optional in-cluster test:

```bash
kubectl run curlpod --image=curlimages/curl:8.9.1 -it --rm --restart=Never -- sh
```

Inside pod shell:

```sh
curl -I http://nginx
exit
```

If you receive HTTP headers (for example `200 OK`), your browser Kubernetes setup is working.

---

## Mental model

Use this flow to think clearly:

```text
Deployment -> Pod(s) -> Service -> Ingress
```

- Deployment ensures Pods exist
- Service exposes Pods internally
- Ingress exposes selected services externally

---

## Learning roadmap

### 1) Kubernetes fundamentals

- Pod
- Deployment
- Service
- ConfigMap
- Secret

### 2) Networking

- Service types (ClusterIP / NodePort)
- Ingress
- Ingress Controller

### 3) Helm

- Why Helm exists
- Chart structure (`Chart.yaml`, `values.yaml`, `templates/`)
- `helm install`
- `helm upgrade`
- `helm rollback`

### 4) Practical project phase

Deploy your NestJS app with Helm and compare:

- ECS Fargate architecture vs Kubernetes architecture

---

## Command quick reference (used repeatedly)

Use these status checks throughout the lessons:

```bash
kubectl get deploy,pods,svc,ingress
kubectl get deploy
kubectl get svc
helm list
helm status <release-name>
helm history <release-name>
```

---

## Rolling update mini-demo (why downtime is low)

Use this quick demo to see rolling updates in action.

### 1) Create sample Deployment and Service

```bash
kubectl create deployment web --image=nginx:1.25
kubectl scale deployment web --replicas=3
kubectl expose deployment web --port=80 --target-port=80 --type=ClusterIP
kubectl get deploy,pods,svc
```

### 2) Trigger rolling update

```bash
kubectl set image deployment/web nginx=nginx:1.27
kubectl rollout status deployment/web
```

### 3) Check rollout history

```bash
kubectl rollout history deployment/web
```

### 4) Roll back if needed

```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
```

### 5) Cleanup

```bash
kubectl delete svc web
kubectl delete deploy web
```

What to observe:

- Pods are replaced gradually, not all at once
- Ready new Pods come up before old Pods fully go away
- With `replicas >= 2`, traffic interruption is usually minimized

---

## How many nodes should you use in labs?

Recommended approach:

- Start with **1 node** for beginner concepts (Pod, Deployment, Service)
- Move to **2 nodes** when practicing scheduling and resilience

Why 2 nodes later:

- You can observe Pod placement across nodes
- You can practice node-aware scheduling concepts
- You can better understand failure behavior

## Lesson 01 (Detailed) — Pod → Deployment → Service

### Objective

In this lesson you will:

1. Create a Pod (indirectly via Deployment)
2. Expose it using a Service
3. Verify traffic flow inside Kubernetes

By the end, you will understand:

```text
Deployment -> Pod(s) -> Service
```

### Prerequisites

- Browser-based Kubernetes lab open (for example: Killercoda)
- `kubectl` available in the lab terminal

Verify cluster access:

```bash
kubectl cluster-info
kubectl get nodes
```

Expected:

- Cluster endpoints are shown
- At least 1 node is in `Ready` state

### Step 1: Check current state

```bash
kubectl get deploy,pods,svc
```

### Step 2: Create a Deployment

```bash
kubectl create deployment nginx --image=nginx
```

What this does:

- Creates Deployment `nginx`
- Uses image `nginx` (contains Nginx web server)
- Starts 1 Pod by default and keeps it running

Verify:

```bash
kubectl get deployments
kubectl get pods -o wide
```

`kubectl get pods -o wide` meaning:

- `get pods`: lists Pods in current namespace
- `-o wide`: includes extra details like Pod IP and Node name

### Step 3: Scale Deployment

```bash
kubectl scale deployment nginx --replicas=2
kubectl get pods -o wide
```

### Step 4: Expose Deployment with Service

```bash
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP
```

What this does:

- Creates Service for Deployment `nginx`
- `--port=80`: Service port
- `--target-port=80`: forwards to container port 80
- `--type=ClusterIP`: internal-only Service (inside cluster)

Verify:

```bash
kubectl get services
kubectl describe service nginx
```

### Step 5: Test connectivity from inside cluster

Run temporary curl pod:

```bash
kubectl run curlpod --image=curlimages/curl:8.9.1 -it --rm --restart=Never -- sh
```

What this does:

- Starts temporary Pod `curlpod`
- Opens interactive shell
- Auto-deletes Pod on exit (`--rm`)
- Runs as single Pod (`--restart=Never`)

Inside pod shell:

```sh
curl -I http://nginx
curl -s http://nginx
exit
```

`curl -s http://nginx` meaning:

- `curl -s`: fetch body silently
- `http://nginx`: Service DNS name

### Step 6: Inspect YAML

```bash
kubectl get deployment nginx -o yaml
kubectl get service nginx -o yaml
```

Focus on:

- Deployment `spec.replicas`
- Deployment selector labels
- Service `spec.selector`
- Service type `ClusterIP`

### Step 7: Cleanup

```bash
kubectl delete service nginx
kubectl delete deployment nginx
kubectl get pods
kubectl get services
```

### Troubleshooting (important)

Pods not ready:

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

Service has no endpoints:

```bash
kubectl get pods --show-labels
kubectl describe service nginx
```

If curl pod cannot resolve `nginx`:

```bash
kubectl get svc nginx
kubectl get endpoints nginx
```

If Service is missing:

```bash
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP
```

Retry DNS using short and full names:

```sh
curl -I http://nginx
curl -I http://nginx.default.svc.cluster.local
```

Shortcut note:

- `svc` means `service`
- `kubectl get svc` == `kubectl get services`

---

## Lesson 02 (Detailed) — Service Types + Ingress Basics

### Objective

In this lesson you will:

1. Understand `ClusterIP` vs `NodePort`
2. Expose an app using both types
3. Create your first Ingress rule
4. Verify traffic path end-to-end

Target flow:

```text
Client -> Ingress -> Service -> Pod(s)
```

### Prerequisites

- Existing `nginx` Deployment (or create one)
- `kubectl` access to lab cluster
- Ingress Controller available in the lab cluster

If needed, create deployment:

```bash
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=2
```

---

### Step 1: Create ClusterIP Service (internal access)

```bash
kubectl expose deployment nginx --name=nginx-clusterip --port=80 --target-port=80 --type=ClusterIP
kubectl get svc nginx-clusterip
```

What to observe:

- Service gets a cluster IP
- Reachable from inside cluster only

Test from temporary curl pod:

```bash
kubectl run curlpod --image=curlimages/curl:8.9.1 -it --rm --restart=Never -- sh
```

Inside shell:

```sh
curl -I http://nginx-clusterip
exit
```

---

### Step 2: Create NodePort Service (node-level external port)

```bash
kubectl expose deployment nginx --name=nginx-nodeport --port=80 --target-port=80 --type=NodePort
kubectl get svc nginx-nodeport
```

Inspect assigned node port:

```bash
kubectl get svc nginx-nodeport -o wide
kubectl describe svc nginx-nodeport
```

What to observe:

- NodePort is typically in `30000-32767`
- Any node IP + that port routes to service pods

If your lab provides node IP access, test:

```bash
kubectl get nodes -o wide
```

Then from a reachable shell/browser:

```text
http://<NODE_IP>:<NODE_PORT>
```

Real example from lab output:

```text
Node IP: 172.30.1.2
NodePort: 30533
URL: http://172.30.1.2:30533
```

How to read `kubectl describe svc nginx-nodeport` output:

- `Type: NodePort` means service is exposed on a node port
- `NodePort: 30533/TCP` is the external node-level port
- `Endpoints: ...:80` confirms backend pods are attached
- `External-IP: <none>` on nodes is common in browser labs

If `EXTERNAL-IP` is `<none>`, direct access from your laptop browser may not work.
In that case, test inside the lab terminal first:

```bash
curl -I http://172.30.1.2:30533
curl -s http://172.30.1.2:30533
```

---

### Step 3: Create first Ingress resource

Create file `ingress-nginx.yaml` with this content:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
   name: nginx-ingress
spec:
   rules:
      - host: nginx.local
         http:
            paths:
               - path: /
                  pathType: Prefix
                  backend:
                     service:
                        name: nginx-clusterip
                        port:
                           number: 80
```

Apply and verify:

```bash
kubectl apply -f ingress-nginx.yaml
kubectl get ingress
kubectl describe ingress nginx-ingress
```

What this does:

- Routes host `nginx.local` path `/`
- Forwards traffic to service `nginx-clusterip:80`

---

### Step 4: Verify Ingress Controller availability

Check for ingress-related pods:

```bash
kubectl get pods -A
```

If no ingress controller pod exists, your Ingress object may be created but not active.

---

### Step 5: End-to-end validation

Validation checklist:

- Deployment pods are `Running`
- Service has endpoints
- Ingress has address/class (lab dependent)

Commands:

```bash
kubectl get deploy,pods,svc,ingress
kubectl get endpoints nginx-clusterip
```

---

### Troubleshooting

#### Ingress created but not routing

Check:

```bash
kubectl describe ingress nginx-ingress
kubectl get ingressclass
```

Fix idea:

- Ensure an Ingress controller is running
- Ensure controller matches default `IngressClass` or set it explicitly

#### Service has no endpoints

Check:

```bash
kubectl get pods --show-labels
kubectl describe svc nginx-clusterip
```

Fix idea:

- Service selector must match Pod labels

#### NodePort not reachable

Possible reasons:

- Lab blocks node external access
- Wrong node IP or wrong node port used
- Workload not ready yet

Check:

```bash
kubectl get svc nginx-nodeport
kubectl get pods -o wide
```

---

### Cleanup (after practice)

```bash
kubectl delete ingress nginx-ingress
kubectl delete svc nginx-nodeport
kubectl delete svc nginx-clusterip
kubectl delete deploy nginx
```

---

### Lesson 02 checkpoint ✅

You should now be comfortable with:

- When to use `ClusterIP` vs `NodePort`
- How Ingress routes to a Service
- How to verify each layer (`Ingress -> Service -> Pod`)

### Next

Next lesson: **Helm basics** (`helm create`, `install`, `upgrade`, `rollback`) and then packaging your NestJS app.

---

## Lesson 03 (Detailed) — Helm Basics

### Objective

In this lesson you will:

1. Create your first Helm chart
2. Install it into Kubernetes
3. Upgrade it with changes
4. Check history and rollback

Target flow:

```text
Chart -> helm install -> Release -> Kubernetes resources
```

### Prerequisites

- Kubernetes lab terminal ready
- `kubectl` connected to cluster
- Helm available

Verify:

```bash
helm version
kubectl get nodes
```

---

### Step 1: Create a chart

```bash
helm create my-app
ls my-app
```

What gets created:

- `Chart.yaml` (chart metadata)
- `values.yaml` (default values)
- `templates/` (Kubernetes templates)

---

### Step 2: Preview rendered YAML (safe check)

```bash
helm template my-app ./my-app
```

Why this matters:

- Shows final Kubernetes YAML before deployment
- Helps catch mistakes early

---

### Step 3: Install release

```bash
helm install my-app ./my-app
kubectl get deploy,svc,pods
```

Check Helm release:

```bash
helm list
helm status my-app
```

---

### Step 4: Upgrade release (change replica count)

Use CLI override:

```bash
helm upgrade my-app ./my-app --set replicaCount=2
kubectl get deploy
kubectl get pods
```

What to observe:

- Deployment from Helm now targets 2 replicas
- Rolling update behavior managed by Kubernetes

---

### Step 5: Release history and rollback

```bash
helm history my-app
helm rollback my-app 1
kubectl get deploy
```

What this does:

- `helm history` shows release revisions
- `helm rollback` moves to a previous known-good revision

---

### Step 6: Uninstall release (cleanup)

```bash
helm uninstall my-app
kubectl get deploy,svc,pods
```

---

### Troubleshooting

#### Helm command not found

- Your lab scenario might not include Helm
- Switch to a scenario that includes Helm or install if allowed

#### Install succeeds but pods not ready

Check:

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

#### Upgrade did not apply expected values

Check values used by release:

```bash
helm get values my-app
helm get manifest my-app
```

---

### Lesson 03 checkpoint ✅

You should now be comfortable with:

- Creating a chart with `helm create`
- Installing/upgrading a release
- Viewing history and rolling back safely

### Next

Next lesson: package your NestJS app with a custom Helm chart (`deployment`, `service`, `ingress`, env values) and compare against your ECS setup.

---

## Lesson 04 (Detailed) — Deploy NestJS with Helm

### Objective

In this lesson you will:

1. Create a Helm chart for NestJS
2. Configure image/service/ingress via `values.yaml`
3. Install and verify release
4. Upgrade and rollback safely

Target flow:

```text
Helm values -> Templates -> Deployment/Service/Ingress -> NestJS app running
```

### Prerequisites

- Your NestJS image is already pushed to a registry (for example ECR)
- `kubectl` connected to cluster
- Helm available in the lab

Verify tools:

```bash
kubectl get nodes
helm version
```

---

### Step 1: Create chart scaffold

```bash
helm create nestjs-app
ls nestjs-app
```

---

### Step 2: Update `values.yaml`

Set app values in `nestjs-app/values.yaml`:

```yaml
replicaCount: 2

image:
   repository: <YOUR_IMAGE_REPO>
   pullPolicy: IfNotPresent
   tag: "latest"

service:
   type: ClusterIP
   port: 80

containerPort: 3000

ingress:
   enabled: true
   className: ""
   annotations: {}
   hosts:
      - host: nestjs.local
         paths:
            - path: /
               pathType: Prefix
   tls: []

env:
   NODE_ENV: production
```

Notes:

- Use your real image repo in `image.repository`
- For NestJS default runtime, container often listens on `3000`

If you do not have an image repository yet, use a temporary public image for practice and switch to your real NestJS image before non-lab deployment (see FAQ #1 and #2).

---

### Step 3: Wire templates to NestJS values

In `templates/deployment.yaml`, ensure container port uses value:

```yaml
ports:
   - name: http
      containerPort: {{ .Values.containerPort }}
      protocol: TCP
```

Add environment variable mapping in deployment template:

```yaml
env:
   - name: NODE_ENV
      value: {{ .Values.env.NODE_ENV | quote }}
```

In `templates/service.yaml`, ensure target port maps to container port:

```yaml
ports:
   - port: {{ .Values.service.port }}
      targetPort: {{ .Values.containerPort }}
      protocol: TCP
      name: http
```

---

### Step 4: Render and validate before install

```bash
helm lint ./nestjs-app
helm template nestjs ./nestjs-app
```

---

### Step 5: Install release

```bash
helm install nestjs ./nestjs-app
kubectl get deploy,svc,pods,ingress
helm status nestjs
```

Check rollout:

```bash
kubectl rollout status deployment/nestjs-app
```

If chart naming differs, find deployment name:

```bash
kubectl get deploy
```

---

### Step 6: Test service and app

Internal test with temporary curl pod:

```bash
kubectl run curlpod --image=curlimages/curl:8.9.1 -it --rm --restart=Never -- sh
```

Inside shell:

```sh
curl -I http://nestjs-app
exit
```

If your service has a different name, check it first:

```bash
kubectl get svc
```

---

### Step 7: Upgrade image tag

```bash
helm upgrade nestjs ./nestjs-app --set image.tag=v2
kubectl get pods
helm history nestjs
```

---

### Step 8: Rollback if needed

```bash
helm rollback nestjs 1
kubectl get pods
```

---

### Troubleshooting

#### Pods in `ImagePullBackOff`

Check:

```bash
kubectl describe pod <pod-name>
```

Fix ideas:

- Wrong image repository/tag
- Missing image pull permissions

#### Service works but Ingress does not

Check:

```bash
kubectl get ingress
kubectl describe ingress
kubectl get pods -A
```

Fix ideas:

- Ingress controller missing
- Wrong ingress class
- Host/path mismatch

#### App starts but health endpoint fails

Check logs:

```bash
kubectl logs <pod-name>
```

Fix ideas:

- Wrong container port
- Missing env configuration

---

### Cleanup (after practice)

```bash
helm uninstall nestjs
kubectl get deploy,svc,pods,ingress
```

---

### Lesson 04 checkpoint ✅

You should now be comfortable with:

- Packaging NestJS for Kubernetes via Helm
- Deploying and validating app resources
- Upgrading and rolling back safely

### Next

Optional next: split values by environment:

- `values-dev.yaml`
- `values-stage.yaml`
- `values-prod.yaml`

Then deploy with:

```bash
helm upgrade --install nestjs ./nestjs-app -f values-dev.yaml
```

---

## Quick FAQ (recent clarifications)

### 1) Can I run real NestJS app without my own image repository?

Short answer: **No**.

- You can practice Helm/Kubernetes flow with public images.
- But to run your actual NestJS app, you must build and push your app image and reference it in values.

```yaml
image:
   repository: <your-registry>/<nestjs-image>
   tag: "v1"
```

### 2) Can I use a public hello-world image for practice?

Yes. Good options:

- `nginxdemos/hello`
- `traefik/whoami`
- `hashicorp/http-echo`

Example practice values:

```yaml
image:
   repository: nginxdemos/hello
   tag: "latest"
   pullPolicy: IfNotPresent

containerPort: 80
service:
   type: ClusterIP
   port: 80
```

### 3) How do I update values without replacing everything?

Use layered values files and merge order:

```bash
helm upgrade --install nestjs ./nestjs-app -f values.yaml -f values-dev.yaml
```

- Base file stays unchanged
- Later file overrides only selected keys

Quick one-off value update:

```bash
helm upgrade nestjs ./nestjs-app --set image.tag=v2
```

Keep existing release values while changing one key:

```bash
helm upgrade nestjs ./nestjs-app --reuse-values --set image.tag=v3
```

### 4) Filename reminder

- Correct file name: `nestjs-app/values.yaml`
- Not: `nestjs-app/values.yam`

### 5) Helm error: `open ./nestjs-app/values-dev.yaml: no such file or directory`

This means Helm cannot find the override file path you passed.

Fix steps:

1. Confirm files exist:

```bash
dir .\nestjs-app
```

2. If missing, create `values-dev.yaml` under `nestjs-app` with this content:

```yaml
image:
   repository: nginxdemos/hello
   tag: "latest"
   pullPolicy: IfNotPresent

containerPort: 80

service:
   type: ClusterIP
   port: 80

ingress:
   enabled: true
   hosts:
      - host: hello.local
         paths:
            - path: /
               pathType: Prefix
```

3. Run Helm with explicit paths:

```bash
helm upgrade --install nestjs ./nestjs-app -f ./nestjs-app/values.yaml -f ./nestjs-app/values-dev.yaml
```

If you do not want an override file yet, run only base values:

```bash
helm upgrade --install nestjs ./nestjs-app -f ./nestjs-app/values.yaml
```

### 6) Rollout error: `deployments.apps "nestjs-app" not found`

Reason:

- Helm often creates names as `<release-name>-<chart-name>`.
- With release `nestjs` and chart `nestjs-app`, deployment may be `nestjs-nestjs-app`.

Find actual deployment name:

```bash
kubectl get deploy
```

Then run rollout status with exact name:

```bash
kubectl rollout status deployment/nestjs-nestjs-app
```

Auto-pick first deployment (quick helper):

```bash
kubectl get deploy
kubectl rollout status deployment/<DEPLOYMENT_NAME>
```

### 7) How to curl service from inside shell

1. Get service name and port:

```bash
kubectl get svc
```

2. Start temporary curl pod:

```bash
kubectl run curlpod --image=curlimages/curl:8.9.1 -it --rm --restart=Never -- sh
```

3. Inside shell, curl service by DNS name:

```sh
curl -I http://nestjs-nestjs-app
curl -s http://nestjs-nestjs-app
```

If service port is not `80`, include port:

```sh
curl -I http://nestjs-nestjs-app:<PORT>
```

Optional full DNS name:

```sh
curl -I http://nestjs-nestjs-app.default.svc.cluster.local
```

---

## Kubernetes Production Readiness Checklist (for NestJS)

Use this checklist after your first successful Helm deployment.

### App reliability

- [ ] Add `readinessProbe` to Deployment
- [ ] Add `livenessProbe` to Deployment
- [ ] Set `resources.requests` and `resources.limits` (CPU/memory)
- [ ] Keep `replicaCount >= 2` for high availability

### Configuration and secrets

- [ ] Move non-sensitive config to ConfigMap
- [ ] Move secrets to Secret (never hardcode in values)
- [ ] Use environment-specific values files (`values-dev.yaml`, `values-stage.yaml`, `values-prod.yaml`)

### Networking and access

- [ ] Confirm Service type and targetPort are correct
- [ ] Configure Ingress class and host rules clearly
- [ ] Add TLS for Ingress (cert-manager or platform cert solution)
- [ ] Add NetworkPolicy where required

### Security basics

- [ ] Use non-root container/user when possible
- [ ] Add ServiceAccount and least-privilege RBAC
- [ ] Pin image tags (avoid only `latest` in stage/prod)
- [ ] Scan container images before deploy

### Operability

- [ ] Add app logs/metrics visibility
- [ ] Add rollout verification in CI/CD
- [ ] Test rollback path (`helm rollback`) in non-prod
- [ ] Keep Helm chart versioning clean (`Chart.yaml`)

---

## What to pick next (recommended order)

1. **Environment layering (next best step now)**
   - Create `values-dev.yaml`, `values-stage.yaml`, `values-prod.yaml`
   - Deploy with layered values

2. **Health probes + resources**
   - Add readiness/liveness probes
   - Add CPU/memory requests/limits

3. **Secrets + ConfigMap wiring**
   - Move env settings out of inline values

4. **Ingress TLS and host rules**
   - Enable HTTPS and validate routing

5. **CI/CD Helm deploy flow**
   - Add lint/template/deploy/rollback verification

If you want a single immediate task: pick **#1 Environment layering** now.