# Deployment Guide: CI/CD Platform Infrastructure

This document provides step-by-step instructions for deploying a fully functional, containerized CI/CD Platform stack (GitLab CE, PostgreSQL 16, and GitLab Runner) using *docker-compose*.

---

## 1. Prerequisites

*Note: This guide assumes you are deploying on a Linux environment (e.g., Ubuntu, KDE Plasma) with Docker Engine and Docker Compose installed. I have tested this guide on Linux KDE Plasma. I have mentioned the resources allocated by me on my machine.*

### Machine Specifications

> **Command Used:** `(base) sidhu@sidhu-kde:~$ lscpu`

**Architecture:** x86_64  
**CPU op-mode(s):** 32-bit, 64-bit  
**Address sizes:** 48 bits physical, 48 bits virtual  
**Byte Order:** Little Endian  

**CPU(s):** 12  
**On-line CPU(s) list:** 0-11  
**Vendor ID:** AuthenticAMD  
**Model Name:** AMD Ryzen 5 5500U with Radeon Graphics  
**CPU Family:** 23  
**Model:** 104  
**Thread(s) per core:** 2  
**Core(s) per socket:** 6  
**Socket(s):** 1  
**Stepping:** 1  
**Frequency boost:** enabled  
**CPU(s) scaling MHz:** 44%  
**CPU max MHz:** 4056.0000  
**CPU min MHz:** 400.0000  
**BogoMIPS:** 4191.91  

**Flags:**  
fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_good nopl xtopology nonstop_tsc cpuid extd_apicid aperfmperf rapl pni pclmulqdq monitor ssse3 fma cx16 sse4_1 sse4_2 movbe popcnt aes xsave avx f16c rdrand lahf_lm cmp_legacy svm extapic cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw ibs skinit wdt tce topoext perfctr_core perfctr_nb bpext perfctr_llc mwaitx cpb cat_l3 cdp_l3 hw_pstate ssbd mba ibrs ibpb stibp vmmcall fsgsbase bmi1 avx2 smep bmi2 cqm rdt_a rdseed adx smap clflushopt clwb sha_ni xsaveopt xsavec xgetbv1 cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local clzero irperf xsaveerptr rdpru wbnoinvd cppc arat npt lbrv svm_lock nrip_save tsc_scale vmcb_clean flushbyasid decodeassists pausefilter pfthreshold avic v_vmsave_vmload vgif v_spec_ctrl umip rdpid overflow_recov succor smca

**Virtualization:** AMD-V  

**Caches (sum of all):**  
- L1d: 192 KiB (6 instances)  
- L1i: 192 KiB (6 instances)  
- L2: 3 MiB (6 instances)  
- L3: 8 MiB (2 instances)  

**NUMA Nodes:**  
- NUMA node(s): 1  
- NUMA node0 CPU(s): 0-11  

**Vulnerabilities:**  
- Gather data sampling: Not affected  
- Ghostwrite: Not affected  
- Indirect target selection: Not affected  
- Itlb multihit: Not affected  
- L1tf: Not affected  
- Mds: Not affected  
- Meltdown: Not affected  
- Mmio stale data: Not affected  
- Reg file data sampling: Not affected  
- Retbleed: Mitigation; untrained return thunk; SMT enabled with STIBP protection  
- Spec rstack overflow: Mitigation; Safe RET  
- Spec store bypass: Mitigation; Speculative Store Bypass disabled via prctl  
- Spectre v1: Mitigation; usercopy/swapgs barriers and __user pointer sanitization  
- Spectre v2: Mitigation; Retpolines; IBPB conditional; STIBP always-on; RSB filling; PBRSB-eIBRS Not affected; BHI Not affected  
- Srbds: Not affected  
- Tsa: Not affected  
- Tsx async abort: Not affected  
- Vmscape: Mitigation; IBPB before exit to userspace

**Host OS:** Linux environment (e.g., Ubuntu, KDE Plasma) with Docker Engine and Docker Compose installed.

**CPU:** ≥ 3 cores (GitLab requires 2 cores minimum; Runner requires 1 core).

**Memory:** ≥ 15 GB RAM on the host (8 GB allocated to GitLab, 1 GB to Runner and remaining headroom prevents host swapping).

**Network:** Ports `8081` (HTTP), `8443` (HTTPS), and `2223` (SSH) must be available on the host machine.

---

## 2. Environment Configuration (`.env`)

To prevent configuration drift and securely manage credentials, externalize your environment variables.

**1. Create the `.env` file** in the root of your project directory:

```bash
touch .env
```

**2. Populate** the `.env` file with the following parameters, ensuring the external URL exactly matches the port you intend to expose:

```env
# --- DATABASE CONFIGURATION ---
POSTGRES_DB=gitlabhq_production
POSTGRES_USER=gitlab
POSTGRES_PASSWORD=SuperSecretDatabasePassword123

# --- GITLAB CONFIGURATION ---
GITLAB_ROOT_PASSWORD=SuperSecretRootPassword123
GITLAB_HOSTNAME=localhost

# CRITICAL: This must match the host port mapped in docker-compose.yml
GITLAB_EXTERNAL_URL=http://localhost:8081
```

> **Security Note:** Add `.env` to your `.gitignore` file to ensure secrets are never committed to your version control repository.

---

## 3. Infrastructure as Code (`docker-compose.yml`)

Create your `docker-compose.yml` with the following configuration. Several values below differ from common examples online — each deviation is intentional and documented.

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine # GitLab requires PostgreSQL 16 or higher
    container_name: gitlab-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}" ]
      interval: 10scp # Prevents GitLab from crashing during CI/CD pipeline execution
      timeout: 5s
      retries: 5

  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab-ce
    restart: unless-stopped
    hostname: ${GITLAB_HOSTNAME}
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url '${GITLAB_EXTERNAL_URL}'
        gitlab_rails['db_adapter'] = 'postgresql'
        gitlab_rails['db_encoding'] = 'unicode'
        gitlab_rails['db_host'] = 'postgres'
        gitlab_rails['db_port'] = 5432
        # Ensure these match your .env variable names exactly
        gitlab_rails['db_database'] = "${POSTGRES_DB}"
        gitlab_rails['db_username'] = "${POSTGRES_USER}"
        gitlab_rails['db_password'] = "${POSTGRES_PASSWORD}"
        gitlab_rails['initial_root_password'] = "${GITLAB_ROOT_PASSWORD}"

        puma['listen'] = '0.0.0.0'
        puma['port'] = 8083
        gitlab_workhorse['auth_backend'] = "http://localhost:8083"
    ports:
      - "8081:8081" # Changed from 8081:80 — required when external_url includes the port number
      - "8443:443"
      - "2223:22"   # Changed from 2222 to avoid conflicts with other services
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
    networks:
      - frontend
      - backend
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost/-/health" ]
      interval: 60s
      timeout: 10s
      retries: 10
      start_period: 300s # Allows 5 minutes for first-boot migrations to complete
    deploy:
      resources:
        limits:
          memory: 8g   # Increased from 4g — prevents GitLab from crashing under CI/CD load
          cpus: '2.0'  # Increased from 1.0 — required for stable pipeline execution

  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner
    restart: unless-stopped
    volumes:
      - runner_config:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - backend
    depends_on:
      - gitlab
    deploy:
      resources:
        limits:
          memory: 1G   # Increased from 512m — prevents Runner from crashing during jobs
          cpus: '1.0'  # Increased from 0.5 — required for stable job execution

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true # Isolates backend services from direct host network access

volumes:
  postgres_data:
  gitlab_config:
  gitlab_logs:
  gitlab_data:
  runner_config:
```

### Key Configuration Decisions

Several settings in this file resolve real issues encountered during deployment:

| Setting | Value Used | Why |
|---|---|---|
| `postgres` image | `postgres:16-alpine` | GitLab CE requires PostgreSQL 16 or higher |
| PostgreSQL healthcheck `interval` | `10scp` | Prevents GitLab from crashing during pipeline execution |
| `puma['port']` | `8083` | Avoids internal port conflicts with NGINX on `8080`/`8082` |
| GitLab port mapping | `8081:8081` | Required when `external_url` includes the port — `8081:80` will not work |
| SSH port mapping | `2223:22` | Avoids conflict with other services using `2222` |
| GitLab `depends_on` | `condition: service_healthy` | Ensures PostgreSQL is fully ready before GitLab starts |
| GitLab `memory` limit | `8g` | Prevents OOM crashes under CI/CD load (was `4g`) |
| GitLab `cpus` limit | `2.0` | Required for stable pipeline execution (was `1.0`) |
| Runner `memory` limit | `1G` | Prevents Runner OOM during job execution (was `512m`) |
| Runner `cpus` limit | `1.0` | Required for stable job execution (was `0.5`) |

---

## 4. Deployment & Initialization Steps

**1. Start the Service Stack**

Execute the following command in the directory containing your Compose file:

```bash
sudo docker-compose up -d
```

**2. Monitor the Automated Provisioning**

GitLab runs hundreds of database migrations on its first boot. **This process takes 5–10 minutes.** Monitor progress with:

```bash
sudo docker logs -f gitlab-ce
```

> Do not attempt to access the web UI until you see the message: `Chef Infra Client finished`.

**3. Verify Internal Health**

Confirm the Puma backend is responding before opening the browser:

```bash
sudo docker exec -it gitlab-ce curl -sI http://localhost:8083/users/sign_in
```

> An `HTTP 200 OK` or `302 Found` response confirms the backend is healthy.

---

## 5. Post-Deployment: GitLab Runner Registration

The GitLab Runner must be explicitly registered to the GitLab instance to execute CI/CD pipelines over the isolated `backend` network.

**1. Access the Web Interface**

Navigate to `http://localhost:8081` and log in as `root` using your configured password.

**2. Generate a Token**

Navigate to **Admin Area → CI/CD → Runners**. Click **New instance runner**, select Linux, and copy the provided Authentication Token.

**3. Execute the Handshake**

Run the following command in your host terminal, replacing the token placeholder. The URL uses the container hostname (`gitlab-ce`) rather than `localhost` because the runner communicates over the internal `backend` network:

```bash
sudo docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab-ce" \
  --token "YOUR_COPIED_TOKEN_HERE" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "docker-runner" \
  --docker-network-mode "backend"
```

**4. Verify Registration**

Refresh the Runners page in the GitLab UI. A green **"Online"** status indicator confirms the runner is ready to process jobs.

---

## 6. Architecture & Networking Summary

This deployment implements strict network isolation to mimic production-grade security:

| Component | Network Assignment | Responsibility / Routing |
|---|---|---|
| **PostgreSQL** | `backend` (Internal) | Stores all GitLab metadata. Fully isolated from host access. |
| **GitLab CE** | `frontend` & `backend` | The CI/CD brain. Accepts external traffic on `8081`, communicates with PostgreSQL over `backend`. |
| **GitLab Runner** | `backend` (Internal) | The job executor. Spawns temporary pipeline containers inside the secure backend network. |

---

## 7. Level 2: Production Hardening Features

This deployment implements advanced production-grade security and reliability features, addressing all Level 2 project requirements.

### 1. Reverse Proxy (TLS Termination)
We employ an Alpine-based `nginx` container acting as a reverse proxy for the CI/CD platform:
- **Port Mapping**: The proxy is the **only** entry point exposed to the host machine, listening on standard ports `80` (HTTP) and `443` (HTTPS).
- **Redirection**: All incoming HTTP traffic on port `80` is automatically redirected to `443`.
- **Backend Routing**: Nginx terminates the SSL connection and proxies the unencrypted traffic internally over the `frontend` bridge network directly to the backend `gitlab-ce` container on port `8081`.

*(This approach enables HTTPS protection while explicitly instructing GitLab's Omnibus internal webserver to disable its own costly automatic HTTPS generation).*

### 2. Secrets Management
Passwords and credentials are **not stored** as environment variables or hardcoded inside the project repository.
- **Implementation**: The infrastructure uses the `docker secrets` engine.
- **Workflow**: Passwords for PostgreSQL and the initial GitLab root account are stored in physical text files located in `docker/secrets/`. These files are mapped with strict `600` permissions (read/write only by the owner). 
- **Injection**: Docker mounts these secret files into the containers' isolated memory (`/run/secrets/`), preventing them from ever touching the container disk, appearing in system logs, or leaking via `docker inspect`.
- *(Note: A `secrets-example/` template directory is tracked in version control, while the real `secrets/` directory is `.gitignore`d).*

### 3. Centralized Logging & Retention Restrictions
Unrestricted container logging can lead to a disk-exhaustion crash on the host operating system. To mitigate this:
- **Retention Strategy**: We explicitly declare the standard `json-file` logging driver for both the heavy `gitlab-ce` and `postgres` services inside `docker-compose.yml`.
- **Size Caps**: The `max-size` parameter restricts individual log files to a maximum of `50m` (50 Megabytes).
- **Rotation**: The `max-file` parameter enforces a ceiling of 5 archived files per container. If the maximum is reached, Docker will automatically purge the oldest 50MB log.

### 4. Backup & Disaster Recovery
A highly robust automation script, `scripts/backup.sh`, is provided to safely snapshot the CI/CD environment without corrupting the underlying Git repositories or tracking metadata.
- **Application Tarball**: The script leverages GitLab's native `gitlab-backup create` internal utility to safely compress the core PSQL database, uploaded attachments, and active Git repositories into a centralized archive.
- **Configuration Safely Extracted**: Since the native utility deliberately skips configuration and encryption keys, the script spins up a temporary (`--rm`) Alpine container. This container mounts the persistent `gitlab_config` volume, tars the critical `/etc/gitlab/gitlab.rb` and `gitlab-secrets.json` files, and extracts them to the host's `backups/` directory.

---

## 8. Kubernetes Deployment Transition

Transitioning this stack to Kubernetes provides highly resilient, scalable infrastructure needed to reliably execute containerized pipelines. The deployment has been migrated from `docker-compose` to consolidated Kubernetes manifests located in the `k8s/base/` directory.

### Execution

Ensure your local Kubernetes cluster (like Minikube or kind) is running, and then deploy the entire architecture at once:

```bash
kubectl apply -f k8s/base/
```

To watch the deployment come alive, run:

```bash
kubectl get pods -n gitlab -w
```

Once the GitLab pod reaches a `Running` state, you can use `kubectl exec` into the `gitlab-runner` pod to register the runner with the GitLab instance.