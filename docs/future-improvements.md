# Future Improvements & Roadmap

This document outlines the planned technical upgrades and feature sets to transition this project from a local Minikube environment to a production-grade enterprise architecture.

## Upcoming Milestones

### 1. Application Integration: Python Microservice
- Deploy a standalone **Python (Flask/FastAPI) microservice** within the cluster.
- Utilize the self-hosted GitLab CI/CD platform to automate testing and containerization.
- Demonstrate full source-to-deployment workflow using internal registries.

### 2. Infrastructure-as-Code (IaC): Terraform
- Migrate manual cluster configurations to **Terraform**.
- Use provider-specific modules to manage cloud-native Kubernetes (EKS/GKS/AKS) or local providers.
- Implement version-controlled infrastructure drift management.

### 3. Monitoring Refinement: Label Naming Strategy
- Standardize **Label Management** across Prometheus and Grafana.
- Implement custom tagging for environment-specific metrics (Prod vs Staging).
- Clean up metric naming conventions to improve dashboard readability and query speed.

### 4. Enterprise Logging: Transition to Logstash (JVM)
- Scale the infrastructure to support the full **Java-based Logstash implementation**.
- Transition from the lightweight Fluent Bit scraper to a complete Logstash indexing cluster.
- Leverage Logstash's advanced plugin library for complex data filtering and multi-destination routing.

### 5. Automated Cloud Backups
- Shift from local disk-based persistence to **Cloud Storage (AWS S3, Azure Blob, or GCP Storage)**.
- Implement automated snapshotting of PostgreSQL and GitLab data volumes.
- Configure cross-region redundancy for disaster recovery simulations.
