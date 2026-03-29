# GitLab CI/CD Infrastructure — Self-Hosted Stack

A complete, self-hosted GitLab CI/CD platform built from scratch using **Docker Compose** and **Kubernetes (Minikube)**. The project demonstrates a progression from a basic containerised setup to a production-grade Kubernetes deployment, covering networking, security, persistence, and operational tooling.

## What This Project Does

This project provisions and orchestrates three core services:

| Service | Image | Role |
|---------|-------|------|
| **GitLab CE** | `gitlab/gitlab-ce` | Source code management, CI/CD pipelines, issue tracking |
| **PostgreSQL** | `postgres:16-alpine` | External database backend for GitLab |
| **GitLab Runner** | `gitlab/gitlab-runner` | Executes CI/CD pipeline jobs |

The stack is deployed in two layers:

1. **Docker Compose** — local development environment with hardened security (secrets engine, reverse proxy, log rotation, resource limits).
2. **Kubernetes** — production-style deployment on Minikube with namespace isolation, health probes, PVCs, and resource management.

---

## Project Directory

```text
Project/
│
├── docker/                          # Docker Compose deployment
│   ├── docker-compose.yml           # Orchestrates GitLab, Postgres, Runner, Nginx
│   ├── .env.example                 # Template for environment variables
│   ├── config/                      # GitLab configuration mount point
│   ├── secrets/                     # Docker secrets (gitignored)
│   └── secrets-example/             # Example secret files for reference
│       ├── postgres_password.txt
│       └── gitlab_root_password.txt
│
├── k8s/                             # Kubernetes deployment
│   ├── base/                        # Base manifests
│   │   ├── namespace.yaml           # 'gitlab' namespace definition
│   │   ├── secrets.yaml             # K8s secrets (gitignored)
│   │   ├── configmap.yaml           # GitLab config (DB, URL, ports)
│   │   ├── cert-manager-issuer.yaml # ClusterIssuer for local HTTPS
│   │   ├── rbac.yaml                # View node permissions for Prometheus
│   │   ├── postgres.yaml            # Postgres Deployment + Service + PVC
│   │   ├── gitlab.yaml              # GitLab Deployment + Probes
│   │   ├── runner.yaml              # Runner Deployment + Docker socket mount
│   │   ├── kubectl                  # Helper binary for execution
│   │   └── minikube-linux-amd64     # Minikube binary helper
│   └── logging/                     # EFK Logging Stack config
│       ├── es-values.yaml           # Elasticsearch custom Helm values
│       ├── kibana-values.yaml       # Kibana custom Helm values
│       └── fluent-bit-values.yaml   # Fluent Bit daemonset config
│
├── nginx/                           # Reverse proxy configuration
│   ├── nginx.conf                   # Nginx config (frontend proxy for GitLab)
│   └── ssl/                         # SSL certificates placeholder (gitignored)
│
├── scripts/                         # Operational scripts
│   ├── init.sh                      # Initialises directories, sets permissions
│   ├── backup.sh                    # Backs up GitLab data + config
│   ├── deploy-k8s.sh                # Fail-safe unified port-forwarding script
│   └── backups/                     # Backup output directory
│
├── docs/                            # Project documentation
│   ├── architecture.md              # Architecture overview
│   ├── deployment_guide.md          # Full deployment walkthrough
│   ├── troubleshooting.md           # Issues and resolutions
│   ├── Short_Comings.md             # Known limitations and improvements
│   ├── working-towards-HTTPS.md     # SSL/TLS migration notes
│   ├── Implementing-Data-Scrapping-and-Visualization.md # Prometheus & Grafana docs
│   ├── Implementing-Logging.md      # EFK Stack documentation
│   ├── architecture-diagram.jpeg    # High-level overview
│   ├── architecture-overall.png     # Setup diagram
│   ├── https-traffic.png            # HTTPS traffic flow diagram
│   ├── k8s-architecture.png         # K8s components diagram
│   └── network-topology-diagram.jpeg# Network topology diagram
│
├── img/                             # Screenshots and evidence
│   ├── Runner-Online.png            # Runner registration proof
│   └── runner-k8s.png               # Runner running on Kubernetes
│
├── .gitignore                       # Ignores secrets, .env, SSL keys
├── gitlab-ci-test.yml               # Sample CI pipeline
└── project.pdf                      # Project specification
```

---

## Architecture Overview

```
                     ┌──────────────┐
                     │   Browser    │
                     └──────┬───────┘
                            │ HTTPS :443
                     ┌──────▼───────┐
                     │    NGINX     │
                     │   Ingress    │
                     └──────┬───────┘
                            │
                ┌───────────▼───────────┐
                │      GitLab CE        │
                │  (Web UI + API + Git) │
                └───┬───────────────┬───┘
                    │               │
           ┌────────▼──────┐  ┌────▼──────────┐
           │  PostgreSQL   │  │ GitLab Runner  │
           │  (ClusterIP)  │  │ (CI executor)  │
           └───────────────┘  └────────────────┘
```

- **PostgreSQL** is internal-only (`ClusterIP`) — never exposed outside the cluster
- **GitLab Runner** connects back to GitLab over internal service DNS
- **Nginx** (Docker Compose) or **HTTPS Ingress Controller** (Kubernetes) handles secure external access

---

## Key Design Decisions

### Security
- **Docker Secrets engine** — passwords injected via `/run/secrets/`, never stored in env vars or image layers
- **Secrets gitignored** — both `docker/secrets/` and `k8s/base/secrets.yaml` are excluded from version control
- **Network isolation** — PostgreSQL only accessible from within the Docker network / Kubernetes namespace
- **Permission hardening** — `init.sh` enforces `chmod 600` on secret files and `700` on the secrets directory

### Reliability (Kubernetes)
- **All 3 probe types** — `startupProbe` (10-min grace for initial boot), `livenessProbe`, and `readinessProbe`
- **Resource requests & limits** — defined on every pod to prevent resource contention
- **Persistent Volume Claims** — separate PVCs for GitLab config, logs, data, and Postgres data
- **Namespace isolation** — all resources live in the `gitlab` namespace

### Operations
- **Automated backups** — `backup.sh` runs `gitlab-backup create` and archives configuration separately
- **Initialisation script** — `init.sh` creates required directories and sets correct permissions
- **Log rotation** — Docker Compose configures `max-size: 50m` and `max-file: 5` to prevent disk exhaustion

---

## Documentation

| Document | Description |
|----------|-------------|
| [architecture.md](docs/architecture.md) | Component responsibilities, network design, storage strategy, and security model |
| [deployment_guide.md](docs/deployment_guide.md) | Step-by-step deployment for both Docker Compose and Kubernetes |
| [troubleshooting.md](docs/troubleshooting.md) | Real issues encountered during setup and their resolutions |
| [Short_Comings.md](docs/Short_Comings.md) | Honest assessment of current limitations and planned improvements |
| [Implementing-Data-Scrapping-and-Visualization.md](docs/Implementing-Data-Scrapping-and-Visualization.md) | Deep-dive into Prometheus scraping and Grafana dashboard integration |
| [Implementing-Logging.md](docs/Implementing-Logging.md) | Architectural details on debugging and deploying the customized EFK stack |

---

## Prerequisites

- Docker Engine & Docker Compose
- Minikube (with Docker driver) + `kubectl`
- Minimum 4 GB RAM and 2 CPUs allocated to Minikube
- WSL2 (if running on Windows)

---

## Known Limitations & Future Work

Mentioned inside of the Short_Comings.md file. 

**Key items:**

- ~~**NodePort**~~ → Successfully migrated to secure **Ingress + Cert-Manager for HTTPS**!
- ~~**No monitoring**~~ → Successfully integrated **Prometheus (Scraper) & Grafana (Dashboard)**!
- ~~**No centralized logging**~~ → Successfully deployed **EFK Stack (Elasticsearch, Fluent Bit, Kibana)**!
- **Local backups** → production would use S3 or remote storage
