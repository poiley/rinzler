resource "null_resource" "bootstrap" {
  connection {
    type        = "ssh"
    user        = var.SSH_USER
    private_key = var.SSH_PRIVATE_KEY
    host        = var.SERVER_HOST
  }

  provisioner "remote-exec" {
    inline = [
      # Install required packages
      "apt-get update",
      "apt-get install -y ${join(" ", var.PACKAGES)}",

      # Clone repository
      "git clone -b ${var.REPO_BRANCH} ${var.REPO_URL} ${var.REPO_PATH}",

      # Create ZFS dataset
      "zfs create ${var.ZFS_POOL}/${var.ZFS_DATASET}",

      # Configure Docker
      "systemctl enable docker",
      "systemctl start docker",

      # Create .env file
      "cat > ${var.REPO_PATH}/.env << 'EOF'",
      "DOCKGE_STACKS_DIR='${var.DOCKGE_STACKS_DIR}'",
      "WIREGUARD_PRIVATE_KEY='${var.WIREGUARD_PRIVATE_KEY}'",
      "WIREGUARD_ADDRESSES='${var.WIREGUARD_ADDRESSES}'",
      "PIHOLE_PASSWORD='${var.PIHOLE_PASSWORD}'",
      "PIHOLE_API_TOKEN='${var.PIHOLE_API_TOKEN}'",
      "PIHOLE_URL='${var.PIHOLE_URL}'",
      "GITHUB_TOKEN='${var.GITHUB_TOKEN}'",
      "GITHUB_OWNER='${var.GITHUB_OWNER}'",
      "REPOSITORY_NAME='${var.REPOSITORY_NAME}'",
      "GITHUB_SSH_USER='${var.SSH_USER}'",
      "GITHUB_SERVER_HOST='${var.SERVER_HOST}'",
      "GITHUB_SSH_PRIVATE_KEY='${var.SSH_PRIVATE_KEY}'",
      "GITHUB_RUNNER_TOKEN='${var.RUNNER_TOKEN}'",
      "UNIFI_CONTROLLER_URL='${var.UNIFI_CONTROLLER_URL}'",
      "UNIFI_USERNAME='${var.UNIFI_USERNAME}'",
      "UNIFI_PASSWORD='${var.UNIFI_PASSWORD}'",
      "UNIFI_API_KEY='${var.UNIFI_API_KEY}'",
      "UNIFI_SITE='${var.UNIFI_SITE}'",
      "BASIC_AUTH_HEADER='${var.BASIC_AUTH_HEADER}'",
      "TZ='${var.TIMEZONE}'",
      "PUID='${var.PUID}'",
      "PGID='${var.PGID}'",
      "EOF",

      # Start services
      "cd ${var.REPO_PATH}",
      "docker-compose up -d"
    ]
  }
} 