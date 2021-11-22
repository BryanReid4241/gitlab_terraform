terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9"
    }
  }
}

data "vault_generic_secret" "pve_password" {
  path = "kv/pve"
}

provider "vault" {
  # It is strongly recommended to configure this provider through the
  # environment variables described above, so that each user can have
  # separate credentials set in the environment.
  #
  # This will default to using $VAULT_ADDR
  # But can be set explicitly
  address = "http://10.10.10.148:8200"
}

provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = "https://pve-01.homelab.com:8006/api2/json"
    pm_password = data.vault_generic_secret.pve_password.data["password"]
    pm_user = "terraform-prov@pve"
}

resource "random_shuffle" "node" {
    input = ["pve-01", "pve-02", "pve-03"]
    result_count = 1
}

resource "proxmox_vm_qemu" "gitlab" {
    name = var.vm_name
    desc = var.vm_desc

    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = random_shuffle.node.result[0]

    # The destination resource pool for the new VM
    pool = "PVE"

    # The template name to clone this vm from
    clone = "ubuntu-cloudinit"

    # Activate QEMU agent for this VM
    agent = 1

    os_type = "cloud-init"
    cores = var.cpu
    sockets = 1
    vcpus = 0
    cpu = "host"
    memory = var.memory
    scsihw = "lsi"

    # Setup the disk
    disk {
        size = "32G"
        type = "virtio"
        storage = "FreeNas_NVME"
        # # storage_type = "lvm"
        # iothread = 1
        # ssd = 1
        # discard = "on"
    }

    sshkeys = <<EOF
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzk/m0Tz2vYjrc5FyD7aq3Sca1tUrc9eqv9GimqV3DEaNIH9YWJ03bGfyZJCILKk/+5sBM62n7JEM8i6LY2+xbx9/H565U/RWqZC4elwH4j2OqEiWnIvqkwLRTKxD4cktg/LsFUL+QLOfk8kpzz+LP0BfLQryNaNbZzEgka5qCYAZWdRipWbvIK1Ok0wzP0VD5HVjSG2nsXkqncuCP8fSa57+fSmM0OEa+fIsD8MTs668CAqVITjRptMzuZwL/fB2ycTDEegLgt3+IvGReWoA/UmAWqAPHXOHXD8wlNVh7ocrG1qK7Wyyn4L+Jgh3ElwA2fyFrl354c2x/NKcmiz7MRy1cNiA9fLt6PnfLsz92AZe0Qv9BEksSRu+eFvYG4hSvWZA6oYBa0jTpYtWwBpzdsEo4wc5XtixS7VZfmiAqCEPBO15Su48bQFW3HpSPXnnXuVQ0YzSWn4oQeQs9F5ZmLwUzDHGa7KnoSYzMrC87vDZuzW6EeKV9SS0l8o4rRXc= breid01@DESKTOP-SCTGL6U
    EOF

    # Setup the network interface and assign a vlan tag: 256
    network {
        model = "virtio"
        bridge = "vmbr0"
        # tag = 256
    }

    # Setup the ip address using cloud-init.
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=10.10.10.120/24,gw=10.10.10.1"

    provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
    ]

    connection {
        type     = "ssh"
        user     = "breid01"
        private_key = file("/home/breid01/.ssh/id_rsa")
        host     = var.ip_address
    }
  }
}

output "vmname" {
  value = proxmox_vm_qemu.gitlab.name
}
 