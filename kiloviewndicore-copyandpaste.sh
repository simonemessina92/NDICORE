#!/bin/bash

# === CONFIGURATION ===
DOWNLOAD_URL="https://download.kiloview.com/NDICORE/install-kiloview-ndicore-1.10.0095-software-20250311.tar.gz"
TAR_FILE="kiloview_ndicore_1.10.0095.tar.gz"
DOWNLOAD_DIR="/tmp/ndicore"
CONTAINER_NAME="Ndicore"
IMAGE_TAG="kiloview/ndicore:1.10.0095"

# === CREATE TEMP DIRECTORY ===
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR" || exit 1

# === CHECK & INSTALL AVAHI-DAEMON ===
echo "Checking if avahi-daemon is installed..."
if ! dpkg -s avahi-daemon &> /dev/null; then
    echo "avahi-daemon not found. Installing..."
    apt update && apt install -y avahi-daemon || { echo "Failed to install avahi-daemon"; exit 1; }
else
    echo "avahi-daemon is already installed."
fi

# === INSTALL CURL IF NEEDED ===
if ! command -v curl &> /dev/null; then
    echo "curl not found. Installing curl..."
    apt update && apt install -y curl || { echo "curl installation failed"; exit 1; }
fi

# === DOWNLOAD WITH CURL ===
echo "Downloading Docker image from Kiloview site..."
curl -L "$DOWNLOAD_URL" -o "$TAR_FILE" || { echo "Download failed"; exit 1; }

# === VERIFY DOWNLOADED FILE ===
if [ ! -f "$TAR_FILE" ]; then
    echo "Downloaded file not found: $TAR_FILE"
    exit 1
fi

# === EXTRACT TAR.GZ ===
echo "Extracting the tar.gz file..."
tar -xzf "$TAR_FILE" -C "$DOWNLOAD_DIR" || { echo "Extraction failed"; exit 1; }
echo "Extraction completed successfully ✅"

# === FIND THE EXTRACTED IMAGE FILE ===
TAR_IMAGE_FILE=$(find "$DOWNLOAD_DIR" -type f -name "image-*.tar" | head -n 1)

if [ ! -f "$TAR_IMAGE_FILE" ]; then
    echo "No Docker image tar file found after extraction. Aborting."
    exit 1
fi

# === INSTALL DOCKER IF NOT PRESENT ===
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh || { echo "Docker installation failed"; exit 1; }
    systemctl start docker
    systemctl enable docker
fi

# === LOAD DOCKER IMAGE ===
echo "Loading Docker image from $TAR_IMAGE_FILE..."
docker load -i "$TAR_IMAGE_FILE" || { echo "Docker image load failed"; exit 1; }
echo "Docker image loaded successfully ✅"

# === REMOVE EXISTING CONTAINER (IF EXISTS) ===
if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
    echo "Existing container found. Removing it..."
    docker rm -f "$CONTAINER_NAME"
fi

# === RUN CONTAINER ===
echo "Starting the Docker container..."
docker run --name="$CONTAINER_NAME" \
    -idt \
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
    /usr/local/bin/ndicore_start.sh || { echo "Failed to start container"; exit 1; }

echo "Container started successfully! 🚀"

# === CLEAN UP ===
echo "Cleaning up downloaded files..."
rm -rf "$DOWNLOAD_DIR" || { echo "Failed to clean up downloaded files"; exit 1; }
echo "Clean up completed successfully. All temporary files removed! ✅"
