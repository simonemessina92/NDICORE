#!/bin/sh

# === CONFIGURATION ===
DOWNLOAD_URL="https://download.kiloview.com/NDICORE/install-kiloview-ndicore-1.10.0095-software-20250311.tar.gz"
DOWNLOAD_DIR="/tmp/ndicore"
TAR_FILE="$DOWNLOAD_DIR/kiloview_ndicore_1.10.0095.tar.gz"
EXTRACTION_DIR="$DOWNLOAD_DIR/kiloview-ndicore-1.10.0095-software"
IMAGE_TAR="image-kiloview-ndicore-1.10.0095.tar"
CONTAINER_NAME="Ndicore"
IMAGE_TAG="kiloview/ndicore:1.10.0095"

# --- 1) Install missing Debian packages (avahi-daemon, curl) in one go ---
missing=""
command -v avahi-daemon >/dev/null 2>&1 || missing="$missing avahi-daemon"
command -v curl         >/dev/null 2>&1 || missing="$missing curl"

if [ -n "$missing" ]; then
  echo "Installing missing packages:$missing"
  apt-get update -qq
  apt-get install -y $missing
else
  echo "All required Debian packages already installed."
fi

# --- 2) Install Docker if missing ---
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker >/dev/null 2>&1
  systemctl start  docker
else
  echo "Docker already installed."
fi

# --- 3) Download & extract the NDI Core archive ---
echo "Preparing download directory..."
rm -rf "$DOWNLOAD_DIR" && mkdir -p "$DOWNLOAD_DIR"

echo "Downloading NDI Core package..."
curl -fSL "$DOWNLOAD_URL" -o "$TAR_FILE" || {
  echo "ERROR: download failed"; exit 1
}

echo "Extracting archive..."
tar -xzf "$TAR_FILE" -C "$DOWNLOAD_DIR" || {
  echo "ERROR: extraction failed"; exit 1
}

# --- 4) Load the Docker image from the extracted .tar ---
IMAGE_PATH="$EXTRACTION_DIR/$IMAGE_TAR"
if [ ! -f "$IMAGE_PATH" ]; then
  echo "ERROR: image tar not found at $IMAGE_PATH"; exit 1
fi

echo "Loading Docker image..."
docker load -i "$IMAGE_PATH" || { echo "ERROR: docker load failed"; exit 1; }

# --- 5) Remove any existing container ---
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "Removing existing container $CONTAINER_NAME..."
  docker rm -f "$CONTAINER_NAME"
fi

# --- 6) Run the new container with volumes & host networking ---
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
  /usr/local/bin/ndicore_start.sh || { echo "ERROR: failed to start container"; exit 1; }

# --- 7) Cleanup ---
echo "Cleaning up temporary files..."
rm -rf "$DOWNLOAD_DIR"

echo "Installation and setup completed successfully! 🚀"
