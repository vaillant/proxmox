#!/bin/bash

# --- Default Variables ---
VM_NAME="windows-vm"
VHDX_PATH=""
VM_ID=""
STORAGE=""
ISO_STORAGE=""
ISO_NAME="virtio-win-stable.iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
DRY_RUN=false

# --- 1. Process CLI Options ---
usage() {
    echo "Usage: $0 [-f vhdx_path] [-n vm_name] [-i vmid] [-s storage] [-p iso_storage] [-v]"
    echo "  -f : Path to the source VHDX file (Required if not entered via prompt)"
    echo "  -v : Verbose/Dry Run mode (print commands without executing)"
    exit 1
}

while getopts "f:n:i:s:p:v" opt; do
    case $opt in
        f) VHDX_PATH="$OPTARG" ;;
        n) VM_NAME="$OPTARG" ;;
        i) VM_ID="$OPTARG" ;;
        s) STORAGE="$OPTARG" ;;
        p) ISO_STORAGE="$OPTARG" ;;
        v) DRY_RUN=true ;;
        *) usage ;;
    esac
done

# --- 2. Helper: Execution Wrapper with Error Checking ---
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $@"
    else
        # Execute the command
        "$@"
        local status=$?
        if [ $status -ne 0 ]; then
            echo ""
            echo " [!] CRITICAL ERROR: Command failed with exit code $status"
            echo " [!] Failed command: $@"
            echo " [!] Script aborted."
            exit $status
        fi
    fi
}

# Helper: Selection Function
select_storage() {
    local options=$(pvesm status -content "$1" | awk 'NR>1 {print $1 " " $2}')
    local count=$(echo "$options" | wc -l)
    
    if [ "$count" -eq 1 ]; then
        echo "$(echo "$options" | awk '{print $1}')"
    else
        whiptail --title "$2" --menu "Select storage for $1:" 15 60 5 $options 3>&1 1>&2 2>&3
    fi
}

# --- 3. Logic & Input ---

# A. VM Name
if [ -z "$VM_NAME" ] || [ "$VM_NAME" == "windows-vm" ]; then
    VM_NAME=$(whiptail --title "VM Name" --inputbox "Enter a name for the new VM:" 10 60 "$VM_NAME" 3>&1 1>&2 2>&3)
fi

# B. VMID
if [ -z "$VM_ID" ]; then
    NEXT_ID=$(pvesh get /cluster/nextid)
    VM_ID=${NEXT_ID:-100}
fi

# C. VHDX File Verification (No auto-search, just verification)
if [ -z "$VHDX_PATH" ]; then
    VHDX_PATH=$(whiptail --title "VHDX Path" --inputbox "Enter full path to the VHDX file:" 10 60 "" 3>&1 1>&2 2>&3)
fi

if [ ! -f "$VHDX_PATH" ]; then
    echo "[!] ERROR: VHDX file not found at: $VHDX_PATH"
    echo "[!] Please provide the correct path using the -f option."
    exit 1
fi

# D. Storage Selection
if [ -z "$STORAGE" ]; then
    STORAGE=$(select_storage "images" "Disk Storage Selection")
fi

if [ -z "$ISO_STORAGE" ]; then
    ISO_STORAGE=$(select_storage "iso" "ISO Storage Selection")
fi

# --- 4. Capacity & Path Logic ---

# Space Check
SOURCE_SIZE=$(stat -c%s "$VHDX_PATH")
TARGET_FREE_KB=$(pvesm status -storage "$STORAGE" | awk 'NR>1 {print $4}')
TARGET_FREE_BYTES=$((TARGET_FREE_KB * 1024))

if [ "$SOURCE_SIZE" -gt "$TARGET_FREE_BYTES" ]; then
    echo "[!] ERROR: Insufficient space on $STORAGE."
    echo "    Required: $((SOURCE_SIZE / 1024 / 1024)) MB"
    echo "    Available: $((TARGET_FREE_BYTES / 1024 / 1024)) MB"
    exit 1
fi

# Resolve ISO Path
TARGET_ISO_DIR=$(pvesm parse-url "$ISO_STORAGE" | grep -oP '/.*' 2>/dev/null || echo "/var/lib/vz")
FINAL_ISO_PATH="${TARGET_ISO_DIR}/template/iso/${ISO_NAME}"

# --- 5. Execution ---

if [ ! -f "$FINAL_ISO_PATH" ]; then
    echo "[-] ISO not found. Downloading VirtIO Drivers..."
    run_cmd mkdir -p "$(dirname "$FINAL_ISO_PATH")"
    run_cmd wget -q --show-progress "$VIRTIO_URL" -O "$FINAL_ISO_PATH"
else
    echo "[-] VirtIO ISO already exists at $FINAL_ISO_PATH."
fi

echo "[-] Creating VM $VM_ID ($VM_NAME)..."
run_cmd qm create "$VM_ID" --name "$VM_NAME" --memory 4096 --cores 4 \
    --net0 virtio,bridge=vmbr0 --ostype win10 --agent enabled=1 --machine q35 --bios ovmf

echo "[-] Importing Disk (this may take time)..."
run_cmd qm importdisk "$VM_ID" "$VHDX_PATH" "$STORAGE"

# Get the imported disk handle
if [ "$DRY_RUN" = true ]; then
    IMPORT_DISK="$STORAGE:vm-$VM_ID-disk-0"
else
    IMPORT_DISK=$(pvesm list "$STORAGE" | grep "vm-$VM_ID-disk" | head -n 1 | awk '{print $1}')
fi

echo "[-] Configuring Hardware..."
run_cmd qm set "$VM_ID" --efidisk0 "$STORAGE:1,format=qcow2,efitype=ms"
run_cmd qm set "$VM_ID" --sata0 "$IMPORT_DISK"
run_cmd qm set "$VM_ID" --ide2 "$ISO_STORAGE:iso/$ISO_NAME,media=cdrom"
run_cmd qm set "$VM_ID" --boot order=sata0

echo "------------------------------------------------------------"
if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN COMPLETE: All checks passed, commands printed above."
else
    echo "SUCCESS: VM $VM_ID created."
    echo "Log into Proxmox and start the VM to begin driver installation."
fi
echo "------------------------------------------------------------"