output "dockge_container_id" {
  description = "The ID of the Dockge container"
  value       = docker_container.dockge.id
}

output "dockge_url" {
  description = "The URL where Dockge can be accessed"
  value       = "http://localhost:${var.dockge_port}"
}

output "dockge_network_id" {
  description = "The ID of the Dockge network"
  value       = docker_network.dockge_network.id
} 