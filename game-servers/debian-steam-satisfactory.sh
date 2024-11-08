#!/usr/bin/env bash

# Copyright (c) 2021-2024 kryptobaseddev
# Author: kryptobaseddev
# License: MIT
# https://github.com/kryptobaseddev/Proxmox/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"

░██████╗░█████╗░████████╗██╗░██████╗███████╗░█████╗░░█████╗░████████╗░█████╗░██████╗░██╗░░░██╗
██╔════╝██╔══██╗╚══██╔══╝██║██╔════╝██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗╚██╗░██╔╝
╚█████╗░███████║░░░██║░░░██║╚█████╗░█████╗░░███████║██║░░╚═╝░░░██║░░░██║░░██║██████╔╝░╚████╔╝░
░╚═══██╗██╔══██║░░░██║░░░██║░╚═══██╗██╔══╝░░██╔══██║██║░░██╗░░░██║░░░██║░░██║██╔══██╗░░╚██╔╝░░
██████╔╝██║░░██║░░░██║░░░██║██████╔╝██║░░░░░██║░░██║╚█████╔╝░░░██║░░░╚█████╔╝██║░░██║░░░██║░░░
╚═════╝░╚═╝░░╚═╝░░░╚═╝░░░╚═╝╚═════╝░╚═╝░░░░░╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░
                Satisfactory Game Server
                Running on Debian 12

EOF
}
header_info
echo -e "\n Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --backtitle "Proxmox VE Helper Scripts" --title "Debian 12 VM" --yesno "This will create a New Debian 12 VM. Proceed?" 10 58; then
  :
else
  header_info && echo -e "⚠ User exited script \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/[6-8]\.[0-9]"; then
    msg_error "This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires Proxmox Virtual Environment Version 6.0 or later."
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    msg_error "This script will not work with PiMox! \n"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

function default_settings() {
  VMID="$NEXTID"
  FORMAT=""
  MACHINE=""
  DISK_CACHE=""
  HN="satisfactory-server"
  CPU_TYPE="host"
  CORE_COUNT="8"
  RAM_SIZE="32768"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  echo -e "${DGN}Using Virtual Machine ID: ${BGN}${VMID}${CL}"
  echo -e "${DGN}Using Machine Type: ${BGN}i440fx${CL}"
  echo -e "${DGN}Using Disk Cache: ${BGN}None${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}${HN}${CL}"
  echo -e "${DGN}Using CPU Model: ${BGN}${CPU_TYPE}${CL}"
  echo -e "${DGN}Allocated Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${DGN}Allocated RAM: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DGN}Using Bridge: ${BGN}${BRG}${CL}"
  echo -e "${DGN}Using MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${DGN}Using VLAN: ${BGN}Default${CL}"
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
  echo -e "${BL}Creating a Debian 12 VM using the above default settings${CL}"
}


function advanced_settings() {
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if MACH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "MACHINE TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 10 58 2 \
    "i440fx" "Machine i440fx" ON \
    "q35" "Machine q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ $MACH = q35 ]; then
      echo -e "${DGN}Using Machine Type: ${BGN}$MACH${CL}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${DGN}Using Machine Type: ${BGN}$MACH${CL}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit-script
  fi

  if DISK_CACHE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DISK CACHE" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "None (Default)" ON \
    "1" "Write Through" OFF \
    3>&1 1>&2 2>&3); then
    if [ $DISK_CACHE = "1" ]; then
      echo -e "${DGN}Using Disk Cache: ${BGN}Write Through${CL}"
      DISK_CACHE="cache=writethrough"
    else
      echo -e "${DGN}Using Disk Cache: ${BGN}None${CL}"
      DISK_CACHE=""
    fi
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 satisfactory-server --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="satisfactory-server"
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi

  if CPU_TYPE1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CPU MODEL" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "KVM64" OFF \
    "1" "Host (Recommended)" ON \
    3>&1 1>&2 2>&3); then
    if [ $CPU_TYPE1 = "1" ]; then
      echo -e "${DGN}Using CPU Model: ${BGN}Host${CL}"
      CPU_TYPE="host"
    else
      echo -e "${DGN}Using CPU Model: ${BGN}KVM64${CL}"
      CPU_TYPE="kvm64"
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 8 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="8"
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 32768 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="32768"
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Vlan (leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
    echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
    START_VM="yes"
  else
    echo -e "${DGN}Start VM when completed: ${BGN}no${CL}"
    START_VM="no"
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create a Debian 12 VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a Debian 12 VM using the above advanced settings${CL}"
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

check_root
arch_check
pve_check
ssh_check
start_script

# Prompt for root password with verification
while true; do
  echo -e "${YW}Please enter the root password:${CL}"
  read -s ROOT_PASSWORD
  echo
  echo -e "${YW}Please verify root password:${CL}"
  read -s ROOT_PASSWORD_VERIFY
  echo
  if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_VERIFY" ]; then
    break
  else
    echo -e "${RD}Passwords do not match. Please try again.${CL}"
  fi
done

# Prompt for steam user password with verification
while true; do
  echo -e "${YW}Please enter the steam user password:${CL}"
  read -s STEAM_PASSWORD
  echo
  echo -e "${YW}Please verify steam user password:${CL}"
  read -s STEAM_PASSWORD_VERIFY
  echo
  if [ "$STEAM_PASSWORD" = "$STEAM_PASSWORD_VERIFY" ]; then
    break
  else
    echo -e "${RD}Passwords do not match. Please try again.${CL}"
  fi
done

# Hash the passwords
ROOT_PASSWORD_HASH=$(echo "${ROOT_PASSWORD}" | openssl passwd -6 -stdin)
STEAM_PASSWORD_HASH=$(echo "${STEAM_PASSWORD}" | openssl passwd -6 -stdin)

# Storage Validation and Selection
msg_info "Validating Storage"

# Build a menu of storage options that support 'images'
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "Unable to detect a valid storage location."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool would you like to use for ${HN}?\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."

msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Retrieving the URL for the Debian 12 Qcow2 Disk Image"
URL=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Downloaded ${CL}${BL}${FILE}${CL}"

# Determine storage type and adjust settings accordingly
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')

# Create VM
msg_info "Creating a Debian 12 VM"
qm create $VMID -agent 1 -localtime 1 -bios seabios -cpu $CPU_TYPE -cores $CORE_COUNT -memory $RAM_SIZE \
  -name $HN -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 \
  -ide2 ${STORAGE}:cloudinit
msg_ok "VM $VMID created"

# Import the disk image
msg_info "Importing the disk image to storage"
qm importdisk $VMID ${FILE} $STORAGE
msg_ok "Disk image imported to storage"

# Get the imported disk reference
IMPORTED_DISK_REF=$(qm config $VMID | grep '^unused' | cut -d ' ' -f2)

# Attach the imported disk
msg_info "Attaching imported disk to VM"
qm set $VMID --scsi0 $IMPORTED_DISK_REF,${DISK_CACHE}${THIN}size=50G
msg_ok "Imported disk attached to VM"

# Set the boot order
qm set $VMID --boot order=scsi0
msg_ok "Boot order set to scsi0"

qm set $VMID -serial0 socket \
  -description "<div align='center'>

  # Satisfactory Game Server
  ## Debian 12 VM (SteamCMD)

<script type='text/javascript' src='https://storage.ko-fi.com/cdn/widget/Widget_2.js'></script><script type='text/javascript'>kofiwidget2.init('Support me on Ko-fi', '#0d7d07', 'H2H815OTBU');kofiwidget2.draw();</script> 
  </div>" >/dev/null

# Cloud-Init Configuration

mkdir -p /var/lib/vz/snippets

cat <<EOF > /var/lib/vz/snippets/user-data-$VMID.yaml
#cloud-config
users:
  - name: steam
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
    groups: sudo
    lock_passwd: false
    passwd: ${STEAM_PASSWORD_HASH}

chpasswd:
  list: |
    root:${ROOT_PASSWORD_HASH}
  expire: False
  encrypted: True

ssh_pwauth: True

disable_root: False

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - steamcmd
  - lib32gcc-s1

runcmd:
  - |
    systemctl enable qemu-guest-agent
    systemctl start qemu-guest-agent

    echo "Adding non-free repository"
    sed -i '/^deb .* main$/ s/$/ non-free/' /etc/apt/sources.list
    dpkg --add-architecture i386
    apt-get update

    echo "Creating Satisfactory server directory"
    mkdir -p /home/steam/SatisfactoryDedicatedServer
    chown steam:steam /home/steam/SatisfactoryDedicatedServer

    echo "Installing Satisfactory Dedicated Server"
    sudo -u steam steamcmd +force_install_dir /home/steam/SatisfactoryDedicatedServer +login anonymous +app_update 1690800 validate +quit

    echo "Creating systemd service"
    cat <<EOL > /etc/systemd/system/satisfactory.service
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
EOL

    systemctl daemon-reload
    systemctl enable satisfactory.service
    systemctl start satisfactory.service
EOF

qm set $VMID --cicustom "user=local:snippets/user-data-$VMID.yaml"

msg_ok "Created a Debian 12 VM ${CL}${BL}(${HN}) with SteamCMD and Satisfactory Dedicated Server"
echo -e "\nVM Configuration:"
echo -e "- Hostname: ${HN}"
echo -e "- CPU: ${CPU_TYPE} with ${CORE_COUNT} cores" 
echo -e "- RAM: $((RAM_SIZE/1024))GB"
echo -e "- Steam user created with sudo access"
echo -e "- SteamCMD installed with i386 architecture support"
echo -e "- Satisfactory Dedicated Server installed in /home/steam/SatisfactoryDedicatedServer"
echo -e "- Systemd service 'satisfactory.service' configured for auto-start"
echo -e "- Default ports: 15777/UDP (Game), 15000/UDP (Beacon), 7777/UDP (Query)\n"
 
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Debian 12 VM with Satisfactory Server"
  qm start $VMID
  msg_ok "Started Debian 12 VM - Satisfactory server will initialize automatically"
  echo -e "Please allow a few minutes for first-time setup and server start"
fi
msg_ok "Satisfactory Server VM Setup Completed Successfully!\n"

# Wait a few seconds for services to start
sleep 10

# Get IP address
IP_ADDRESS=$(qm guest exec $VMID -- ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

# Check if satisfactory service is running
if qm guest exec $VMID -- systemctl is-active --quiet satisfactory.service; then
  echo -e "\n${GN}✓${CL} Satisfactory server is running"
  echo -e "Server IP Address: ${BL}${IP_ADDRESS}${CL}"
  echo -e "Connect using: ${IP_ADDRESS}:15777"
else
  echo -e "\n${RD}✗${CL} Satisfactory server is not running. Check logs with:"
  echo -e "qm guest exec $VMID -- journalctl -u satisfactory.service"
fi
