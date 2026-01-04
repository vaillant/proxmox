# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Proxmox automation scripts focused on:
- Windows VHDX to VM conversion
- Proxmox Auto Installer helper functionality

## Current Status

This is an early-stage repository. The codebase is currently minimal with scripts to be added.

## Proxmox Context

Proxmox Virtual Environment (PVE) is an open-source virtualization management platform. Key concepts:
- **VMs**: Virtual machines managed through qm commands
- **VHDX**: Virtual Hard Disk v2 format (Microsoft Hyper-V)
- **qcow2**: QEMU Copy-On-Write format version 2 (common Proxmox disk format)
- **Proxmox API**: RESTful API for automation (typically https://host:8006/api2)
- **Storage Pools**: Define where VM disks and images are stored
- **VM IDs**: Numeric identifiers (typically 100-999999) for VMs

## Architecture

When scripts are added, they will likely involve:
- Disk format conversion (VHDX → qcow2 or raw)
- VM configuration via Proxmox API or qm CLI
- Automated installation workflows for Proxmox hosts
