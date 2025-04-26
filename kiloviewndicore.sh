#!/bin/sh

# === CONFIGURATION ===
DOWNLOAD_URL="https://download.kiloview.com/NDICORE/install-kiloview-ndicore-1.10.0095-software-20250311.tar.gz"
DOWNLOAD_DIR="/tmp/ndicore"
TAR_FILE="$DOWNLOAD_DIR/kiloview_ndicore_1.10.0095.tar.gz"
EXTRACTION_DIR="$DOWNLOAD_DIR/kiloview-ndicore-1.10.0095-software"
IMAGE_TAR_FILE="image-kiloview-ndicore-1.10.0095.tar"
CONTAINER_NAME="Ndicore"
IMAGE_TAG="kiloview/ndicore:1.10.0095"

# --- Helpers for checks ---
is_installed_pkg() {
  dpkg -s "$1" > /dev/null 2>&1
}

cmd_exists() {
  command -v "$1" > /dev/null 2>&1
}

# --- 1) Dependencies install only if missing ---

echo "Checking avahi-daemon..."
if ! is_installed_pkg avahi-daemon; then
  echo " avahi-daemon not installed. Installing..."
  apt-get update -qq && apt-get install -y avahi-daemon
else
  echo " avahi-daemon already installed."
fi

echo "Checking curl..."
if ! cmd_exists curl; then
  echo " curl not installed. Installing..."
  apt-get update -qq && apt-get install -y curl
else
  echo " curl already installed."
fi

echo "Checking Docker..."
if ! cmd_exists docker; then
  echo " Docker not installed. Installing..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
else
  echo " Docker already installed."
fi

# --- 2) Download & extract image archive ---

echo "Preparing download directory..."
mkdir -p "$DOWNLOAD_DIR"

echo "Downloading NDI Core package..."
curl -fSL "$DOWNLOAD_URL" -o "$TAR_FILE"

if [ ! -s "$TAR_FILE" ]; then
  echo "ERROR: Download failed or file is empty."
  exit 1
fi

echo "Extracting package to $DOWNLOAD_DIR..."
tar -xzf "$TAR_FILE" -C "$DOWNLOAD_DIR" || {
  echo "ERROR: Extraction failed."
  exit 1
}

# --- 3) Load Docker image ---

IMAGE_PATH="$EXTRACTION_DIR/$IMAGE_TAR_FILE"
if [ ! -f "$IMAGE_PATH" ]; then
  echo "ERROR: Docker image archive not found at $IMAGE_PATH"
  exit 1
fi

echo "Loading Docker image from $IMAGE_PATH..."
docker load -i "$IMAGE_PATH" || {
  echo "ERROR: docker load failed."
  exit 1
}

# --- 4) Remove old container if exists ---

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "Removing existing container $CONTAINER_NAME..."
  docker rm -f "$CONTAINER_NAME"
fi

# --- 5) Run new container ---

echo "Starting container $CONTAINER_NAME..."
docker run -d \
  --name="$CONTAINER_NAME" \
  --network host \
  --privileged=true \
  --restart=always \
  -v /etc/localtime:/etc/localtime:ro \
  -v /var/run/avahi-daemon:/var/run/avahi-daemon \
  -v /var/run/dbus:/var/run/dbus \
  -v /opt/package:/opt/package \
  -v /upgrade:/upgrade \
  -v /root/cp_data_hardware:/app/data/ndicore \
  "$IMAGE_TAG" \
  /usr/local/bin/ndicore_start.sh || {
    echo "ERROR: Failed to start container."
    exit 1
  }

# --- 6) Clean up ---

echo "Cleaning up..."
rm -rf "$DOWNLOAD_DIR"

echo "Done! ✅"
