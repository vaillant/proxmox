# Proxmox Auto-Installer ISO Creator

Automate the creation of Proxmox VE installation ISOs for a multi-node cluster. This script generates bootable ISO images that automatically install and configure Proxmox VE with predefined settings from an embedded answer file. 
Script runs on MacOs and uses [proxmox-auto-install-assistant](https://pve.proxmox.com/wiki/Automated_Installation).
It wraps the official `proxmox-auto-install-assistant` tool with convenience features for multi-node deployments.

## Features

- 🚀 **Automatic Version Detection** - Fetches the latest Proxmox VE ISO 
- 🔐 **Secure Password Hashing** - Uses SHA-512 for root password encryption in the answer file
- 🖥️ **Multi-Node Support** - Generate multiple ISOs with sequential hostnames in one command
- ✅ **Validation** - Verifies ISO integrity (partially) and answer file configuration before building
- 🍎 **Apple Silicon Compatible** - Works on ARM64 Macs using platform emulation
- 📦 **Zero Dependencies** - Uses Docker for all operations, no local package installation needed
- 🎯 **Template-Based** - Customizable answer file templates

## Prerequisites

- **macOS** (tested on Apple Silicon, should work on Intel Macs too)
- **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop)
- **Internet Connection** - For downloading Proxmox ISOs (first run only)
- `curl` or `wget` - Usually pre-installed on macOS


## A Quick Start

1. **Ensure Docker Desktop is running:**
   ```bash
   open -a Docker
   ```

2. **Get the Script**

   Change to your working directory and execute
   ```bash
   curl -O https://raw.githubusercontent.com/vaillant/proxmox/main/proxmox-iso-create/proxmox-iso-create.sh
   chmod +x proxmox-iso-create.sh
   ```

3. **Run the script:**
   ```bash
   ./proxmox-iso-create.sh 3
   ```
   * Enter root password when prompted
   * Wait for generation, ~5 minutes on first run with ISO download

   * Find your ISOs in `./output/`:
   ```
   ./output/proxmox-pc-1-pve-9.1-1.iso
   ./output/proxmox-pc-2-pve-9.1-1.iso
   ./output/proxmox-pc-3-pve-9.1-1.iso
   ```

4. **Copy to USB**
   Follow instructions printed by the script. Also see [Proxmox documentation on Installation Media](https://pve.proxmox.com/pve-docs/chapter-pve-installation.html#installation_prepare_media). 

5. **Boot from USB:**
   * Insert USB drive into target machine
   * Boot from USB:
      - Enter BIOS/UEFI (usually F2, F12, DEL, or ESC during boot)
      - Select the USB drive as boot device
      - Save and exit
   * Automatic installation begins:
      - The installer reads the answer file 
      - Progress is shown on screen
      - Installation takes ~5-10 minutes
   * System reboots automatically when complete
   * Remove USB drive after first reboot

6. **Access Proxmox**
   * Find the IP address:
      - Check your DHCP server/router for the new device
      - Or use: `arp -a | grep -i proxmox` from another machine on the network

   * Login to web interface:
      - URL: `https://<node-ip>:8006`
      - Username: `root`
      - Password: The password you entered during ISO creation

   * First login notes:
      - Browser will show security warning (self-signed certificate) - this is normal
      - You may see a subscription notice - can be dismissed for home/test use

7. **Proxmox configuration**
   * Create the cluster, if you have more than one node.
   * Install https://github.com/community-scripts/ProxmoxVE and execute [PVE post Install](https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install) to update repos.

## Usage

### Basic Usage

Generate ISO images for N nodes:
```bash
./proxmox-iso-create.sh <number_of_nodes>
```

### Using a Specific Proxmox Version

By default, the script downloads the latest Proxmox VE version. To use a specific version:

```bash
PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso" ./proxmox-iso-create.sh 3
```

## Answer file generation

The script embeds an Proxmox answer file template. This is in TOML format, documented [here](https://pve.proxmox.com/wiki/Automated_Installation#Answer_File_Format_2). In many cases you need to make changes to reflect keyboard, DNS domain, netwokring or disk setup in your location. 

The defaults in the script assume: 
* DHCP (Note: make the IP static in your DHCP server, e.g. in Ubiquiti Unifi.)
* Single NVME disk
* Use ZFS with RAID0, i.e. no redundancy.

To customize the answer file, edit the `DEFAULT_ANSWER_TEMPLATE` section in `proxmox-iso-create.sh`:

```bash
DEFAULT_ANSWER_TEMPLATE=\
'[global]
keyboard = "en-us"                  # Keyboard layout
country = "at"                      # Country code
fqdn = "proxmox-pc-$N$.home"        # Hostname template ($N$ = node number)
mailto = "mail@no.invalid"          # Email for notifications
timezone = "Europe/Vienna"          # Timezone
root-password-hashed = "$PASSWD$"   # Password (auto-filled)

[network]
source = "from-dhcp"         # Use DHCP for networking

[disk-setup]
filesystem = "zfs"           # Filesystem type (zfs, ext4, xfs, btrfs)
zfs.raid = "raid0"           # ZFS RAID level
filter.DEVNAME = "/dev/nvme*"  # Disk filter (nvme, sd, etc.)
```

### Common Customizations

**Change hostname pattern:**
```toml
fqdn = "pve-$N$.example.com"  # Results in: pve-1.example.com, pve-2.example.com, ...
```

**Use SCSI/SATA disks instead of NVMe:**
```toml
filter.DEVNAME = "/dev/sd*"
```

**Change timezone:**
```toml
timezone = "America/New_York"
```

**Change keyboard layout:**
```toml
keyboard = "de"  # German
keyboard = "fr"  # French
keyboard = "en-gb"  # UK English
```

**Custom Disk Configuration:**
E.g. for multiple SATA disks:
```toml
[disk-setup]
filesystem = "zfs"
zfs.raid = "raidz"  # RAID-Z (similar to RAID-5)
disk_list = ["/dev/sda", "/dev/sdb", "/dev/sdc"]  # Specific disks
```

**Change to static IP Configuration**
```toml
[network]
source = "from-dhcp"
address = "192.168.1.100/24"
gateway = "192.168.1.1"
dns = "8.8.8.8"
```

## Output

Generated files are organized in the current directory:

```
./iso/                          # Downloaded Proxmox ISO (cached for reuse)
  └─ proxmox-ve_9.1-1.iso
./answers/                      # Generated answer files (TOML)
  ├─ proxmox-pc-1.toml
  ├─ proxmox-pc-2.toml
  └─ proxmox-pc-3.toml
./output/                       # Final bootable ISO images
  ├─ proxmox-pc-1-pve-9.1-1.iso  # ~1.7GB each
  ├─ proxmox-pc-2-pve-9.1-1.iso
  └─ proxmox-pc-3-pve-9.1-1.iso
```

## Troubleshooting

### Docker Not Running

**Error:** `Docker is not running`

**Solution:**
```bash
open -a Docker
# Wait for Docker Desktop to fully start, then retry
```

### ISO Download Issues

**Error:** `Failed to download Proxmox ISO`

**Solution:**
- Check your internet connection
- Verify the URL is accessible: `curl -I https://enterprise.proxmox.com/iso/`
- Try specifying a different mirror or version manually

### Validation Errors

**Error:** `Validation failed for answer file`

**Solutions:**
- Ensure keyboard layout uses full locale (e.g., `en-us` not `us`)
- Verify FQDN format includes domain (e.g., `hostname.domain`)
- Check disk filter matches your hardware (`/dev/nvme*` for NVMe, `/dev/sd*` for SATA)

### Slow Performance on Apple Silicon

The script uses x86_64 emulation which is slower than native. This is normal and required because Proxmox packages are only available for amd64 architecture. ISO generation may take 5-10 minutes.

## Contributing

Issues and pull requests are welcome! Please test any changes on both Intel and Apple Silicon Macs if possible.

## License

See [LICENSE](../LICENSE) file in the repository root.

## References

- [Proxmox VE Automated Installation Documentation](https://pve.proxmox.com/wiki/Automated_Installation)
- [Proxmox VE Downloads](https://www.proxmox.com/en/downloads)
- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)

## Credits

This tool automates the Proxmox VE automated installation feature introduced in Proxmox VE 8.1+. 

---

**Note:** This tool generates ISOs with embedded credentials. Keep the generated ISOs secure and delete them after use if they contain production passwords.
