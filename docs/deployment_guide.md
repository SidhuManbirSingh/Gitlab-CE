# Deployment Guide: CI/CD Platform Infrastructure

This document provides step-by-step instructions for deploying a fully functional, containerized CI/CD Platform stack (GitLab CE, PostgreSQL 16, and GitLab Runner) using Docker Compose.

---

## 1. Prerequisites

- **Host OS:** Linux environment (e.g., Ubuntu, KDE Plasma) with Docker Engine and Docker Compose installed.
- **CPU:** ≥ 3 cores (GitLab requires 2 cores minimum; Runner requires 1 core).
- **Memory:** ≥ 14 GB RAM on the host (8 GB allocated to GitLab, 1 GB to Runner — remaining headroom prevents host swapping).
- **Network:** Ports `8081` (HTTP), `8443` (HTTPS), and `2223` (SSH) must be available on the host machine.

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