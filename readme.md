# Automatic DNS provisioning in Proxmox

This repository contains scripts and configurations to automate DNS provisioning in a Proxmox environment. The goal is to streamline the process of setting up and managing DNS records for virtual machines (VMs) and containers (LXD) hosted on Proxmox.

## How to

1. **Clone the Repository**: Start by cloning this repository to your Proxmox server.
2. **Set Up Environment**: Ensure you have the necessary envionment variables and dependencies installed.
3. **Run 00-provision-lxc.sh**: This script provisions LXC containers with the required DNS configurations.
4. **Add records**: Use the provided scripts to add DNS records for your VMs and containers.

## Adding DNS Records
To add DNS records, you can use the `add-zone.sh` script. Here’s an example of how to add an A record:

```bash
pct exec <container_id> -- add-zone example.com 192.168.1.232 --reverse 192.168.1.0/24
```
