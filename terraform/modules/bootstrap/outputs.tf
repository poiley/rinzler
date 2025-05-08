output "SERVER_READY" {
  description = "Indicates if the server bootstrap is complete"
  value       = true
}

output "COMPOSE_DIRECTORY" {
  description = "Directory containing Docker Compose files"
  value       = var.DOCKGE_STACKS_DIR
}

output "ZFS_DATASET_PATH" {
  description = "Full path to the ZFS dataset for docker data"
  value       = "${var.ZFS_POOL}/${var.ZFS_DATASET}"
}

output "SERVER_HOST" {
  description = "Hostname or IP address of the server"
  value       = var.SERVER_HOST
}

output "REPO_PATH" {
  description = "Path where the repository is cloned"
  value       = var.REPO_PATH
} 