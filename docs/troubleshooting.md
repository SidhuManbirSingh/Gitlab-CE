# Troubleshooting Guide — GitLab Kubernetes Deployment

This document covers all known issues and their fixes for the GitLab + PostgreSQL + Runner stack running on Minikube (WSL2).

---

## 1. `kubectl` Not Found on Windows

**Symptom:**
```
kubectl : The term 'kubectl' is not recognized...
```

**Cause:** 
`kubectl` is not installed system-wide on Windows or not in the PATH.

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

**Cause:** 
Minikube is not running. The Kubernetes API server is down.

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

**Cause:** 
In `k8s/base/configmap.yaml`, the `db_host` and `db_password` lines were commented out, so GitLab did not know which host to connect to or which password to use.

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

**Cause:** 
After a `kubectl rollout restart`, the old GitLab pod may not terminate before the new one starts. Both pods try to use the same PersistentVolumeClaims simultaneously, causing lock conflicts with Gitaly's log service.

**Fix:** 
Delete the deployment entirely and recreate it cleanly:

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

**Cause:** 
Timing issue — the PVC was being provisioned when the pod was first scheduled.

**Fix:** 
This resolves itself automatically within a minute or two as the default StorageClass provisions the volume. Verify with:

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

**Cause:** 
Minikube runs inside the WSL2 virtual machine. The NodePort IP `192.168.49.2` is **only reachable within WSL2**, not from the Windows host directly.

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

> **Warning:** Deleting the namespace or running `minikube delete` will destroy all PersistentVolumeClaims and all stored GitLab data.

---

## 9. GitLab Takes Too Long to Start

**Symptom:** 
GitLab pod shows `0/1 Running` for a long time.

**Cause:** 
This is **normal**. GitLab CE is a heavy application that runs many internal services (Puma, Sidekiq, Gitaly, Nginx, etc.) and can take **5–10 minutes** on first boot, especially with limited resources.

**What to watch:**

```bash
kubectl -n gitlab get pods --watch
```

The startup probe allows up to **10 minutes** (`failureThreshold: 60` × `periodSeconds: 10`). Once the probe passes, the pod will transition to `1/1 Running`.

---

## 10. Grafana Cannot Find Prometheus Data Source

**Symptom:**
Adding `http://localhost:9090` as the Prometheus URL in Grafana fails to connect.

**Cause:** `localhost` inside the Grafana UI refers to the Grafana container itself, not the Windows machine or the cluster.

**Fix:**
Internal cluster services must communicate using Kubernetes DNS. Use the exact service name: `http://prometheus-service:9090`.

---

## 11. Prometheus Not Scraping Hardware Metrics (401 Unauthorized)

**Symptom:**
Prometheus shows targets as "Down" with 401 Unauthorized errors from the Kubelet.

**Cause:** Minikube secures its node APIs. Prometheus needs explicit authentication injected into `prometheus-config.yaml`.

**Fix:**
Add `bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token` and `insecure_skip_verify: true` to the scrape jobs so Prometheus can securely impersonate a valid service account.

---

## 12. Prometheus Missing cAdvisor/Node Telemetry (RBAC Limits)

**Symptom:**
Even when authenticated, Prometheus cannot read raw CPU/Memory metrics from pods.

**Cause:** The default Prometheus `ClusterRole` lacks deep node-level scraping authorizations.

**Fix:**
We updated the `resources` array inside `rbac.yaml` to explicitly include `nodes/proxy` and `nodes/stats`.

**How it Works:** 
Prometheus is a "pull" based scraper. It actively requests logs from nodes on a timer. By granting these RBAC permissions, the Kubernetes API allows Prometheus to look past the generic node status and read the sub-proxy telemetry detailing exactly how much RAM each pod is consuming.

---

## 13. Understanding Port Forwarding vs Internal DNS

**Question:** 
Why do we port-forward some tools but not others?

**Explanation:** 
- **Internal DNS (No port-forward needed):** Backend machine-to-machine communication (like Fluent Bit sending logs to Elasticsearch, or Grafana querying Prometheus) happens entirely inside the Minikube virtual machine. They just use their service names (`http://elasticsearch-master:9200`).
- **Port-Forwarding:** Whenever a *human* needs to view a Web UI (like Kibana, Grafana, or GitLab) on a Windows Chrome browser, we must build a bridge. `kubectl port-forward` drills a temporary tunnel through the Minikube wall to map internal UI ports directly to your Windows `localhost`.

---

## 14. Elasticsearch / Kibana Pods Crashing (OOMKilled)

**Symptom:**
Extracting the EFK stack logs reveals sudden pod terminations labeled `OOMKilled`.

**Cause:** Elasticsearch defaults to consuming huge blocks of JVM Heap memory, instantly exhausting the local Minikube virtual machine's RAM allocation.

**Fix:**
We capped the Elasticsearch JVM footprint by injecting `esJavaOpts: "-Xmx1g -Xms1g"` into our customized `es-values.yaml`, strictly locking its compute footprint to 1GB.

---

## 15. Bypassing Elasticsearch Security Tokens

**Symptom:**
Kibana falls into a `CreateContainerConfigError` boot loop demanding an `elasticsearch-enrollment-token`.

**Cause:** Elastic version 8.x aggressively enforces secure TLS setups and user authentication loops out-of-the-box.

**Fix:**
To save extreme computing overhead and ensure maximum speed on the local Minikube stack, we deliberately chose an unsecured internal approach by disabling X-Pack security (`xpack.security.enabled: false`). We then completely bypassed Kibana's strict booting constraints by manually injecting an empty dummy secret `kibana-kibana-es-token` directly into the cluster dataset.

---

## 16. The Hidden HTTPS Readiness Probe Mismatch

**Symptom:**
Elasticsearch container starts successfully, but Kubernetes permanently flags the pod as `0/1 Not Ready`.

**Cause:** We disabled `xpack.security.http.ssl.enabled` to run plain HTTP. However, the Helm chart's hardcoded readiness probe *assumes* HTTPS by default, attempting a secure TLS handshake against an unsecured port, instantly failing the health check!

**Fix:**
Explicitly add `protocol: http` to the `es-values.yaml` configuration to force the readiness probe to drop the "s" in its internal curl testing script. (This hidden requirement is widely missing from official Elastic documentation and took extensive deduction to figure out).

---

## 17. The Fluent Bit Architectural Shift

**Symptom:**
Local computers instantly crash or throttle to a halt when attempting to run the full ELK stack.

**Cause:** The traditional Logstash indexer is a monolithic app requiring immense JVM memory overhead just to filter text.

**Fix:**
We discarded Logstash completely and deployed **Fluent Bit**—an ultra-lightweight C-binary DaemonSet. To ensure native compatibility with Kibana, we flipped the `Logstash_Format On` configuration in Fluent Bit, allowing it to seamlessly impersonate Logstash indices (`logstash-*`) while saving gigabytes of local memory.

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
| Grafana can't see Prometheus | Using `localhost` instead of DNS | Use `http://prometheus-service:9090` |
| Prometheus 401 Unauthorized | Missing API authentication | Inject `bearer_token_file` to scrape jobs |
| Missing CPU/RAM metrics | Strict default RBAC | Add `nodes/stats` and `nodes/proxy` to ClusterRole |
| ES / Kibana OOMKilled | Java Heap limits exceeded | Add `esJavaOpts: -Xmx1g` to cap VM footprint |
| Kibana Token Boot-loop | Strict Elastic Security | Inject dummy `kibana-kibana-es-token` secret |
| 0/1 ES Readiness Probe | Helmet assumes HTTPS | Explicitly override `protocol: http` in values |
| Host Machine Crashing | Logstash Java Monolith | Downgrade to Fluent Bit using `Logstash_Format On` |
