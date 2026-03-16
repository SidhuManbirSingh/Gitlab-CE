#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/$DATE"
mkdir -p $BACKUP_DIR

echo "Creating official GitLab application backup..."
# This safely backs up the DB, Git repos, and attachments into a single tar within the container
docker exec -t gitlab-ce gitlab-backup create

echo "Backing up critical configuration files (gitlab.rb & secrets.json)..."
# GitLab backups DO NOT include the configuration and encryption keys. We must back them up manually.
docker run --rm \
  -v gitlab_config:/etc/gitlab \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/$DATE/gitlab_config.tar.gz /etc/gitlab

echo "Backup complete. Application tar is inside the gitlab_data volume; config is located in $BACKUP_DIR."
