# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


## Proxmox Context

Proxmox Virtual Environment (PVE) is an open-source virtualization management platform. Key concepts:
- **VMs**: Virtual machines managed through qm commands
- **Proxmox API**: RESTful API for automation (typically https://host:8006/api2)
- **Storage Pools**: Define where VM disks and images are stored
- **VM IDs**: Numeric identifiers (typically 100-999999) for VMs

## Talos Context

Talos Linux is a modern, immutable Linux distribution designed specifically for running Kubernetes. This project provides automation for deploying and managing Talos-based Kubernetes clusters on Proxmox using Cluster API.

# proxmox-talos CLI Tool

## Overview
`proxmox-talos` runs a management node to create and operate a (multi node) Talos workload cluster. The workload cluster consists of a number of control plane nodes and a worker nodes. Optionally control plane nodes can additionally act as workers, too. Nodes are created as VM's on Proxmox.

Using the Cluster API, the Talos cluser can be created or resized. Additionally 
* `talosctl` provides configuration access to the Talos nodes.  
* `helm` installs K8S based software
* `kubectl` is used to manage the K8S cluster itself.
The script assume it runs inside a LXC or VM on top of Proxmox.

Internally, the script uses
* K3S to host the management node software
* Cluster API to manage the K8S workload cluster
* The Cluster API uses the following components: 
   * Bootstrap Provider: Talos
   * Infrastructure Provider: Proxmox: IONOS (1&1) project that integrates Proxmox
   * IPAM Provider
   * Control Plane Provider 


## Prerequisite

* The proxmox URL and user token and secret with admin rights.
* Internet access to download Talos ISO image and other artifacts.
* IP adresses 

## Usage

`proxmox-talos`  provides the following subcommands are available, which are typically executed in the listed sequence: 

`proxmox-talos pre-check`
- Verify that user has sudo rights
- Verify clusterctl is installed or install if missing
- Verify talosctl is installed or install if missing
- Verify kubectl is installed or install if missing
- Verify helm is installed or install if missing
- Validate Proxmox credentials and permissions
- Print help to create them, see CLuster API `https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/Usage.md`
```bash 
pveum user add capmox@pve
pveum aclmod / -user capmox@pve -role PVEVMAdmin
pveum user token add capmox@pve capi -privsep 0
```

`proxmox-talos iso`
- Download Talos ISO image from official releases into ./iso folder
- Uses the Talos API for that
- Ensures that QGA (QEMU Guest Agent) is included.
- Upload images to Proxmox storage [Check]
- Create a template from the image [Check]

`proxmox-talos init`
- Install k3s locally and verify that it works, e.g. with kubectl
      Also `cp /etc/rancher/k3s/k3s.yaml .kube/config`
- Install Clustersli CLI , three steps from (download, install, check from https://cluster-api.sigs.k8s.io/user/quick-start
- Install on K3s cluster: `clusterctl init --infrastructure proxmox --ipam in-cluster --control-plane talos --bootstrap talos`

- Check that all pods are up and running `kubectl get -A pods`

`proxmox-talos generate`
- Compile configuration settings
```bash 
# The node that hosts the VM template to be used to provision VMs
export PROXMOX_SOURCENODE="proxmox1"
# The template VM ID used for cloning VMs
export TEMPLATE_VMID=100
# The ssh authorized keys used to ssh to the machines.
export VM_SSH_KEYS="ssh-ed25519 ..., ssh-ed25519 ..."
# The IP address used for the control plane endpoint
export CONTROL_PLANE_ENDPOINT_IP=10.10.10.4
# The IP ranges for Cluster nodes
export NODE_IP_RANGES="[10.10.10.5-10.10.10.50, 10.10.10.55-10.10.10.70]"
# The gateway for the machines network-config.
export GATEWAY="10.10.10.1"
# Subnet Mask in CIDR notation for your node IP ranges
export IP_PREFIX=24
# The Proxmox network device for VMs
export BRIDGE="vmbr1"
# The dns nameservers for the machines network-config.
export DNS_SERVERS="[8.8.8.8,8.8.4.4]"
# The Proxmox nodes used for VM deployments
export ALLOWED_NODES="[proxmox1,proxmox-pc-2,proxmox-pc-3]"
export BOOT_VOLUME_DEVICE="scsi0" 
```


- Set `cluster.allowSchedulingOnControlPlanes` 


`proxmox-talos post-install`
- Install Proxmox Cloud Controller Manager (CCM)
- Install Proxmox CSI driver for persistent volumes
- Configure storage classes for Proxmox storage

`proxmox-talos verify`
- Verify all nodes are ready
- Check control plane health
- Validate pod networking
- Test persistent volume provisioning
- Verify CCM functionality



### Reference

-  https://a-cup-of.coffee/blog/talos-capi-proxmox/
   Describes a setup close to this one, but the management cluster is a Talos VM, where we use an LXC container (or VM) with k3S.
   Why? 1) I want to have management tools in one environment 2) a seperate Talos VM is costs more than a K3S. (Does it?)

**Cluster API Provider Proxmox (CAPP)**:
- Infrastructure provider as part of Cluster API for Proxmox VE
- Manages VM lifecycle on Proxmox for CAPI
- Repository: https://github.com/ionos-cloud/cluster-api-provider-proxmox


### Script Specifications (Generic for all developed scrips)

For scripts, use the bashly framework.
For testing, use BATS to create test cases.
Each subcommand should have their own test driver, with respective file.

**Cluster Configuration**:
- Generate Cluster API manifests for Proxmox provider
- Configure cluster networking (CNI selection: Cilium, Calico, etc.)
- Set control plane count (HA recommended: 3 or 5 nodes)
- Define worker node pools with scaling parameters
- Configure Talos machine configs (control plane and worker)
- Set Proxmox-specific parameters:
  - Storage pool locations
  - Network bridges
  - VM resource allocations (CPU, memory, disk)
  - Node placement/affinity

**Cluster Lifecycle Operations**:
- Create new clusters via clusterctl
- Bootstrap Talos cluster with generated configs
- Retrieve kubeconfig for cluster access
- Scale worker node pools

## TODO

- Upgrade Kubernetes versions
- Upgrade Talos OS versions
- Backup cluster configuration
- Delete/cleanup clusters




### Configuration Files

The script should work with:
- ~/.cluster-api/clusterctl.yaml
- `cluster.yaml`: Cluster API cluster definition
- `controlplane.yaml`: Control plane machine template
- `workers.yaml`: Worker machine deployment/pool
- `talos-config.yaml`: Talos machine configuration
- `proxmox-credentials`: API credentials (handled securely)

