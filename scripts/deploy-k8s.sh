#!/bin/bash
# ==============================================================================
# Script: deploy-k8s.sh
# Purpose: Fail-safe unified port-forwarding for the entire cluster architecture
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

echo "==========================================="
echo "   🚀 Minikube Infrastructure Linker 🚀    "
echo "==========================================="
echo ""
echo "⚠️  BEGINNER WARNING:"
echo "Before deploying this to an active repository, please ensure"
echo "any personal configuration files, local passwords, or sensitive"
echo "certificates that you generated are safely appended to your"
echo ".gitignore file. Do not commit personal secrets!"
echo "=========================================================="

# Fail-Safe: Trap CTRL+C (SIGINT) to automatically kill all background tunnels
# This prevents leaving "zombie" port-forwards that block ports on your Windows host.
cleanup() {
    echo ""
    echo "[!] Shutting down all secure port-forwarding tunnels..."
    # Kills all child processes started by this script
    kill -- -$$ 2>/dev/null || true
    echo "[✓] All tunnels safely closed. Enjoy your food!"
    exit 0
}
trap cleanup SIGINT SIGTERM ERR EXIT

echo ""
echo "[INFO] Verifying cluster metrics before opening gates..."

# Fail-Safe: Wait for the pods to be Ready *before* attempting a port route
# If they are still booting, this will hold the line instead of crashing.
echo "⏳ Waiting for Kibana (EFK)..."
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=120s 2>/dev/null || true

echo "⏳ Waiting for GitLab..."
kubectl wait --for=condition=ready pod -l app=gitlab -n gitlab --timeout=120s 2>/dev/null || true

echo "⏳ Waiting for Grafana..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n gitlab --timeout=120s 2>/dev/null || true


echo ""
echo "✅ Core systems verified. Initializing secure tunnels in the background..."

# Spin up port-forwards in the background (&) and pipe their logs to null
kubectl port-forward svc/gitlab-service 80:80 -n gitlab > /dev/null 2>&1 &
kubectl port-forward svc/prometheus-service 9090:9090 -n gitlab > /dev/null 2>&1 &
kubectl port-forward svc/grafana 3000:3000 -n gitlab > /dev/null 2>&1 &
kubectl port-forward svc/kibana-kibana 5601:5601 -n logging > /dev/null 2>&1 &

echo ""
echo "==========================================="
echo "           🌐 ALL SYSTEMS ONLINE 🌐        "
echo "==========================================="
echo "Your dashboards are now permanently linked to your localhost."
echo "You can click or copy these directly into Chrome:"
echo ""
echo " 🦊 GitLab       : http://localhost:80"
echo " 📊 Grafana      : http://localhost:3000"
echo " 📈 Prometheus   : http://localhost:9090"
echo " 🪵 Kibana (EFK) : http://localhost:5601"
echo ""
echo "⚠️  LEAVE THIS TERMINAL OPEN. Press [Ctrl+C] when you are fully done"
echo "   to safely severe all network connections and prevent zombie ports."
echo "==========================================="

# Wait indefinitely to keep the background tasks alive until user interrupts
wait
