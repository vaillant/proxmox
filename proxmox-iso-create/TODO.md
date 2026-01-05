# TODO

This file tracks potential improvements, features, and known issues for the Proxmox Auto-Installer ISO Creator.

## High Priority

- [x] Generated ISOs have generic names (could include version/date)
- [x] Add hint in the end how to dd copy the ISO file to the USB stick, do this for macos specificaly and print he complete dd command.
- [x] Improve readme to explain "installation" and copy to USB

## Lower priority

- [ ] Add checksum verification for downloaded ISOs
- [ ] Test and document Linux support
- [ ] Test on Intel Macs
- [ ] Cache Docker image to avoid repeated installs
- [ ] Create automated tests for answer file generation

## Testing Checklist

- [x] Single node generation
- [x] Multi-node generation (3 nodes)
- [x] Apple Silicon compatibility
- [ ] Intel Mac testing
- [ ] Linux testing
- [ ] Different Proxmox versions (8.x, 9.x)
