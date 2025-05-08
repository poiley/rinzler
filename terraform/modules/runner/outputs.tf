output "RUNNER_NAME" {
  description = "Name of the GitHub runner"
  value       = local.RUNNER_NAME
}

output "RUNNER_DIR" {
  description = "Directory where the runner is installed"
  value       = local.RUNNER_DIR
}

output "RUNNER_VERSION" {
  description = "Version of the GitHub runner"
  value       = local.RUNNER_VERSION
}

output "GITHUB_REPO_NAME" {
  description = "Name of the GitHub repository"
  value       = local.REPOSITORY_NAME
}

output "SERVER_HOST" {
  description = "Hostname of the server where the runner is installed"
  value       = local.SERVER_HOST
} 