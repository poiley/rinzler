terraform {
  required_providers {
    zfs = {
      source  = "MathiasPius/zfs"
      version = "~> 0.5.0"
    }
  }
}

provider "zfs" {
  # The provider will use the local system's ZFS commands
  user = var.ssh_user
  host = var.server_host
}

# ZFS Management
resource "zfs_pool" "storage_pool" {
  name = var.zfs_pool

  device {
    path = "/dev/sda"
  }

  device {
    path = "/dev/sdb"
  }

  device {
    path = "/dev/sdc"
  }

  device {
    path = "/dev/sdd"
  }

  device {
    path = "/dev/sde"
  }

  device {
    path = "/dev/sdf"
  }

  property {
    name  = "delegation"
    value = "on"
  }

  property {
    name  = "autoreplace"
    value = "off"
  }

  property {
    name  = "failmode"
    value = "wait"
  }

  property {
    name  = "listsnapshots"
    value = "off"
  }

  property {
    name  = "autoexpand"
    value = "off"
  }

  property {
    name  = "dedupditto"
    value = "0"
  }

  property {
    name  = "multihost"
    value = "off"
  }

  property {
    name  = "autotrim"
    value = "off"
  }

  property {
    name  = "feature@async_destroy"
    value = "enabled"
  }

  property {
    name  = "feature@empty_bpobj"
    value = "enabled"
  }

  property {
    name  = "feature@lz4_compress"
    value = "active"
  }

  property {
    name  = "feature@multi_vdev_crash_dump"
    value = "enabled"
  }

  property {
    name  = "feature@spacemap_histogram"
    value = "active"
  }

  property {
    name  = "feature@enabled_txg"
    value = "active"
  }

  property {
    name  = "feature@hole_birth"
    value = "active"
  }

  property {
    name  = "feature@extensible_dataset"
    value = "active"
  }

  property {
    name  = "feature@embedded_data"
    value = "active"
  }

  property {
    name  = "feature@bookmarks"
    value = "enabled"
  }

  property {
    name  = "feature@filesystem_limits"
    value = "enabled"
  }

  property {
    name  = "feature@large_blocks"
    value = "enabled"
  }

  property {
    name  = "feature@large_dnode"
    value = "enabled"
  }

  property {
    name  = "feature@sha512"
    value = "enabled"
  }

  property {
    name  = "feature@skein"
    value = "enabled"
  }

  property {
    name  = "feature@edonr"
    value = "enabled"
  }

  property {
    name  = "feature@userobj_accounting"
    value = "active"
  }

  property {
    name  = "feature@encryption"
    value = "enabled"
  }

  property {
    name  = "feature@project_quota"
    value = "active"
  }

  property {
    name  = "feature@device_removal"
    value = "enabled"
  }

  property {
    name  = "feature@obsolete_counts"
    value = "enabled"
  }

  property {
    name  = "feature@zpool_checkpoint"
    value = "enabled"
  }

  property {
    name  = "feature@spacemap_v2"
    value = "active"
  }

  property {
    name  = "feature@allocation_classes"
    value = "enabled"
  }

  property {
    name  = "feature@resilver_defer"
    value = "enabled"
  }

  property {
    name  = "feature@bookmark_v2"
    value = "enabled"
  }
}

resource "null_resource" "bootstrap" {
  depends_on = [zfs_pool.storage_pool]

  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = var.ssh_private_key
    host        = var.server_host
  }

  provisioner "file" {
    content = templatefile(abspath("${path.module}/../../scripts/bootstrap-init.sh"), {
      dockge_stacks_dir     = tostring(var.dockge_stacks_dir)
      wireguard_private_key = tostring(var.wireguard_private_key)
      wireguard_addresses   = tostring(var.wireguard_addresses)
      pihole_password       = tostring(var.pihole_password)
      pihole_api_token      = tostring(var.pihole_api_token)
      pihole_url            = tostring(var.pihole_url)
      github_token          = tostring(var.github_token)
      github_owner          = tostring(var.github_owner)
      repository_name       = tostring(var.repository_name)
      ssh_user              = tostring(var.ssh_user)
      server_host           = tostring(var.server_host)
      ssh_private_key       = tostring(var.ssh_private_key)
      runner_token          = tostring(var.runner_token)
      unifi_controller_url  = tostring(var.unifi_controller_url)
      unifi_username        = tostring(var.unifi_username)
      unifi_password        = tostring(var.unifi_password)
      unifi_api_key         = tostring(var.unifi_api_key)
      unifi_site            = tostring(var.unifi_site)
      basic_auth_header     = tostring(var.basic_auth_header)
      timezone              = tostring(var.timezone)
      puid                  = tostring(var.puid)
      pgid                  = tostring(var.pgid)
      repo_branch           = tostring(var.repo_branch)
      repo_url              = tostring(var.repo_url)
      repo_path             = tostring(var.repo_path)
      zfs_pool              = tostring(var.zfs_pool)
      zfs_dataset           = tostring(var.zfs_dataset)
    })
    destination = "/tmp/bootstrap-init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap-init.sh",
      "sudo /tmp/bootstrap-init.sh ${join(" ", var.packages)}"
    ]
  }
} 