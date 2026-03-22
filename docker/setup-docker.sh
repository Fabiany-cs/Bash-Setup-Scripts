#!/bin/bash
# =============================================================
# setup-docker.sh
# Installs Docker Engine and Docker Compose on:
#   Raspberry Pi 5 — Debian Trixie (or any Debian-based Pi OS)
#
# Installs from Docker's official APT repository — not the
# outdated docker.io package from Debian's repos.
#
# What gets installed:
#   - docker-ce              (Docker Engine)
#   - docker-ce-cli          (Docker CLI)
#   - containerd.io          (container runtime)
#   - docker-buildx-plugin   (buildx for multi-arch builds)
#   - docker-compose-plugin  (docker compose v2)
#
# Also creates a 'docker-compose' alias so both
# 'docker compose' and 'docker-compose' work.
#
# Usage: sudo bash setup-docker.sh
# =============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()    { echo -e "\n${CYAN}==>${NC} $1"; }

# ── root check ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    print_error "Run with sudo: sudo bash setup-docker.sh"
    exit 1
fi

# ── detect the real user (the one who called sudo) ────────────
DOCKER_USER="${SUDO_USER:-pi}"

# ── header ────────────────────────────────────────────────────
clear
echo ""
echo "========================================"
echo "   Docker Setup — Raspberry Pi / Debian"
echo "========================================"
echo -e "  ${YELLOW}Tip: Press Ctrl+C at any time to quit${NC}"
echo "========================================"
echo ""
echo "  This script will install:"
echo "    - Docker Engine (latest stable)"
echo "    - Docker Compose v2"
echo "    - docker-compose alias (v1 compatibility)"
echo ""
echo "  User '${DOCKER_USER}' will be added to the"
echo "  docker group (no sudo needed for docker commands)."
echo ""
read -r -p "Press Enter to begin, or Ctrl+C to cancel: "
echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 1 — SYSTEM UPDATE
# ═══════════════════════════════════════════════════════════════
print_step "Step 1 of 5 — Updating system packages"
apt update && apt upgrade -y
print_info "System up to date."

# ═══════════════════════════════════════════════════════════════
# STEP 2 — REMOVE OLD CONFLICTING PACKAGES
# ═══════════════════════════════════════════════════════════════
print_step "Step 2 of 5 — Removing any conflicting old packages"

# These are the old/unofficial Docker packages that conflict
# with the official Docker CE packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    if dpkg -l | grep -q "^ii.*${pkg}"; then
        apt remove -y "$pkg"
        print_info "Removed: $pkg"
    fi
done
print_info "No conflicts remaining."

# ═══════════════════════════════════════════════════════════════
# STEP 3 — ADD DOCKER'S OFFICIAL APT REPOSITORY
# ═══════════════════════════════════════════════════════════════
print_step "Step 3 of 5 — Adding Docker's official APT repository"

# Install prerequisites for adding the repo
apt install -y ca-certificates curl
print_info "Prerequisites installed."

# Create the keyring directory
install -m 0755 -d /etc/apt/keyrings

# Download Docker's official GPG key
# This verifies that packages we install actually come from Docker
curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
print_info "Docker GPG key added."

# Add Docker's APT repository
# VERSION_CODENAME is read from /etc/os-release — on Trixie this is "trixie"
# This means we always get the right repo for whatever Debian version is running
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
print_info "Docker APT repository added."

# ═══════════════════════════════════════════════════════════════
# STEP 4 — INSTALL DOCKER
# ═══════════════════════════════════════════════════════════════
print_step "Step 4 of 5 — Installing Docker Engine and Compose"

apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

print_info "Docker installed."

# Enable and start Docker service
systemctl enable docker
systemctl start docker
print_info "Docker service enabled and started."

# ═══════════════════════════════════════════════════════════════
# STEP 5 — POST-INSTALL CONFIGURATION
# ═══════════════════════════════════════════════════════════════
print_step "Step 5 of 5 — Configuring Docker for user '${DOCKER_USER}'"

# Add user to the docker group so they can run docker without sudo
# Note: group change takes effect on next login / reboot
usermod -aG docker "${DOCKER_USER}"
print_info "Added '${DOCKER_USER}' to the docker group."

# Create a docker-compose alias so both 'docker compose' (v2)
# and 'docker-compose' (old v1 style) work interchangeably
# Many homelab compose files still use the hyphenated command
if [ ! -f /usr/local/bin/docker-compose ]; then
    cat > /usr/local/bin/docker-compose << 'EOF'
#!/bin/sh
docker compose --compatibility "$@"
EOF
    chmod +x /usr/local/bin/docker-compose
    print_info "docker-compose alias created (/usr/local/bin/docker-compose)"
else
    print_warning "docker-compose already exists — leaving it unchanged."
fi

# ── verify the installation ───────────────────────────────────
echo ""
print_info "Verifying Docker installation..."
DOCKER_VERSION=$(docker --version)
COMPOSE_VERSION=$(docker compose version)
print_info "Installed: ${DOCKER_VERSION}"
print_info "Installed: ${COMPOSE_VERSION}"

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
echo ""
echo "========================================"
echo -e "  ${GREEN}Docker setup complete!${NC}"
echo "========================================"
echo ""
echo "  Docker is running and starts on boot."
echo ""
echo "  User '${DOCKER_USER}' has been added to the"
echo "  docker group. You will need to log out"
echo "  and back in (or reboot) before running"
echo "  docker without sudo."
echo ""
echo "  Both commands work:"
echo -e "    ${CYAN}docker compose up -d${NC}"
echo -e "    ${CYAN}docker-compose up -d${NC}"
echo ""
echo "  Useful commands:"
echo -e "    ${CYAN}docker ps${NC}               — list running containers"
echo -e "    ${CYAN}docker images${NC}            — list downloaded images"
echo -e "    ${CYAN}docker system prune${NC}      — clean up unused resources"
echo -e "    ${CYAN}sudo systemctl status docker${NC} — check Docker service"
echo ""

read -r -p "Reboot now to apply group changes? (yes/no): " ANS
if [[ "$ANS" =~ ^[Yy] ]]; then
    print_info "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    reboot
else
    print_warning "Reboot skipped. Run 'sudo reboot' or log out and back in."
    print_warning "Until then, use 'sudo docker' for docker commands."
fi
