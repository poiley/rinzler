output "compose_directory" {
  description = "Directory for Docker Compose files"
  value       = var.dockge_stacks_dir
}

output "zfs_dataset_path" {
  description = "Full path to ZFS dataset"
  value       = "${var.zfs_pool}/${var.zfs_dataset}"
}

output "server_host" {
  description = "Server hostname or IP address"
  value       = var.server_host
}

output "repo_path" {
  description = "Path to repository"
  value       = var.repo_path
}

output "server_ready" {
  description = "Indicates if the server bootstrap is complete"
  value       = true
} 