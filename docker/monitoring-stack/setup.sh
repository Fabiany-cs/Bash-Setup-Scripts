#!/bin/bash

set -e

echo "================================================"
echo "  Monitoring Stack Setup - Raspberry Pi"
echo "================================================"

# Check docker is running
if ! docker info > /dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit 1
fi

DOCKER_DIR="$HOME/Docker"

echo ""
echo "[1/4] Creating directory structure..."
mkdir -p "$DOCKER_DIR/prometheus"
mkdir -p "$DOCKER_DIR/grafana/provisioning/datasources"

echo "[2/4] Copying config files..."
cp docker-compose.yml "$DOCKER_DIR/docker-compose.yml"
cp prometheus/prometheus.yml "$DOCKER_DIR/prometheus/prometheus.yml"
cp grafana/provisioning/datasources/prometheus.yml "$DOCKER_DIR/grafana/provisioning/datasources/prometheus.yml"

echo "[3/4] Removing old containers and networks (if any)..."
cd "$DOCKER_DIR"

# Bring down any old stacks in subdirectories
for dir in grafana prometheus uptime-kuma node-exporter; do
  if [ -f "$DOCKER_DIR/$dir/docker-compose.yml" ]; then
    echo "  -> Stopping old stack in $dir/"
    docker compose -f "$DOCKER_DIR/$dir/docker-compose.yml" down 2>/dev/null || true
  fi
done

# Prune unused networks to clean up old bridge interfaces
docker network prune -f

echo "[4/4] Starting monitoring stack..."
cd "$DOCKER_DIR"
docker compose pull
docker compose up -d

echo ""
echo "================================================"
echo "  All containers started!"
echo ""
echo "  Grafana:       http://$(hostname -I | awk '{print $1}'):3000"
echo "    User:        admin"
echo "    Password:    admin  (change after first login)"
echo ""
echo "  Prometheus:    http://$(hostname -I | awk '{print $1}'):9090"
echo "  Node Exporter: http://$(hostname -I | awk '{print $1}'):9100"
echo "  Uptime Kuma:   http://$(hostname -I | awk '{print $1}'):3001"
echo "================================================"
echo ""
echo "Run 'docker compose logs -f' in ~/Docker to watch logs."
