# Proxmox Auto-Installer ISO Creator

Automate the creation of customized Proxmox VE installation ISOs with unattended installation configurations. This tool generates bootable ISO images that automatically install and configure Proxmox VE with predefined settings. 
Script runs on MacOs.

## Features

- 🚀 **Automatic Version Detection** - Fetches the latest Proxmox VE ISO 
- 🔐 **Secure Password Hashing** - Uses SHA-512 for root password encryption in the answer file
- 🖥️ **Multi-Node Support** - Generate multiple ISOs with sequential hostnames in one command
- ✅ **Validation** - Verifies ISO integrity (partially) and answer file configuration before building
- 🍎 **Apple Silicon Compatible** - Works on ARM64 Macs using platform emulation
- 📦 **Zero Dependencies** - Uses Docker for all operations, no local package installation needed
- 🎯 **Template-Based** - Easily customizable answer file templates

## Prerequisites

- **macOS** (tested on Apple Silicon, should work on Intel Macs too)
- **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop)
- **Internet Connection** - For downloading Proxmox ISOs (first run only)
- `curl` or `wget` - Usually pre-installed on macOS

## Quick Start

1. **Ensure Docker Desktop is running:**
   ```bash
   open -a Docker
   ```

2. **Run the script:**
   ```bash
   ./proxmox-iso-create.sh 3
   ```
   This creates 3 ISOs for nodes: `proxmox-pc-1`, `proxmox-pc-2`, `proxmox-pc-3`

3. **Enter root password when prompted**

4. **Wait for generation** (~5 minutes on first run with ISO download)

5. **Find your ISOs in `./output/`:**
   ```
   ./output/proxmox-answer-node1.iso
   ./output/proxmox-answer-node2.iso
   ./output/proxmox-answer-node3.iso
   ```

## Usage

### Basic Usage

Generate ISO images for N nodes:
```bash
./proxmox-iso-create.sh <number_of_nodes>
```

**Examples:**
```bash
# Single node
./proxmox-iso-create.sh 1

# Three nodes (cluster setup)
./proxmox-iso-create.sh 3

# Five nodes
./proxmox-iso-create.sh 5
```

### Using a Specific Proxmox Version

By default, the script downloads the latest Proxmox VE version. To use a specific version:

```bash
PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso" ./proxmox-iso-create.sh 3
```

Or edit the `PROXMOX_ISO_URL` variable at the top of the script.

### Non-Interactive Password (for automation)

```bash
echo "your_password" | ./proxmox-iso-create.sh 3
```

## Configuration

Edit the `DEFAULT_ANSWER_TEMPLATE` section in `proxmox-iso-create.sh` to customize:

```bash
DEFAULT_ANSWER_TEMPLATE=\
'[global]
keyboard = "en-us"           # Keyboard layout
country = "at"               # Country code
fqdn = "proxmox-pc-$N$.home" # Hostname template ($N$ = node number)
mailto = "mail@no.invalid"   # Email for notifications
timezone = "Europe/Vienna"   # Timezone
root-password = "$PASSWD$"   # Password (auto-filled)

[network]
source = "from-dhcp"         # Use DHCP for networking

[disk-setup]
filesystem = "zfs"           # Filesystem type (zfs, ext4, xfs, btrfs)
zfs.raid = "raid0"           # ZFS RAID level
filter.DEVNAME = "/dev/nvme*"  # Disk filter (nvme, sd, etc.)
```

### Common Customizations

**Change hostname pattern:**
```bash
fqdn = "pve-$N$.example.com"  # Results in: pve-1.example.com, pve-2.example.com, ...
```

**Use SCSI/SATA disks instead of NVMe:**
```bash
filter.DEVNAME = "/dev/sd*"
```

**Change timezone:**
```bash
timezone = "America/New_York"
```

**Change keyboard layout:**
```bash
keyboard = "de"  # German
keyboard = "fr"  # French
keyboard = "en-gb"  # UK English
```

## Output

Generated files are organized in the current directory:

```
./iso/                          # Downloaded Proxmox ISO (cached for reuse)
  └─ proxmox-ve_9.1-1.iso
./answers/                      # Generated answer files (TOML)
  ├─ answer-node1.toml
  ├─ answer-node2.toml
  └─ answer-node3.toml
./output/                       # Final bootable ISO images
  ├─ proxmox-answer-node1.iso  # ~1.7GB each
  ├─ proxmox-answer-node2.iso
  └─ proxmox-answer-node3.iso
```

### Using the Generated ISOs

1. **Burn to USB** using tools like [balenaEtcher](https://www.balena.io/etcher/) or `dd`
2. **Boot the target machine** from the USB/ISO
3. **Wait for automatic installation** (no interaction needed)
4. **System will reboot** when complete with Proxmox VE installed

**Default login:**
- Username: `root`
- Password: The password you entered during ISO creation
- Web interface: `https://<node-ip>:8006`

## How It Works

1. **Checks Docker** - Ensures Docker Desktop is running
2. **Detects Latest Version** - Automatically fetches the newest Proxmox VE ISO URL
3. **Downloads ISO** - Downloads and caches the ISO (~1.7GB, only on first run)
4. **Validates ISO** - Checks file integrity and format
5. **Hashes Password** - Securely hashes your password using SHA-512
6. **Generates Configurations** - Creates answer files for each node
7. **Validates Configurations** - Uses Proxmox tools to verify answer files
8. **Builds ISOs** - Embeds configurations into bootable ISO images
9. **Reports Success** - Shows generated ISOs with sizes

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

## Advanced Usage

### Custom Disk Configuration

For multiple disks or specific disk selection:

```toml
[disk-setup]
filesystem = "zfs"
zfs.raid = "raidz"  # RAID-Z (similar to RAID-5)
disk_list = ["/dev/sda", "/dev/sdb", "/dev/sdc"]  # Specific disks
```

### Static IP Configuration

Instead of DHCP:

```toml
[network]
source = "from-dhcp"
address = "192.168.1.100/24"
gateway = "192.168.1.1"
dns = "8.8.8.8"
```

### Different Filesystem Types

```toml
[disk-setup]
filesystem = "ext4"  # Options: zfs, ext4, xfs, btrfs
```

## Technical Details

- **Docker Platform:** Uses `--platform linux/amd64` for ARM64 compatibility
- **Password Hashing:** SHA-512 via `mkpasswd` from whois package
- **ISO Embedding:** Uses `proxmox-auto-install-assistant prepare-iso --fetch-from iso`
- **Validation:** Runs `proxmox-auto-install-assistant validate-answer` before building
- **Version Detection:** Parses HTML directory listing with grep and version sort

## Contributing

Issues and pull requests are welcome! Please test any changes on both Intel and Apple Silicon Macs if possible.

## License

See [LICENSE](../LICENSE) file in the repository root.

## References

- [Proxmox VE Automated Installation Documentation](https://pve.proxmox.com/wiki/Automated_Installation)
- [Proxmox VE Downloads](https://www.proxmox.com/en/downloads)
- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)

## Credits

This tool automates the Proxmox VE automated installation feature introduced in Proxmox VE 8.1+. It wraps the official `proxmox-auto-install-assistant` tool with convenience features for multi-node deployments.

---

**Note:** This tool generates ISOs with embedded credentials. Keep the generated ISOs secure and delete them after use if they contain production passwords.
