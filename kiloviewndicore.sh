#!/bin/bash

# === CONFIGURATION ===
DOWNLOAD_URL="https://download.kiloview.com/NDICORE/install-kiloview-ndicore-1.10.0095-software-20250311.tar.gz"
TAR_FILE="kiloview_ndicore_1.10.0095.tar.gz"
DOWNLOAD_DIR="/tmp/ndicore"
CONTAINER_NAME="Ndicore"
IMAGE_TAG="kiloview/ndicore:1.10.0095"
IMAGE_TAR_FILE="image-kiloview-ndicore-1.10.0095.tar"
EXTRACTION_DIR="/tmp/ndicore/kiloview-ndicore-1.10.0095-software"

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

# === DOWNLOAD THE TAR FILE ===
echo "Downloading Kiloview NDI Core package..."
curl -L "$DOWNLOAD_URL" -o "$TAR_FILE" || { echo "Download failed"; exit 1; }

# === VERIFY DOWNLOADED FILE ===
if [ ! -f "$TAR_FILE" ]; then
    echo "Downloaded file not found: $TAR_FILE"
    exit 1
fi

# === EXTRACT THE TAR FILE ===
echo "Extracting Kiloview NDI Core package..."
tar -xzf "$TAR_FILE" -C "$DOWNLOAD_DIR" || { echo "Extraction failed"; exit 1; }

# === VERIFY IMAGE TAR FILE LOCATION ===
if [ ! -f "$EXTRACTION_DIR/$IMAGE_TAR_FILE" ]; then
    echo "Docker image tar file not found at $EXTRACTION_DIR/$IMAGE_TAR_FILE. Aborting."
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
echo "Loading Docker image from $EXTRACTION_DIR/$IMAGE_TAR_FILE..."
docker load -i "$EXTRACTION_DIR/$IMAGE_TAR_FILE" || { echo "Docker image load failed"; exit 1; }

# === REMOVE EXISTING CONTAINER (IF EXISTS) ===
if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
    echo "Existing container found. Removing it..."
    docker rm -f "$CONTAINER_NAME"
fi

# === RUN DOCKER CONTAINER ===
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

# === CLEAN UP ===
echo "Cleaning up temporary files..."
rm -rf "$DOWNLOAD_DIR" || { echo "Failed to clean up"; exit 1; }

echo "Installation and setup completed successfully! 🚀"
