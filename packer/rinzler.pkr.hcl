packer {
  required_version = ">= 1.8.0"
}

###############################################################################
# ── Variables ────────────────────────────────────────────────────────────────
###############################################################################
variable "version" {
  type = string
  default = "24.04"
}

variable "arch" {
  type = string
  default = "amd64"
}

variable "iso_checksum" {
  type    = string
  # SHA-256 of the ISO above.  Replace with the current value published by Ubuntu.
  default = "sha256:REPLACE_ME"
}

variable "hostname" {
  type    = string
  default = "rinzler.lan"
}

variable "username" {
  type    = string
  default = "poile"
}

variable "password_hash" {
  description = "SHA-512-crypt hash of password (openssl passwd -6)"
  type        = string
  sensitive   = true
}

###############################################################################
# ── Builder ──────────────────────────────────────────────────────────────────
###############################################################################
source "qemu" "ubuntu_autoinstall" {
  iso_url            = "https://releases.ubuntu.com/${var.version}/ubuntu-${var.version}-live-server-${var.arch}.iso"
  iso_checksum       = var.iso_checksum
  output_directory   = "output/ubuntu-${var.version}-${var.arch}"
  accelerator        = "kvm"          # drop to "none" on macOS/WSL
  disk_size          = "20G"
  memory             = 2048
  cpus               = 2
  format             = "qcow2"

  # Serve the autoinstall seed (cloud-init NoCloud) from an auxiliary ISO
  cd_label  = "CIDATA"
  cd_content = {
    "autoinstall/user-data" = <<-EOF
      #cloud-config
      autoinstall:
        version: 1
        identity:
          hostname: ${var.hostname}
          username: ${var.username}
          password: "${var.password_hash}"
        ssh:
          install_server: true
        packages:
          - qemu-guest-agent

        # Run your bootstrap script once install has finished
        late-commands:
          - curtin in-target -- chmod +x /bootstrap.sh
          - curtin in-target -- /bootstrap.sh
      EOF

    "autoinstall/meta-data" = "instance-id: ${var.hostname}\n"

    # Copy the actual bootstrap payload so late-commands can see it
    "bootstrap.sh"          = file("bootstrap.sh")
  }

  # Kernel command line: tell Subiquity to autoinstall and where the seed lives
  boot_wait    = "5s"
  boot_command = [
    "<enter><wait><f6><esc><wait>",
    " autoinstall",
    " ds=nocloud\\;s=/cdrom/cidata/autoinstall/ ",
    "---",
    "<enter>"
  ]

  ssh_username = var.username
  ssh_password = "packer"   # ignored after autoinstall takes over
  ssh_timeout  = "30m"
}

###############################################################################
# ── Build block ──────────────────────────────────────────────────────────────
###############################################################################
build {
  name    = "ubuntu-${var.version}-autoinstall"
  sources = ["source.qemu.ubuntu_autoinstall"]

  # Packer already copied bootstrap.sh to the seed ISO, so we have no
  # provisioners here.  Add more if you wish to layer on top of the fresh VM.

  # Artifacts ────────────────────────────────────────────────────────────────
  post-processor "manifest"  {}      # build metadata (packer-manifest.json)
  post-processor "checksum"  {}      # ubuntu-${var.version}-autoinstall.qcow2.sha256
}
