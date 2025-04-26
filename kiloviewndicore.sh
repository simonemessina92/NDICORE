#!/bin/sh

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_ok() { echo "${GREEN}✅ $1${NC}"; }
print_warn() { echo "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo "${RED}❌ $1${NC}"; }

# --- Check if run as root ---
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root!"
    exit 1
fi

# --- Install avahi-daemon if missing ---
if ! dpkg -s avahi-daemon >/dev/null 2>&1; then
    print_warn "avahi-daemon not found. Installing..."
    apt update && apt install -y avahi-daemon
    print_ok "avahi-daemon installed."
else
    print_ok "avahi-daemon already installed."
fi

# --- Install curl if missing ---
if ! command -v curl >/dev/null 2>&1; then
    print_warn "curl not found. Installing..."
    apt update && apt install -y curl
    print_ok "curl installed."
else
    print_ok "curl already installed."
fi

# --- Install Docker if missing ---
if ! command -v docker >/dev/null 2>&1; then
    print_warn "Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    print_ok "Docker installed."
else
    print_ok "Docker already installed."
fi

# --- Download the Kiloview NDI Core Docker Image ---
TMP_DIR="/tmp/ndicore"
IMAGE_URL="https://www.kiloview.com/download/kiloview-ndicore-1.10.0095-software.tar.gz"

mkdir -p "$TMP_DIR"
print_ok "Downloading Kiloview NDI Core..."
curl -L "$IMAGE_URL" -o "$TMP_DIR/ndicore.tar.gz"

# --- Extract the tar.gz ---
print_ok "Extracting Kiloview NDI Core package..."
tar -xzf "$TMP_DIR/ndicore.tar.gz" -C "$TMP_DIR"

# --- Load Docker image ---
print_ok "Loading Docker image into local registry..."
docker load -i "$TMP_DIR"/kiloview-ndicore-*/image-*.tar

# --- Run the container ---
print_ok "Starting Kiloview NDI Core container..."
docker run -d --name kiloview-ndicore --restart unless-stopped -p 80:80 kiloview/ndicore:1.10.0095

# --- Clean up ---
print_ok "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

print_ok "Installation and setup completed successfully! 🚀"
