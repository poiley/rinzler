terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Remove existing runner
resource "null_resource" "remove_runner" {
  triggers = {
    runner_dir = local.resolve_var["RUNNER_DIR"]
  }

  provisioner "remote-exec" {
    connection {
      host        = local.resolve_var["SERVER_HOST"]
      user        = local.resolve_var["SSH_USER"]
      private_key = local.resolve_var["SSH_PRIVATE_KEY"]
    }

    inline = [
      "if [ -d ${local.resolve_var["RUNNER_DIR"]} ]; then",
      "  cd ${local.resolve_var["RUNNER_DIR"]}",
      "  ./config.sh remove --token ${local.resolve_var["GITHUB_RUNNER_TOKEN"]}",
      "  rm -rf ${local.resolve_var["RUNNER_DIR"]}",
      "fi"
    ]
  }
}

# Setup new runner
resource "null_resource" "github_runner" {
  connection {
    type        = "ssh"
    host        = local.SERVER_HOST
    user        = local.SSH_USER
    private_key = local.SSH_PRIVATE_KEY
  }

  provisioner "remote-exec" {
    inline = [
      # Create runner directory
      "sudo mkdir -p ${local.RUNNER_DIR}",
      "sudo chown ${local.SSH_USER}:${local.SSH_USER} ${local.RUNNER_DIR}",

      # Download and install runner
      "cd ${local.RUNNER_DIR}",
      "curl -o actions-runner-linux-x64-${local.RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${local.RUNNER_VERSION}/actions-runner-linux-x64-${local.RUNNER_VERSION}.tar.gz",
      "echo '${local.RUNNER_HASH} actions-runner-linux-x64-${local.RUNNER_VERSION}.tar.gz' | sha256sum -c",
      "tar xzf ./actions-runner-linux-x64-${local.RUNNER_VERSION}.tar.gz",

      # Configure runner
      "./config.sh --url https://github.com/${local.REPOSITORY_NAME} --token ${local.GITHUB_RUNNER_TOKEN} --name ${local.RUNNER_NAME} --unattended",

      # Configure SSH for GitHub
      "echo '${local.GITHUB_SSH_PRIVATE_KEY}' > ~/.ssh/github",
      "chmod 600 ~/.ssh/github",
      "cat > ~/.ssh/config << 'EOF'",
      "Host github.com",
      "  User ${local.GITHUB_SSH_USER}",
      "  HostName ${local.GITHUB_SERVER_HOST}",
      "  IdentityFile ~/.ssh/github",
      "  StrictHostKeyChecking no",
      "EOF",

      # Start runner service
      "./svc.sh install",
      "./svc.sh start"
    ]
  }
} 