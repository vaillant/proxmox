## Project Overview

This tool creates customized Proxmox VE installation ISO images with automated installation configurations.
See https://pve.proxmox.com/wiki/Automated_Installation for details.

## Usage

```bash
./proxmox-iso-create.sh <number_of_nodes>
```

**Examples:**
- `./proxmox-iso-create.sh 1` - Creates 1 ISO for node proxmox-pc-1
- `./proxmox-iso-create.sh 3` - Creates 3 ISOs for nodes proxmox-pc-1, proxmox-pc-2, proxmox-pc-3

**Optional: Specify a specific Proxmox version:**
```bash
PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso" ./proxmox-iso-create.sh 3
```

By default, the script automatically detects and downloads the latest Proxmox VE version.

## Requirements

* macOS (tested on Apple Silicon)
* Docker Desktop installed and running
* Internet connection (for first run to download ISO and fetch latest version)
* curl or wget (for downloading ISOs and fetching version info)
* Proxmox VE 9.1 (tested)

**Important for Apple Silicon Macs:** The script uses `--platform linux/amd64` to run x86_64 containers via emulation, as Proxmox packages are only available for amd64 architecture.

## Configuration

Edit the top of `proxmox-iso-create.sh` to customize:

```bash
# Optional: Set a specific Proxmox ISO URL
# If not set, the script will automatically fetch the latest version
PROXMOX_ISO_URL="${PROXMOX_ISO_URL:-}"
```

## Answer File Template

The script uses a template with placeholders that are replaced for each node:
- `$N$` - Replaced with node number (1, 2, 3, ...)
- `$PASSWD$` - Replaced with SHA-512 hashed password

**Default template:**
```toml
[global]
keyboard = "en-us"
country = "at"
fqdn = "proxmox-pc-$N$.home"
mailto = "mail@no.invalid"
timezone = "Europe/Vienna"
root-password = "$PASSWD$"

[network]
source = "from-dhcp"

[disk-setup]
filesystem = "zfs"
zfs.raid = "raid0"
# Select one of the following to match your hardware
filter.DEVNAME = "/dev/nvme*"   # SSD
#filter.DEVNAME = "/dev/sd*"     # SCSI/SATA
```

**To customize:** Edit the `DEFAULT_ANSWER_TEMPLATE` variable in the script.

## How It Works

The script performs the following steps:

1. **Validates input** - Checks that number of nodes is a positive integer
2. **Checks Docker** - Ensures Docker Desktop is installed and running
3. **Detects Proxmox version** - If `PROXMOX_ISO_URL` is not set:
   - Fetches directory listing from https://enterprise.proxmox.com/iso/
   - Extracts all ISO filenames matching pattern `proxmox-ve_X.Y-Z.iso`
   - Uses version sort to find the latest version
4. **Downloads ISO** - Downloads Proxmox ISO if not already cached (cached for future runs)
5. **Validates ISO** - Checks file size (>100MB) and file type using `file` command
6. **Prompts for password** - Securely reads root password (hidden input)
7. **Hashes password** - Uses Docker container with `mkpasswd` to generate SHA-512 hash
8. **Generates answer files** - Creates one TOML file per node by replacing `$N$` and `$PASSWD$` placeholders
9. **Runs Docker container** (with amd64 platform for compatibility):
   - Installs `proxmox-auto-install-assistant` from Proxmox repository
   - Validates each answer file with `proxmox-auto-install-assistant validate-answer`
   - Generates customized ISO for each node with `proxmox-auto-install-assistant prepare-iso --fetch-from iso`
10. **Reports success** - Shows generated ISO files with sizes

## Directory Structure

Generated files are placed in the current directory:
```
./iso/                  # Downloaded Proxmox ISO (cached)
  └─ proxmox-ve_9.1-1.iso
./answers/              # Generated answer files (TOML)
  ├─ answer-node1.toml
  ├─ answer-node2.toml
  └─ answer-node3.toml
./output/               # Final bootable ISO images
  ├─ proxmox-answer-node1.iso
  ├─ proxmox-answer-node2.iso
  └─ proxmox-answer-node3.iso
```

## Implementation Details

### Password Hashing
The script uses Docker to run `mkpasswd` (from the `whois` package) to generate SHA-512 password hashes, ensuring compatibility regardless of the host OS.

### ISO Generation
The script uses `--fetch-from iso` mode, which embeds the answer file directly into the ISO. During boot, the Proxmox installer will automatically read the embedded configuration and perform an unattended installation.

### Template Variables
- Using `$N$` and `$PASSWD$` placeholders simplifies hostname/FQDN generation
- The sed replacement uses `|` as delimiter to handle password hashes containing `/` characters
- Dollar signs are escaped as `\\\$` in sed patterns

### Automatic Version Detection
```bash
LATEST_ISO=$(curl -s "$PROXMOX_BASE_URL" | \
    grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | \
    sort -V | \
    tail -1)
```

This extracts all ISO filenames, sorts them by version number, and selects the latest.

## Troubleshooting

**Docker not running:**
```bash
open -a Docker  # Start Docker Desktop on macOS
```

**"invalid reference format" error:**
Ensure Docker Desktop is fully started (check the menu bar icon).

**"bad flag in substitute command" error:**
This has been fixed by using `|` delimiter in sed commands to handle password hash characters.

**Validation errors:**
- Ensure `keyboard` uses full locale code (e.g., `en-us` not `us`)
- Disk setup requires either `disk_list` or `filter` parameter
- Check FQDN format (must be fully qualified: `hostname.domain`)

## Testing

To test with 1 node:
```bash
echo "test123" | ./proxmox-iso-create.sh 1
```

This will generate `./output/proxmox-answer-node1.iso` with password "test123".
