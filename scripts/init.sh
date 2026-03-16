#!/bin/bash

# Configuration
DOCKER_DIR="docker"
SECRETS_DIR="${DOCKER_DIR}/secrets"
NGINX_SSL_DIR="nginx/ssl"

echo "Running initial setup for CI/CD Stack Deployment..."

# 1. Directory Creation
echo "=> Ensuring required directories exist"
mkdir -p "${SECRETS_DIR}"
mkdir -p "${NGINX_SSL_DIR}"
mkdir -p "scripts"
mkdir -p "backups"

# 2. Permissions adjustments
echo "=> Securing secrets directory"
# Prevent unauthorized access to the secrets files on the host
chmod 700 "${SECRETS_DIR}"

if [ "$(ls -A ${SECRETS_DIR})" ]; then
    chmod 600 ${SECRETS_DIR}/*
    echo "=> Set secure permissions (600) on existing secret files"
else
    echo "=> Warning: The secrets directory is currently empty."
    echo "     Remember to add postgres_password.txt and gitlab_root_password.txt"
fi

# 3. Executable scripts
echo "=> Ensuring scripts are executable"
chmod +x scripts/backup.sh
chmod +x scripts/init.sh

echo "Initialization complete! Your environment is ready."
echo "If you have not done so, generate your SSL certificates and populate your .env file."
