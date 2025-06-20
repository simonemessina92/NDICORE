#!/bin/bash

# ===================================================
#  NDI CORE installation script by Simone Messina
#  Kiloview Your AVoIP Trailblazer! 
# ===================================================

CONTAINER_NAME="Ndicore"
IMAGE_REPO="kiloview/ndicore"
DATA_DIR="/root/cp_data_hardware"
DOWNLOAD_URL="https://download.kiloview.com/NDICORE/install-kiloview-ndicore-1.10.0095-software-20250311.tar.gz"
DOWNLOAD_DIR="/tmp/ndicore"
TAR_FILE="$DOWNLOAD_DIR/kiloview_ndicore_1.10.0095.tar.gz"
EXTRACTION_DIR="$DOWNLOAD_DIR/kiloview-ndicore-1.10.0095-software"
IMAGE_TAR="image-kiloview-ndicore-1.10.0095.tar"
IMAGE_TAG="$IMAGE_REPO:1.10.0095"

echo
echo "Select an option:"
echo "1) Install Kiloview NDI CORE"
echo "2) Uninstall any version of Kiloview NDI CORE"
read -rp "Enter choice [1-2]: " CHOICE

if [[ "$CHOICE" == "1" ]]; then
    echo "=== Checking dependencies ==="
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

    echo "=== Checking Docker installation ==="
    if command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1; then
      echo "Docker is already installed and working."
    else
      echo "Docker not found. Installing..."
      curl -fsSL https://get.docker.com | sh
      systemctl enable docker >/dev/null 2>&1
      systemctl start docker
    fi

    echo "=== Preparing download directory ==="
    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    echo "Downloading NDI CORE package..."
    curl -fSL "$DOWNLOAD_URL" -o "$TAR_FILE" || { echo "ERROR: Download failed"; exit 1; }

    echo "Extracting archive..."
    tar -xzf "$TAR_FILE" -C "$DOWNLOAD_DIR" || { echo "ERROR: Extraction failed"; exit 1; }

    IMAGE_PATH="$EXTRACTION_DIR/$IMAGE_TAR"
    if [ ! -f "$IMAGE_PATH" ]; then
      echo "ERROR: Docker image not found at $IMAGE_PATH"
      exit 1
    fi

    echo "Loading Docker image..."
    docker load -i "$IMAGE_PATH" || { echo "ERROR: Docker load failed"; exit 1; }

    echo "Removing any existing container named $CONTAINER_NAME..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1

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
      -v "$DATA_DIR":/app/data/ndicore \
      "$IMAGE_TAG" \
      /usr/local/bin/ndicore_start.sh || { echo "ERROR: Failed to start container"; exit 1; }

    echo "Cleaning up temporary files..."
    rm -rf "$DOWNLOAD_DIR"

    echo "✅ Installation complete."

elif [[ "$CHOICE" == "2" ]]; then
    echo "=== Stopping and removing any existing containers named '$CONTAINER_NAME' ==="
    if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
        docker rm -f "$CONTAINER_NAME" || { echo "Error removing container"; exit 1; }
        echo "Container '$CONTAINER_NAME' removed."
    else
        echo "No container named '$CONTAINER_NAME' found."
    fi

    echo "=== Removing all Docker images related to '$IMAGE_REPO' ==="
    IMAGE_IDS=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep "^$IMAGE_REPO" | awk '{print $2}')
    for id in $IMAGE_IDS; do
        docker rmi -f "$id" || echo "Warning: Could not remove image ID $id"
    done

    echo "=== Removing data directory $DATA_DIR ==="
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR" || { echo "Error removing directory"; exit 1; }
        echo "Data directory removed."
    else
        echo "No data directory found."
    fi

    echo "✅ Cleanup completed successfully."

else
    echo "Invalid selection. Exiting."
    exit 1
fi
