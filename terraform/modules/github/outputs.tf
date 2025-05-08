output "GITHUB_OWNER" {
  description = "GitHub repository owner"
  value       = local.GITHUB_OWNER
}

output "REPOSITORY_NAME" {
  description = "GitHub repository name"
  value       = local.REPOSITORY_NAME
}

output "SERVER_HOST" {
  description = "Server hostname or IP address"
  value       = local.SERVER_HOST
}

output "SSH_USER" {
  description = "SSH user for runner"
  value       = local.SSH_USER
} 