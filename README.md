<<<<<<< HEAD
# CIS 395 - Level 3 CI/CD Platform Project

Welcome to the comprehensive CI/CD Platform deployment project! This repository contains the completely containerized infrastructure required to run a production-grade GitLab instance, PostgreSQL database, and GitLab Runner.

## Deployment Evolution

This project has evolved through three distinct levels of maturity:

1. **Level 1 (Docker Compose):** Initial monolithic deployment using `docker-compose.yml` to define the stack, establishing internal networks and persistent volumes.
2. **Level 2 (Production Hardening):** Added advanced security and reliability features, including automated database backups (`scripts/backup.sh`), secret injection via `docker secrets` instead of environment variables, Nginx automated reverse proxies, and rigid container logging constraints.
3. **Level 3 (Kubernetes Migration):** The entire stack was successfully migrated to a resilient, self-healing **Kubernetes** environment.

## Repository Structure

- `k8s/base/`: Contains the Kubernetes manifests (Deployments, Services, ConfigMaps, Secrets, PVCs) that manage the current state of the platform. --Working but needs more work
- `docs/`: Contains the extensive `deployment_guide.md` and `architecture.md` breaking down the technical design and deployment steps.
- `docker/`: Contains the legacy docker-compose files and the strictly managed `secrets/` directory.
- `scripts/`: Contains the disaster recovery backup automation scripts. -- Still Under development 
- `nginx/`: Contains the custom configurations used for the Level 2 reverse proxy.

## Key Features
- **High Availability & Self-Healing:** Kubernetes continuously monitors the health probes on the GitLab and Runner deployments.
- **Resource Limits:** Pods strictly define CPU and Memory requests/limits to prevent noisy neighbor resource exhaustion.
- **Persistent Storage:** PVCs guarantee that Git repositories and PostgreSQL data survive pod recycles.
- **Secured Credentials:** All passwords and tokens are base64-encoded and mounted directly into the containers via Kubernetes `Secret` volumes.

## Getting Started

Please refer to the `docs/deployment_guide.md` file for step-by-step instructions on deploying this infrastructure to either Docker Compose or a Kubernetes cluster like Minikube.
=======
# Readme test from a differnt machine
>>>>>>> 2e948806fe415ddcd358b0e3ca82714bd5ed2689
