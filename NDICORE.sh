#!/bin/bash

# === Kiloview NDI CORE Enhanced Installer ===
echo -e "\n\033[1;44m     🚀 Kiloview NDI CORE Installer Starting...     \033[0m\n"
sleep 1

# === Configuration ===
CONTAINER_NAME="Ndicore"
IMAGE_REPO="kiloview/ndicore"
DATA_DIR="/root/cp_data_hardware"
DOWNLOAD_URL="https://download.kiloview.com/NDICORE/install-kiloview-ndicore-1.10.0095-software-20250311.tar.gz"
DOWNLOAD_DIR="/tmp/ndicore"
TAR_FILE="$DOWNLOAD_DIR/kiloview_ndicore_1.10.0095.tar.gz"
EXTRACTION_DIR="$DOWNLOAD_DIR/kiloview-ndicore-1.10.0095-software"
IMAGE_TAR="image-kiloview-ndicore-1.10.0095.tar"
IMAGE_TAG="$IMAGE_REPO:1.10.0095"

echo -e "\033[1;36m\nSelect an option:\033[0m"
echo -e "  1) Install Kiloview NDI CORE"
echo -e "  2) Uninstall any version of Kiloview NDI CORE\n"
read -rp "Enter choice [1-2]: " CHOICE

if [[ "$CHOICE" == "1" ]]; then
    echo -e "\n\033[1;36m=== Checking dependencies ===\033[0m"
    missing=""
    command -v avahi-daemon >/dev/null 2>&1 || missing="$missing avahi-daemon"
    command -v curl >/dev/null 2>&1 || missing="$missing curl"
    if [ -n "$missing" ]; then
        echo "Installing: $missing"
        apt-get update -qq
        apt-get install -y $missing
    else
        echo "All dependencies satisfied."
    fi

    echo -e "\n\033[1;36m=== Checking Docker ===\033[0m"
    if ! command -v docker >/dev/null || ! docker version >/dev/null 2>&1; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker >/dev/null
        systemctl start docker
    else
        echo "Docker is already installed."
    fi

    echo -e "\n\033[1;36m=== Downloading Kiloview NDI CORE ===\033[0m"
    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"
    echo -n "Downloading"
    for i in {1..5}; do echo -n "."; sleep 0.3; done
    curl -fSL "$DOWNLOAD_URL" -o "$TAR_FILE" || { echo "Download failed"; exit 1; }
    echo -e " \033[1;32mDone\033[0m"

    echo -e "\033[1;36mExtracting archive...\033[0m"
    tar -xzf "$TAR_FILE" -C "$DOWNLOAD_DIR" || { echo "Extraction failed"; exit 1; }

    IMAGE_PATH="$EXTRACTION_DIR/$IMAGE_TAR"
    if [ ! -f "$IMAGE_PATH" ]; then echo "Image not found"; exit 1; fi

    echo -e "\033[1;36mLoading Docker image...\033[0m"
    docker load -i "$IMAGE_PATH" || { echo "Docker load failed"; exit 1; }

    echo -e "\033[1;36mCleaning previous container (if any)...\033[0m"
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1

    echo -e "\033[1;36mStarting container...\033[0m"
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
      /usr/local/bin/ndicore_start.sh || { echo "Failed to start container"; exit 1; }

    echo -e "\033[1;32m\n✅ Installation complete.\033[0m"

echo -e "\n\033[1;44m 🎉 Installation Complete! \033[0m\n"
IP=$(hostname -I | awk '{print $1}')
echo -e "\033[1;37mYour Kiloview NDI CORE is now running.\033[0m"
echo -e "\033[1;36mAccess the Web UI at: http://$IP\033[0m"
echo -e "\033[1;33mDefault credentials: \033[1;37madmin / admin\033[0m"
echo -e "\033[1;37mAt first login, you will be required to set a new password.\033[0m"
echo
echo -e "\033[1;32m✔️  Start routing NDI streams like never before!\033[0m"
echo -e "\033[1;34m🔗  For firmware updates, visit:\033[0m https://www.kiloview.com/en/support/download/"
echo -e "\033[1;34m📤  You can upload the latest .bin file directly from the Web UI.\033[0m"
echo
echo -e "\033[1;35mThank you for choosing Kiloview – Your AVoIP Trailblazer!\033[0m"

elif [[ "$CHOICE" == "2" ]]; then
    echo -e "\n\033[1;36m=== Uninstalling Kiloview NDI CORE ===\033[0m"
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 && echo "Container removed."
    docker rmi -f $(docker images "$IMAGE_REPO" -q) 2>/dev/null && echo "Image(s) removed."
    rm -rf "$DATA_DIR" && echo "Data directory removed."
    echo -e "\033[1;32m\n✅ Cleanup complete.\033[0m"
else
    echo -e "\033[1;31mInvalid choice. Exiting.\033[0m"
    exit 1
fi
