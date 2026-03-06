# GitLab CI/CD Monitoring Stack

## Section 1 — Stack Overview

GitLab CE is a self-hosted DevOps platform that provides Git repository management, CI/CD pipelines, issue tracking, and merge request workflows. It allows development teams to manage the entire software development lifecycle in one platform.

PostgreSQL serves as the primary database backend for GitLab. It stores all application data such as user accounts, project metadata, issues, merge requests, and CI/CD pipeline information.

GitLab Runner is a separate execution agent responsible for processing CI/CD pipeline jobs. It receives tasks from the GitLab server and executes them in isolated environments, such as containers or virtual machines.

---

## Section 2 — Component Architecture

The architecture of the system consists of three main components: GitLab CE, PostgreSQL, and GitLab Runner.

GitLab CE acts as the *main application server*. It provides the web interface, repository management, authentication, CI/CD orchestration, and API endpoints.

PostgreSQL functions as the *backend database server*. It stores all persistent application data required for GitLab to function.

GitLab Runner operates as an *independent service* responsible for executing CI/CD jobs defined in project pipelines. It communicates with the GitLab server to receive jobs and report results.

These components are separated to improve scalability, security, and reliability. By separating the GitLab Runner from the main GitLab application, CI/CD workloads can be scaled independently without affecting the core GitLab service. This also isolates job execution from the main application environment, reducing potential security risks.

---

## Section 3 — Network Design

The network configuration ensures that only necessary services are exposed externally while internal components communicate securely within the Docker network.

GitLab requires several ports to be accessible. HTTP (port 80) allows users to access the GitLab web interface through a browser. HTTPS (port 443) is used for secure web traffic. SSH (port 22) is required for developers who clone and push repositories using Git over SSH.

PostgreSQL does not have any externally exposed ports. This design prevents direct access to the database from outside the container network, significantly reducing security risks. Only the GitLab application container can communicate with the PostgreSQL database internally.

This network design follows the principle of least exposure by limiting external access only to services that users must interact with. 

**GitLab**

  ├── HTTP (80)

  ├── HTTPS (443)

  └── SSH (22)

**PostgreSQL**

  └── Internal only (not exposed)

---

## Section 4 — Storage Design

Persistent storage volumes are used to ensure that critical data is not lost when containers restart or are recreated.

| Data Volume Name | Why it Needs Persistence |
|------------------|--------------------------|
| **gitlab_data** | Stores GitLab repositories and application data. Losing this volume would result in the loss of all project code and repository history. |
| **gitlab_logs** | Contains GitLab log files used for debugging, monitoring, and auditing system activity. |
| **gitlab_config** | Stores GitLab configuration files so that settings remain consistent across container restarts. |
| **postgres_data** | Holds the PostgreSQL database files that store all GitLab application data. Losing this volume would mean losing the entire database. |
| **runner_config** | Stores GitLab Runner configuration, including the runner registration token and settings required for CI/CD job execution. |

## Section 5 — Security Analysis

1. No hardcoded passwords — all credentials via environment variables
2. PostgreSQL not exposed externally
3. GitLab Runner uses a registration token to authenticate with GitLab
4. SSH on non-standard port (2222) reduces automated attack attempts

## Section 6 — Scalability

GitLab Runner is the easiest thing to scale and we can register multiple runners for parallel pipeline execution. PostgreSQL can be scaled with read replicas. GitLab CE itself would require shared storage (like NFS or S3) for true horizontal scaling.