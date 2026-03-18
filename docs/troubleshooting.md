# Troubleshooting Guide — GitLab Kubernetes Deployment

This document covers all known issues and their fixes for the GitLab + PostgreSQL + Runner stack running on Minikube (WSL2).

---

## 1. `kubectl` Not Found on Windows

**Symptom:**
```
kubectl : The term 'kubectl' is not recognized...
```

**Cause:** `kubectl` is not installed system-wide on Windows or not in the PATH.

**Fix:**
- Always run `kubectl` commands from **WSL**, not from PowerShell or CMD.
- Open a WSL terminal and use `kubectl` there — it is installed inside WSL.

```bash
# Always run in WSL:
kubectl -n gitlab get pods
```

---

## 2. Minikube Stopped / API Server Refusing Connections

**Symptom:**
```
The connection to the server 127.0.0.1:32771 was refused - did you specify the right host or port?
```

**Cause:** Minikube is not running. The Kubernetes API server is down.

**Fix:**
```bash
# Check minikube status
minikube status

# Start minikube (uses Docker driver inside WSL)
minikube start --driver=docker
```

> **Note:** If you see warnings like "You cannot change the memory size for an existing minikube cluster", they are harmless — minikube will still start using the existing cluster config.

---

## 3. GitLab Cannot Connect to PostgreSQL

**Symptom:**
- GitLab pod starts but fails to initialize.
- Logs show DB connection errors.
- GitLab web UI shows `500` or `502` errors referencing the database.

**Cause:** In `k8s/base/configmap.yaml`, the `db_host` and `db_password` lines were commented out, so GitLab did not know which host to connect to or which password to use.

**Fix:**  
Ensure these lines are **not** commented out in `configmap.yaml`:

```ruby
gitlab_rails['db_host'] = 'postgres-service'
gitlab_rails['db_password'] = ENV['POSTGRES_PASSWORD']
```

After editing, reapply the configmap and restart the GitLab deployment:

```bash
kubectl apply -f k8s/base/configmap.yaml
kubectl rollout restart deployment/gitlab -n gitlab
```

---

## 4. GitLab Pod in `CrashLoopBackOff` — Gitaly Service Timeout

**Symptom:**
```
runit_service[gitaly] had an error: ...
timeout: down: /opt/gitlab/service/gitaly/log: 1s, normally up, want up
```

**Cause:** After a `kubectl rollout restart`, the old GitLab pod may not terminate before the new one starts. Both pods try to use the same PersistentVolumeClaims simultaneously, causing lock conflicts with Gitaly's log service.

**Fix:** Delete the deployment entirely and recreate it cleanly:

```bash
kubectl -n gitlab delete deployment gitlab
kubectl apply -f k8s/base/gitlab.yaml
```

This ensures only one pod owns the PVCs at a time.

---

## 5. `runner-config-pvc` Stuck in `Pending`

**Symptom:**
```
persistentvolumeclaim/runner-config-pvc   Pending
```

**Cause:** Timing issue — the PVC was being provisioned when the pod was first scheduled.

**Fix:** This resolves itself automatically within a minute or two as the default StorageClass provisions the volume. Verify with:

```bash
kubectl -n gitlab get pvc
```

All PVCs should show `Bound` once provisioned.

---

## 6. GitLab Web UI Not Reachable from Windows Browser

**Symptom:**
```
ERR_CONNECTION_TIMED_OUT
192.168.49.2 took too long to respond.
```

**Cause:** Minikube runs inside the WSL2 virtual machine. The NodePort IP `192.168.49.2` is **only reachable within WSL2**, not from the Windows host directly.

**Fix — Port Forward to localhost:**

Run this in a WSL terminal and **keep it open**:

```bash
kubectl port-forward -n gitlab svc/gitlab-service 8080:80
```

Then access GitLab in your Windows browser at:

```
http://localhost:8080
```

> The tunnel is active only while the terminal is open. To run it in the background:
> ```bash
> nohup kubectl port-forward -n gitlab svc/gitlab-service 8080:80 &
> ```

---

## 7. Checking Overall Cluster Health

Use these commands at any time to diagnose the state of your stack:

```bash
# Check if minikube is running
minikube status

# See all pods, services, and PVCs in the gitlab namespace
kubectl -n gitlab get pods,svc,pvc

# Watch pods live (Ctrl+C to exit)
kubectl -n gitlab get pods --watch

# View GitLab pod logs
kubectl -n gitlab logs deploy/gitlab

# View Postgres pod logs
kubectl -n gitlab logs deploy/postgres

# View Runner pod logs
kubectl -n gitlab logs deploy/gitlab-runner

# See why a specific pod is failing
kubectl -n gitlab describe pod <pod-name>

# See recent cluster events sorted by time
kubectl -n gitlab get events --sort-by=.metadata.creationTimestamp
```

---

## 8. Full Reset — Start From Scratch

If the stack is in an unrecoverable state:

```bash
# Delete all GitLab resources
kubectl delete namespace gitlab

# Stop minikube
minikube stop

# Optionally wipe the cluster entirely
minikube delete

# Then redeploy from scratch
minikube start --driver=docker
cd /mnt/c/Users/manbi/Downloads/Project/Project/k8s/base
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f postgres.yaml
kubectl apply -f gitlab.yaml
kubectl apply -f runner.yaml
```

> ⚠️ **Warning:** Deleting the namespace or running `minikube delete` will destroy all PersistentVolumeClaims and all stored GitLab data.

---

## 9. GitLab Takes Too Long to Start

**Symptom:** GitLab pod shows `0/1 Running` for a long time.

**Cause:** This is **normal**. GitLab CE is a heavy application that runs many internal services (Puma, Sidekiq, Gitaly, Nginx, etc.) and can take **5–10 minutes** on first boot, especially with limited resources.

**What to watch:**

```bash
kubectl -n gitlab get pods --watch
```

The startup probe allows up to **10 minutes** (`failureThreshold: 60` × `periodSeconds: 10`). Once the probe passes, the pod will transition to `1/1 Running`.

---

## Summary Table

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| `kubectl` not found | Not in Windows PATH | Use WSL terminal |
| API server refused | Minikube stopped | `minikube start --driver=docker` |
| GitLab DB error | `db_host`/`db_password` commented out | Uncomment in `configmap.yaml`, reapply |
| Gitaly CrashLoop | Two pods sharing PVCs | Delete and recreate the deployment |
| PVC Pending | Provisioning timing | Wait ~1 min, auto-resolves |
| Browser can't reach `192.168.49.2` | WSL2 network isolation | Use `kubectl port-forward` to `localhost:8080` |
| GitLab slow to start | Normal — heavy app | Wait 5–10 min for startup probe to pass |
