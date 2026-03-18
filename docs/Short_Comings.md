# KNOWN SHORTCOMINGS (Identified & Acknowledged)

• **Backup destination**— backup.sh writes to the local repo directory (./backups/).
  For production, backups should go off-machine (e.g. S3, NFS, or rsync to a remote).
  Kept in-directory for submission/demo purposes only.

• **NodePort Exposure** — GitLab is exposed via NodePort (port 30080) which is a
  dev/minikube pattern only. Production requires Ingress + cert-manager for proper
  HTTPS termination. This is the next planned step.

• **No HTTPS / TLS** — Currently running HTTP only. Need to enable CA certificates and
  configure HTTPS via Ingress + cert-manager or self-signed certs.

• **No monitoring stack** — No Prometheus/Grafana for metrics and alerting.
  Grafana would be the ideal node to add for dashboards and alerting rules.

• **No centralized logging** — No ELK/Kibana stack for log aggregation and searching
  across GitLab, Postgres, and Runner pods.


# FUTURE IMPROVEMENTS (Planned)

• Ingress controller + cert-manager for HTTPS (replaces NodePort)
• Prometheus + Grafana for metrics, monitoring, and alerting
• Kibana / ELK stack for centralized log aggregation
• StatefulSet for Postgres instead of Deployment
• External backup destination (S3 / remote rsync)
• Vault or Sealed Secrets for production-grade secret management


-- Note: The above are future-state goals, not required for current submission.
