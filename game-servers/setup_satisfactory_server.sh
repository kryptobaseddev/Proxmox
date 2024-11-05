#!/bin/bash

# Script to install QEMU Guest Agent, SteamCMD, and Satisfactory Dedicated Server on Debian

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to display headers
function header() {
  echo -e "\n${PURPLE}========== $1 ==========${NC}\n"
}

# Function to display info messages
function info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to display success messages
function success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display error messages
function error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a package is installed and install it if not
function check_and_install() {
  if ! dpkg -l | grep -qw "$1"; then
    info "Installing $1..."
    apt-get install -y "$1" > /dev/null
    success "$1 installed."
  else
    info "$1 is already installed."
  fi
}

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  error "Please run this script as root or with sudo."
  exit 1
fi

# Update and upgrade the system
header "System Update"
info "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
success "System packages updated."

# Ensure prerequisites are installed
header "Installing Prerequisites"
info "Checking and installing prerequisites..."

# List of prerequisites
PREREQS=("wget" "curl" "software-properties-common" "ca-certificates" "apt-transport-https" "gnupg" "sudo" "net-tools")

for pkg in "${PREREQS[@]}"; do
  check_and_install "$pkg"
done

# Add i386 architecture for 32-bit support
header "Configuring Architecture"
info "Adding i386 architecture support..."
dpkg --add-architecture i386
success "i386 architecture support added."

# Enable 'non-free' and 'non-free-firmware' repositories using the workaround
header "Configuring Repositories"
info "Enabling 'non-free' and 'non-free-firmware' repositories using workaround..."

# Use add-apt-repository workaround to add non-free components
info "Adding 'non-free' and 'non-free-firmware' components to repositories..."

# Run add-apt-repository with the necessary options
add-apt-repository -y -n -U http://deb.debian.org/debian -c non-free -c non-free-firmware

# Due to a bug, we need to run the command twice
add-apt-repository -y -n -U http://deb.debian.org/debian -c non-free -c non-free-firmware

# Update package lists
apt-get update -qq
success "Repositories updated."

# Install QEMU Guest Agent
header "Installing QEMU Guest Agent"
check_and_install "qemu-guest-agent"
systemctl enable qemu-guest-agent > /dev/null
systemctl start qemu-guest-agent
success "QEMU Guest Agent installed and running."

# Install dependencies for SteamCMD
header "Installing Dependencies for SteamCMD"
DEPENDENCIES=("lib32gcc-s1" "lib32stdc++6" "libc6-i386" "libcurl4-gnutls-dev:i386")

for dep in "${DEPENDENCIES[@]}"; do
  check_and_install "$dep"
done
success "Dependencies installed."

# Install SteamCMD
header "Installing SteamCMD"
check_and_install "steamcmd"
success "SteamCMD installed."

# Create a steam user (if not already existing)
header "Creating Steam User"
if id "steam" &>/dev/null; then
  info "User 'steam' already exists."
else
  info "Creating 'steam' user..."
  useradd -m steam
  # Prompt to set a password for 'steam' user
  info "Please set a password for the 'steam' user."
  passwd steam
  usermod -aG sudo steam
  success "User 'steam' created and added to sudoers."
fi

# Create directory for Satisfactory server
header "Setting Up Satisfactory Server Directory"
info "Creating directory for Satisfactory Dedicated Server..."
mkdir -p /home/steam/SatisfactoryDedicatedServer
chown steam:steam /home/steam/SatisfactoryDedicatedServer
success "Server directory created."

# Install Satisfactory Dedicated Server using SteamCMD
header "Installing Satisfactory Dedicated Server"
info "Installing Satisfactory Dedicated Server. This may take a while..."
sudo -u steam bash -c "steamcmd +login anonymous +force_install_dir /home/steam/SatisfactoryDedicatedServer +app_update 1690800 validate +quit" > /dev/null
success "Satisfactory Dedicated Server installed."

# Create systemd service for Satisfactory server
header "Configuring Systemd Service"
info "Creating systemd service file..."
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
success "Systemd service file created."

# Reload systemd daemon and enable the service
info "Enabling and starting the Satisfactory server service..."
systemctl daemon-reload
systemctl enable satisfactory.service > /dev/null
systemctl start satisfactory.service
success "Satisfactory server service started."

# Fetch the server's IP address
header "Retrieving Server Information"
IP_ADDRESS=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDRESS" ]; then
  error "Unable to retrieve IP address."
  IP_ADDRESS="Unavailable"
else
  success "Server IP address: $IP_ADDRESS"
fi

# Define default ports
GAME_PORT=15777
BEACON_PORT=15000
QUERY_PORT=7777

# Display final server information
echo -e "\n${CYAN}================= Satisfactory Server Information =================${NC}\n"
echo -e "${YELLOW}Server IP Address:${NC} ${GREEN}$IP_ADDRESS${NC}"
echo -e "${YELLOW}Game Port:${NC} ${GREEN}$GAME_PORT/UDP${NC}"
echo -e "${YELLOW}Beacon Port:${NC} ${GREEN}$BEACON_PORT/UDP${NC}"
echo -e "${YELLOW}Query Port:${NC} ${GREEN}$QUERY_PORT/UDP${NC}"
echo -e "\n${CYAN}===================================================================${NC}\n"

header "Installation Complete"
success "Satisfactory Dedicated Server setup is complete!"
