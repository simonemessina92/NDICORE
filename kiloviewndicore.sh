#!/bin/bash

# Function to check if a package is installed
check_installed() {
    if ! dpkg -l | grep -q "$1"; then
        return 1
    else
        return 0
    fi
}

# Check if avahi-daemon is installed
echo "Checking if avahi-daemon is installed..."
if ! check_installed avahi-daemon; then
    echo "avahi-daemon not found. Installing..."
    sudo apt-get install -y avahi-daemon
else
    echo "avahi-daemon is already installed."
fi

# Check if curl is installed
echo "Checking if curl is installed..."
if ! command -v curl &> /dev/null; then
    echo "curl not found. Installing..."
    sudo apt-get install -y curl
else
    echo "curl is already installed."
fi

# Check if Docker is installed
echo "Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing..."
    # Docker install commands
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker is already installed."
fi

# Download Kiloview NDI Core package
echo "Downloading Kiloview NDI Core package..."
curl -L -o /tmp/kiloview-ndicore.tar.gz https://download.kiloview.com/ndicore/kiloview-ndicore-1.10.0095-software.tar.gz

# Extract Kiloview NDI Core package
echo "Extracting Kiloview NDI Core package..."
tar -xvzf /tmp/kiloview-ndicore.tar.gz -C /tmp

# Load Docker image
echo "Loading Docker image..."
docker load < /tmp/ndicore/kiloview-ndicore-1.10.0095-software/image-kiloview-ndicore-1.10.0095.tar

# Create Docker container
echo "Creating Docker container..."
docker run -d \
  --name kiloview-ndicore \
  --restart=always \
  -p 8090:8090 \
  -p 8350:8350 \
  -v /tmp/ndicore/config:/app/config \
  -v /tmp/ndicore/logs:/app/logs \
  kiloview/ndicore:1.10.0095

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf /tmp/kiloview-ndicore.tar.gz /tmp/ndicore

echo "Installation and setup completed successfully! 🚀"
