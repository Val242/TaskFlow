#!/bin/bash
#=============================================================
#  TaskFlow Application Server Setup Script
#-------------------------------------------------------------
#  Installs and configures:
#   1. Basic System Setup
#   2. Node.js LTS
#   3. Node Exporter
#   4. PostgreSQL
#   5. TaskFlow NestJS Application
#   6. TaskFlow systemd Service
#   7. Load Generation Scripts
#   8. UFW Firewall
#   9. Final Summary
#
#  Author: Ebong Valentine
#  Version: 3.0
#  Tested on: Ubuntu 22.04 LTS
#=============================================================

set -e

#-------------------------------------------------------------
# 1. Basic System Setup
#-------------------------------------------------------------
echo "===== [1/9] Setting up basic system configuration ====="

echo "Setting hostname to web01..."

echo "web01" > /etc/hostname
hostname web01

echo "Updating and upgrading system packages..."

apt update -y
apt upgrade -y

echo "Installing essential utilities..."

apt install -y \
    curl \
    wget \
    git \
    zip \
    unzip \
    ca-certificates \
    gnupg \
    stress \
    stress-ng

echo "Basic system setup completed."


#-------------------------------------------------------------
# 2. Install Node.js LTS
#-------------------------------------------------------------
echo "===== [2/9] Installing Node.js LTS ====="

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

apt install -y nodejs

echo "Node.js version:"
node --version

echo "NPM version:"
npm --version

echo "Node.js installation completed."


#-------------------------------------------------------------
# 3. Install and Configure Node Exporter
#-------------------------------------------------------------
echo "===== [3/9] Installing Prometheus Node Exporter ====="

NODE_EXPORTER_VERSION="1.10.2"

mkdir -p /tmp/node-exporter
cd /tmp/node-exporter

echo "Downloading Node Exporter v${NODE_EXPORTER_VERSION}..."

wget -q \
    "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

echo "Extracting Node Exporter..."

tar xzf \
    "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

echo "Installing Node Exporter..."

mkdir -p /var/lib/node

mv \
    "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" \
    /var/lib/node/node_exporter

echo "Creating prometheus system user..."

groupadd --system prometheus 2>/dev/null || true

useradd \
    --system \
    --no-create-home \
    --shell /usr/sbin/nologin \
    --gid prometheus \
    prometheus 2>/dev/null || true

chown -R prometheus:prometheus /var/lib/node

chmod 755 /var/lib/node
chmod 755 /var/lib/node/node_exporter

echo "Creating Node Exporter systemd service..."

cat <<EOF > /etc/systemd/system/node-exporter.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus

ExecStart=/var/lib/node/node_exporter

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node-exporter

echo "Checking Node Exporter status..."

systemctl status node-exporter --no-pager

echo "Node Exporter setup completed."


#-------------------------------------------------------------
# 4. Install PostgreSQL
#-------------------------------------------------------------
echo "===== [4/9] Installing PostgreSQL ====="

apt install -y postgresql postgresql-contrib

systemctl enable --now postgresql

echo "Checking PostgreSQL status..."

systemctl status postgresql --no-pager

echo "PostgreSQL setup completed."


#-------------------------------------------------------------
# 5. Setup TaskFlow NestJS Application
#-------------------------------------------------------------
echo "===== [5/9] Setting up TaskFlow NestJS application ====="

mkdir -p /tmp/project

cd /tmp/project

rm -rf TaskFlow

echo "Cloning TaskFlow repository..."

git clone --no-checkout https://github.com/Val242/TaskFlow.git

cd TaskFlow

echo "Checking out taskflow-api only..."

git sparse-checkout init --cone
git sparse-checkout set taskflow-api
git checkout

echo "Repository checkout completed."


#-------------------------------------------------------------
# Move application to /opt
#-------------------------------------------------------------
echo "Installing TaskFlow application..."

rm -rf /opt/taskflow-api

mkdir -p /opt/taskflow-api

cp -r taskflow-api/. /opt/taskflow-api/

cd /opt/taskflow-api


#-------------------------------------------------------------
# Create TaskFlow system user
#-------------------------------------------------------------
echo "Creating taskflow system user..."

groupadd --system taskflow 2>/dev/null || true

useradd \
    --system \
    --no-create-home \
    --shell /usr/sbin/nologin \
    --gid taskflow \
    taskflow 2>/dev/null || true


#-------------------------------------------------------------
# Install Node dependencies
#-------------------------------------------------------------
echo "Installing Node.js dependencies..."

npm ci


#-------------------------------------------------------------
# Generate Prisma Client
#-------------------------------------------------------------
echo "Generating Prisma Client..."

npx prisma generate


#-------------------------------------------------------------
# Build NestJS application
#-------------------------------------------------------------
echo "Building TaskFlow application..."

npm run build


#-------------------------------------------------------------
# Create application environment file
#-------------------------------------------------------------
echo "Creating TaskFlow environment file..."

touch /opt/taskflow-api/.env

chown taskflow:taskflow /opt/taskflow-api/.env

chmod 600 /opt/taskflow-api/.env


#-------------------------------------------------------------
# Application permissions
#-------------------------------------------------------------
echo "Setting application permissions..."

chown -R taskflow:taskflow /opt/taskflow-api

chmod -R 755 /opt/taskflow-api

chmod 600 /opt/taskflow-api/.env


#-------------------------------------------------------------
# TaskFlow systemd service
#-------------------------------------------------------------
echo "Creating TaskFlow systemd service..."

cat <<EOF > /etc/systemd/system/taskflow-api.service
[Unit]
Description=TaskFlow NestJS API
Wants=network-online.target
After=network-online.target postgresql.service

[Service]
Type=simple

User=taskflow
Group=taskflow

WorkingDirectory=/opt/taskflow-api

EnvironmentFile=/opt/taskflow-api/.env
Environment=NODE_ENV=production

ExecStart=/usr/bin/node /opt/taskflow-api/dist/src/main.js

Restart=always
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF


#-------------------------------------------------------------
# Reload systemd
#-------------------------------------------------------------
echo "Reloading systemd..."

systemctl daemon-reload


#-------------------------------------------------------------
# Prisma Database Migration
#-------------------------------------------------------------
echo "Running Prisma migrations..."

if [ -n "${DATABASE_URL:-}" ]; then
    sudo -u taskflow \
        env DATABASE_URL="$DATABASE_URL" \
        npx prisma migrate deploy
else
    echo "DATABASE_URL is not currently set."
    echo "Skipping Prisma migration."
    echo "Configure /opt/taskflow-api/.env before running migrations."
fi


#-------------------------------------------------------------
# Start TaskFlow
#-------------------------------------------------------------
echo "Enabling TaskFlow service..."

systemctl enable taskflow-api

echo "Starting TaskFlow service..."

systemctl start taskflow-api

echo "Checking TaskFlow service..."

systemctl status taskflow-api --no-pager

echo "TaskFlow application setup completed."


#-------------------------------------------------------------
# 6. Verify Application
#-------------------------------------------------------------
echo "===== [6/9] Verifying TaskFlow application ====="

echo "Waiting for TaskFlow to start..."

sleep 5

if curl -f http://localhost:3000/health/live; then
    echo ""
    echo "TaskFlow liveness check passed."
else
    echo ""
    echo "WARNING: TaskFlow liveness check failed."
    echo "Check logs with:"
    echo "journalctl -u taskflow-api -n 100 --no-pager"
fi

echo ""
echo "Checking application metrics endpoint..."

if curl -f http://localhost:3000/metrics > /dev/null; then
    echo "TaskFlow metrics endpoint is available."
else
    echo "WARNING: /metrics endpoint is not available."
fi


#-------------------------------------------------------------
# 7. Load Generation Scripts
#-------------------------------------------------------------
echo "===== [7/9] Setting up load generation scripts ====="

echo "Downloading load scripts..."

wget -q \
    -P /usr/local/bin/ \
    https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/load.sh

wget -q \
    -P /usr/local/bin/ \
    https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/generate_multi_logs.sh

chmod +x \
    /usr/local/bin/load.sh \
    /usr/local/bin/generate_multi_logs.sh

echo "Load generation scripts installed."


#-------------------------------------------------------------
# 8. Configure UFW Firewall
#-------------------------------------------------------------
echo "===== [8/9] Configuring UFW Firewall ====="

apt install -y ufw

echo "Configuring firewall rules..."

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 9100/tcp

echo "Enabling UFW..."

echo "y" | ufw enable

echo "Firewall status:"

ufw status verbose

echo "UFW firewall configured."


#-------------------------------------------------------------
# 9. Final Summary
#-------------------------------------------------------------
echo ""
echo "============================================================="
echo "       TaskFlow Application Server Setup Complete"
echo "============================================================="

echo ""

echo "Node.js:"
node --version

echo ""

echo "NPM:"
npm --version

echo ""

echo "Services:"

echo -n "Node Exporter : "
systemctl is-active node-exporter

echo -n "PostgreSQL    : "
systemctl is-active postgresql

echo -n "TaskFlow API  : "
systemctl is-active taskflow-api

echo ""

echo "Application:"
echo "  Internal: http://<APPLICATION_PRIVATE_IP>:3000"

echo ""

echo "Health:"
echo "  Liveness: http://<APPLICATION_PRIVATE_IP>:3000/health/live"
echo "  Readiness: http://<APPLICATION_PRIVATE_IP>:3000/health/ready"

echo ""

echo "Metrics:"
echo "  Application: http://<APPLICATION_PRIVATE_IP>:3000/metrics"
echo "  System:      http://<APPLICATION_PRIVATE_IP>:9100/metrics"

echo ""

echo "PostgreSQL:"
echo "  Internal only: localhost:5432"

echo ""

echo "Monitoring:"
echo "  Prometheus should scrape:"
echo "    - APPLICATION_PRIVATE_IP:3000/metrics"
echo "    - APPLICATION_PRIVATE_IP:9100/metrics"

echo ""

echo "TaskFlow installation:"
echo "  /opt/taskflow-api"

echo ""

echo "Useful commands:"
echo "  systemctl status taskflow-api"
echo "  journalctl -u taskflow-api -f"
echo "  systemctl status node-exporter"
echo "  journalctl -u node-exporter -f"

echo ""

echo "============================================================="
echo "              Setup completed successfully!"
echo "============================================================="