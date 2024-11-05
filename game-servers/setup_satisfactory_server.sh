#!/bin/bash

# Script to install QEMU Guest Agent, SteamCMD, and Satisfactory Dedicated Server on Debian

set -e

# Function to display messages
function msg() {
  echo -e "\e[32m$1\e[0m"
}

# Function to check if a package is installed and install it if not
function check_and_install() {
  if ! dpkg -l | grep -qw "$1"; then
    msg "Installing $1..."
    sudo apt-get install -y "$1"
  else
    msg "$1 is already installed."
  fi
}

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  msg "Please run this script as root or with sudo."
  exit 1
fi

# Update and upgrade the system
msg "Updating system packages..."
apt-get update
apt-get upgrade -y

# Ensure prerequisites are installed
msg "Checking and installing prerequisites..."

# List of prerequisites
PREREQS=("wget" "curl" "software-properties-common" "ca-certificates" "apt-transport-https" "gnupg" "sudo")

for pkg in "${PREREQS[@]}"; do
  check_and_install "$pkg"
done

# Install QEMU Guest Agent
msg "Installing QEMU Guest Agent..."
check_and_install "qemu-guest-agent"
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Add i386 architecture for 32-bit support
msg "Adding i386 architecture support..."
dpkg --add-architecture i386
apt-get update

# Install dependencies for SteamCMD
msg "Installing dependencies for SteamCMD..."
DEPENDENCIES=("lib32gcc-s1" "lib32stdc++6" "libc6-i386" "libcurl4-gnutls-dev:i386")

for dep in "${DEPENDENCIES[@]}"; do
  check_and_install "$dep"
done

# Install SteamCMD
msg "Installing SteamCMD..."
check_and_install "steamcmd"

# Create a steam user (if not already existing)
if id "steam" &>/dev/null; then
    msg "User 'steam' already exists."
else
    msg "Creating 'steam' user..."
    useradd -m steam
    # Prompt to set a password for 'steam' user
    msg "Please set a password for the 'steam' user."
    passwd steam
    usermod -aG sudo steam
fi

# Create directory for Satisfactory server
msg "Creating directory for Satisfactory Dedicated Server..."
mkdir -p /home/steam/SatisfactoryDedicatedServer
chown steam:steam /home/steam/SatisfactoryDedicatedServer

# Install Satisfactory Dedicated Server using SteamCMD
msg "Installing Satisfactory Dedicated Server..."
sudo -u steam bash -c "steamcmd +login anonymous +force_install_dir /home/steam/SatisfactoryDedicatedServer +app_update 1690800 validate +quit"

# Create systemd service for Satisfactory server
msg "Creating systemd service for Satisfactory Dedicated Server..."
bash -c 'cat > /etc/systemd/system/satisfactory.service <<EOF
[Unit]
Description=Satisfactory Dedicated Server
After=network.target

[Service]
Type=simple
User=steam
WorkingDirectory=/home/steam/SatisfactoryDedicatedServer
ExecStart=/home/steam/SatisfactoryDedicatedServer/FactoryServer.sh -unattended
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd daemon and enable the service
msg "Enabling and starting the Satisfactory server service..."
systemctl daemon-reload
systemctl enable satisfactory.service
systemctl start satisfactory.service

msg "Satisfactory Dedicated Server setup is complete!"
