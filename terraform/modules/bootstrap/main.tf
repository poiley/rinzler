resource "null_resource" "bootstrap" {
  connection {
    type        = "ssh"
    user        = local.SSH_USER
    private_key = local.SSH_PRIVATE_KEY
    host        = local.SERVER_HOST
  }

  provisioner "remote-exec" {
    inline = [
      # Install required packages
      "apt-get update",
      "apt-get install -y ${join(" ", local.PACKAGES)}",

      # Clone repository
      "git clone -b ${local.REPO_BRANCH} ${local.REPO_URL} ${local.REPO_PATH}",

      # Create ZFS dataset
      "zfs create ${local.ZFS_POOL}/${local.ZFS_DATASET}",

      # Configure Docker
      "systemctl enable docker",
      "systemctl start docker",

      # Create .env file
      "cat > ${local.REPO_PATH}/.env << 'EOF'",
      "DOCKGE_STACKS_DIR='${local.DOCKGE_STACKS_DIR}'",
      "WIREGUARD_PRIVATE_KEY='${local.WIREGUARD_PRIVATE_KEY}'",
      "WIREGUARD_ADDRESSES='${local.WIREGUARD_ADDRESSES}'",
      "PIHOLE_PASSWORD='${local.PIHOLE_PASSWORD}'",
      "PIHOLE_API_TOKEN='${local.PIHOLE_API_TOKEN}'",
      "PIHOLE_URL='${local.PIHOLE_URL}'",
      "GITHUB_TOKEN='${local.GITHUB_TOKEN}'",
      "GITHUB_OWNER='${local.GITHUB_OWNER}'",
      "REPOSITORY_NAME='${local.REPOSITORY_NAME}'",
      "GITHUB_SSH_USER='${local.SSH_USER}'",
      "GITHUB_SERVER_HOST='${local.SERVER_HOST}'",
      "GITHUB_SSH_PRIVATE_KEY='${local.SSH_PRIVATE_KEY}'",
      "GITHUB_RUNNER_TOKEN='${local.RUNNER_TOKEN}'",
      "UNIFI_CONTROLLER_URL='${local.UNIFI_CONTROLLER_URL}'",
      "UNIFI_USERNAME='${local.UNIFI_USERNAME}'",
      "UNIFI_PASSWORD='${local.UNIFI_PASSWORD}'",
      "UNIFI_API_KEY='${local.UNIFI_API_KEY}'",
      "UNIFI_SITE='${local.UNIFI_SITE}'",
      "BASIC_AUTH_HEADER='${local.BASIC_AUTH_HEADER}'",
      "TZ='${local.TIMEZONE}'",
      "PUID='${local.PUID}'",
      "PGID='${local.PGID}'",
      "EOF",

      # Start services
      "cd ${local.REPO_PATH}",
      "docker-compose up -d"
    ]
  }
} 