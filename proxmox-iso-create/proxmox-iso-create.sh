#!/usr/bin/env bash
set -euo pipefail

# proxmox-iso-create - Generate Proxmox Auto-Installer ISO images
# Usage: proxmox-iso-create.sh <number_of_nodes>

# ============================================================================
# Configuration
# ============================================================================

# Optional: Set a specific Proxmox ISO URL
# If not set, the script will automatically fetch the latest version
# Example: PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso"
PROXMOX_ISO_URL="${PROXMOX_ISO_URL:-}"

# ============================================================================

#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="."
ISO_DIR="${WORK_DIR}/iso"
ANSWER_DIR="${WORK_DIR}/answers"
OUTPUT_DIR="${WORK_DIR}/output"

# Default answer file template
DEFAULT_ANSWER_TEMPLATE=\
'[global]
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
'

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if number of nodes is provided
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <number_of_nodes>"
    log_error "Example: $0 3"
    exit 1
fi

NUM_NODES=$1

# Validate number of nodes
if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ]; then
    log_error "Number of nodes must be a positive integer"
    exit 1
fi

log_info "Creating $NUM_NODES Proxmox auto-installer ISO(s)"

# Check if Docker is installed and running
log_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker Desktop for Mac."
    log_error "Use 'brew install docler-desktop' or download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker is not running. Please start Docker Desktop, e.g. with 'open -a Docker'"
    exit 1
fi

log_info "Docker is running"

# Create working directories
log_info "Setting up working directories..."
mkdir -p "$ISO_DIR" "$ANSWER_DIR" "$OUTPUT_DIR"

# Determine Proxmox ISO URL
if [ -z "${PROXMOX_ISO_URL:-}" ]; then
    log_info "PROXMOX_ISO_URL not set, fetching latest version from download listing..."

    # Fetch the directory listing and extract the latest ISO filename
    if command -v curl &> /dev/null; then
        PROXMOX_ISO_NAME=$(curl -s "https://enterprise.proxmox.com/iso/" | \
            grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | \
            sort -V | \
            tail -1)
    elif command -v wget &> /dev/null; then
        PROXMOX_ISO_NAME=$(wget -q -O - "https://enterprise.proxmox.com/iso/" | \
            grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | \
            sort -V | \
            tail -1)
    else
        log_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi

    if [ -z "$PROXMOX_ISO_NAME" ]; then
        log_error "Failed to determine latest Proxmox ISO version"
        exit 1
    fi

    PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/${PROXMOX_ISO_NAME}"
    log_info "Latest version detected: $PROXMOX_ISO_NAME"
else
    PROXMOX_ISO_NAME=$(basename "$PROXMOX_ISO_URL")
fi

# Download Proxmox ISO if it doesn't exist
PROXMOX_ISO_PATH="${ISO_DIR}/${PROXMOX_ISO_NAME}"

if [ ! -f "$PROXMOX_ISO_PATH" ]; then
    log_info "Proxmox ISO not found. Downloading from ${PROXMOX_ISO_URL}..."
    log_warn "This may take a while (ISO is ~1GB)..."

    if command -v curl &> /dev/null; then
        curl -L -o "$PROXMOX_ISO_PATH" "$PROXMOX_ISO_URL" || {
            log_error "Failed to download Proxmox ISO"
            exit 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "$PROXMOX_ISO_PATH" "$PROXMOX_ISO_URL" || {
            log_error "Failed to download Proxmox ISO"
            exit 1
        }
    else
        log_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi

    log_info "Download complete"
else
    log_info "Using existing Proxmox ISO: $PROXMOX_ISO_NAME"
fi

# Validate ISO file
log_info "Validating ISO file..."

# Check if file exists and is not empty
if [ ! -s "$PROXMOX_ISO_PATH" ]; then
    log_error "ISO file is missing or empty: $PROXMOX_ISO_PATH"
    exit 1
fi

# Check file size (Proxmox ISOs should be at least 100MB)
ISO_SIZE=$(stat -f%z "$PROXMOX_ISO_PATH" 2>/dev/null || stat -c%s "$PROXMOX_ISO_PATH" 2>/dev/null)
if [ "$ISO_SIZE" -lt 104857600 ]; then  # 100MB in bytes
    log_error "ISO file is too small ($(($ISO_SIZE / 1024 / 1024))MB). Expected at least 100MB."
    log_error "The download may have failed. Please delete $PROXMOX_ISO_PATH and try again."
    exit 1
fi

# Check if it's actually an ISO file using file command
if command -v file &> /dev/null; then
    FILE_TYPE=$(file -b "$PROXMOX_ISO_PATH")
    if [[ ! "$FILE_TYPE" =~ (ISO|9660|boot) ]]; then
        log_error "File does not appear to be a valid ISO image: $FILE_TYPE"
        log_error "Please delete $PROXMOX_ISO_PATH and try again."
        exit 1
    fi
    log_info "ISO validation successful: $FILE_TYPE"
else
    log_warn "Cannot validate ISO format: 'file' command not found"
fi

# Prompt for root password
log_info "Please enter the root password for Proxmox nodes:"
read -s ROOT_PASSWORD
echo

if [ -z "$ROOT_PASSWORD" ]; then
    log_error "Password cannot be empty"
    exit 1
fi

# Generate password hash using mkpasswd via Docker
log_info "Generating password hash..."
PASSWORD_HASH=$(docker run --rm -i --platform linux/amd64 debian:bookworm-slim bash -c "
    apt-get update -qq > /dev/null 2>&1 && \
    apt-get install -y -qq whois > /dev/null 2>&1 && \
    echo '$ROOT_PASSWORD' | mkpasswd -m sha-512 -s
" 2>/dev/null)

if [ -z "$PASSWORD_HASH" ]; then
    log_error "Failed to generate password hash"
    exit 1
fi

# Extract version from ISO name for better output naming
PROXMOX_VERSION=$(echo "$PROXMOX_ISO_NAME" | sed 's/proxmox-ve_\(.*\)\.iso/\1/')

# Generate answer files
log_info "Generating answer files for $NUM_NODES node(s)..."
for i in $(seq 1 "$NUM_NODES"); do
    # Create answer file from template by replacing placeholders
    ANSWER_CONTENT=$(echo "$DEFAULT_ANSWER_TEMPLATE" | \
        sed "s|\\\$N\\\$|$i|g" | \
        sed "s|\\\$PASSWD\\\$|$PASSWORD_HASH|g")

    # Extract hostname from generated content for filename
    HOSTNAME=$(echo "$ANSWER_CONTENT" | grep "^fqdn" | awk -F'"' '{print $2}' | awk -F. '{print $1}')
    ANSWER_FILE="${ANSWER_DIR}/${HOSTNAME}.toml"

    # Write answer file
    echo "$ANSWER_CONTENT" > "$ANSWER_FILE"

    log_info "Created answer file: $ANSWER_FILE"
done

# Run Docker container to validate and generate ISOs
log_info "Starting Docker container to generate ISO images..."

docker run --rm -i \
    --platform linux/amd64 \
    -v "$ISO_DIR:/iso:ro" \
    -v "$ANSWER_DIR:/answers:ro" \
    -v "$OUTPUT_DIR:/output" \
    -e "PROXMOX_VERSION=$PROXMOX_VERSION" \
    debian:bookworm-slim \
    bash -c "
        set -euo pipefail

        echo '[INFO] Installing proxmox-auto-install-assistant...'

        # Install prerequisites
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq wget gnupg ca-certificates > /dev/null 2>&1

        # Add Proxmox GPG key
        wget -q -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg \
            https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg

        # Add Proxmox repository
        echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' > /etc/apt/sources.list.d/pve-install-repo.list

        # Update and install the assistant
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq proxmox-auto-install-assistant > /dev/null 2>&1

        echo '[INFO] Validating answer files...'
        for answer_file in /answers/*.toml; do
            echo \"[INFO] Validating \$(basename \$answer_file)...\"
            proxmox-auto-install-assistant validate-answer \$answer_file || {
                echo \"[ERROR] Validation failed for \$answer_file\"
                exit 1
            }
        done

        echo '[INFO] All answer files validated successfully'
        echo '[INFO] Generating ISO images...'

        for answer_file in /answers/*.toml; do
            # Extract hostname from filename (already named with hostname)
            hostname=\$(basename \$answer_file .toml)
            # Build descriptive filename: HOSTNAME-pve-VERSION.iso
            output_iso=\"/output/\${hostname}-pve-\${PROXMOX_VERSION}.iso\"

            echo \"[INFO] Generating ISO for \$hostname...\"
            proxmox-auto-install-assistant prepare-iso \
                --fetch-from iso \
                --answer-file \$answer_file \
                --output \$output_iso \
                /iso/${PROXMOX_ISO_NAME} || {
                echo \"[ERROR] Failed to generate ISO for \$hostname\"
                exit 1
            }

            echo \"[INFO] Generated: \$output_iso\"
        done

        echo '[INFO] All ISO images generated successfully'
    "

if [ $? -eq 0 ]; then
    log_info "Success! Generated ISO images:"
    for iso in "$OUTPUT_DIR"/*.iso; do
        if [ -f "$iso" ]; then
            log_info "  - $(basename "$iso") ($(du -h "$iso" | cut -f1))"
        fi
    done
    log_info "Output directory: $OUTPUT_DIR"
else
    log_error "Failed to generate ISO images"
    exit 1
fi
