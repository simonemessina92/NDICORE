#!/bin/bash

# === CONFIGURATION ===
CONTAINER_NAME="Ndicore"
IMAGE_NAME="kiloview/ndicore:1.10.0095"
DATA_DIR="/root/cp_data_hardware"

# === REMOVE CONTAINER ===
echo "Checking if container '$CONTAINER_NAME' exists..."
if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
    echo "Container '$CONTAINER_NAME' found. Removing..."
    docker rm -f "$CONTAINER_NAME" || { echo "Error removing container"; exit 1; }
    echo "Container '$CONTAINER_NAME' removed successfully."
else
    echo "Container '$CONTAINER_NAME' not found. No action needed."
fi

# === REMOVE DOCKER IMAGE ===
echo "Checking if Docker image '$IMAGE_NAME' exists..."
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -Eq "^$IMAGE_NAME\$"; then
    echo "Docker image '$IMAGE_NAME' found. Removing..."
    docker rmi "$IMAGE_NAME" || { echo "Error removing Docker image"; exit 1; }
    echo "Docker image '$IMAGE_NAME' removed successfully."
else
    echo "Docker image '$IMAGE_NAME' not found. No action needed."
fi

# === REMOVE DATA DIRECTORY ===
echo "Checking if directory '$DATA_DIR' exists..."
if [ -d "$DATA_DIR" ]; then
    echo "Directory '$DATA_DIR' found. Removing..."
    rm -rf "$DATA_DIR" || { echo "Error removing directory"; exit 1; }
    echo "Directory '$DATA_DIR' removed successfully."
else
    echo "Directory '$DATA_DIR' not found. No action needed."
fi

echo "Cleanup completed successfully! ✅"
