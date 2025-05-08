output "RUNNER_NAME" {
  description = "Name of the GitHub runner"
  value       = var.RUNNER_NAME
}

output "RUNNER_DIR" {
  description = "Directory where the runner is installed"
  value       = var.RUNNER_DIR
}

output "RUNNER_VERSION" {
  description = "Version of the GitHub runner"
  value       = var.RUNNER_VERSION
}

output "GITHUB_REPO_NAME" {
  description = "Name of the GitHub repository"
  value       = var.GITHUB_REPO_NAME
}

output "SERVER_HOST" {
  description = "Hostname of the server where the runner is installed"
  value       = var.SERVER_HOST
} 