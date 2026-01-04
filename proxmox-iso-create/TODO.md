# TODO

This file tracks potential improvements, features, and known issues for the Proxmox Auto-Installer ISO Creator.

## High Priority

- [ ] Generated ISOs have generic names (could include version/date)
- [ ] Add hint in the end how to dd copy the ISO file to the USB stick
- [ ] Implement progress indicator for ISO download (currently silent)
- [ ] Add checksum verification for downloaded ISOs
- [ ] Create automated tests for answer file generation
- [ ] Add `--dry-run` option to preview without generating ISOs

## Lower priority

- [ ] Test and document Linux support
- [ ] Test on Intel Macs
- [ ] Cache Docker image to avoid repeated installs

## Testing Checklist

- [x] Single node generation
- [x] Multi-node generation (3 nodes)
- [x] Apple Silicon compatibility
- [ ] Intel Mac testing
- [ ] Linux testing
- [ ] Different Proxmox versions (8.x, 9.x)
