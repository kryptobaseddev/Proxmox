# Proxmox Satisfactory Game Server Setup Script

This script automates the creation of a Debian 12 virtual machine on a Proxmox server, installs SteamCMD, and sets up a Satisfactory Dedicated Server. The script is designed to be run from the Proxmox console.

## Prerequisites

- A Proxmox server running version 8.1 or later.
- Access to the Proxmox shell (recommended over SSH for this script).
- Sufficient resources on your Proxmox server to allocate to the VM (e.g., 32GB RAM, 8 CPU cores).

## Installation and Usage

1. **Run the Script Directly from GitHub:**
   - Execute the following command from the Proxmox console to run the script directly from your GitHub repository:
   ```bash
   bash -c "$(wget -qO- https://raw.githubusercontent.com/kryptobaseddev/Proxmox/main/game-servers/debian-steam-satisfactory.sh)"
   ```

2. **Script Execution:**
   - The script will prompt you to choose between default and advanced settings.
   - If you choose advanced settings, you will be prompted to input various configuration options such as VM ID, machine type, disk cache, hostname, CPU model, core count, RAM size, bridge, MAC address, VLAN, and MTU size.
   - The script will create a user `steam` for the Satisfactory server installation. This user does not require a password as it is configured with `NOPASSWD` sudo access.

3. **Root User Password:**
   - The script does not set a password for the root user. You should set a root password manually after the VM is created by accessing the VM console.

4. **VM Creation:**
   - The script will download the Debian 12 Qcow2 disk image and create a VM with the specified settings.
   - It will configure the VM to automatically start the Satisfactory server using a systemd service.

5. **Post-Installation:**
   - Once the VM is created and started, the script will display the IP address of the server.
   - You can connect to the Satisfactory server using the displayed IP address and port `15777`.

## Key Information

- **User Creation:** The script creates a `steam` user with sudo access for managing the Satisfactory server.
- **Service Configuration:** A systemd service `satisfactory.service` is created to manage the Satisfactory server.
- **Ports:** The default ports used by the Satisfactory server are 15777/UDP (Game), 15000/UDP (Beacon), and 7777/UDP (Query).
- **Error Handling:** The script includes error handling to clean up resources if an error occurs during execution.

## Troubleshooting

- If the Satisfactory server does not start, check the logs using:
  ```bash
  qm guest exec <VMID> -- journalctl -u satisfactory.service
  ```
- Ensure that your Proxmox server has internet access to download necessary packages and the Debian image.

## License

This script is licensed under the MIT License. See the [LICENSE](https://github.com/kryptobaseddev/Proxmox/raw/main/LICENSE) file for more details.

---

By following these instructions, you should be able to successfully set up a Satisfactory Dedicated Server on your Proxmox environment.
