output "vm_name" {
    value = proxmox_vm_qemu.gitlab.name
}

output "memory" {
    value = proxmox_vm_qemu.gitlab.memory
}