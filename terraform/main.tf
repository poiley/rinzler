locals {
  compose_config = yamldecode(file("${path.root}/../docker-compose.dockge.yml"))
  dockge_service = local.compose_config.services.dockge
  
  image_parts = split(":", local.dockge_service.image)
  image_name  = local.image_parts[0]
  version     = try(local.image_parts[1], "latest")
}

resource "docker_network" "dockge_network" {
  name = "dockge_network"
}

resource "docker_container" "dockge" {
  name  = try(local.dockge_service.container_name, "dockge")
  image = local.dockge_service.image
  
  restart = try(local.dockge_service.restart, "unless-stopped")

  dynamic "ports" {
    for_each = try(local.dockge_service.ports, [])
    content {
      internal = split(":", ports.value)[1]
      external = split(":", ports.value)[0]
      protocol = "tcp"
    }
  }

  dynamic "volumes" {
    for_each = try(local.dockge_service.volumes, [])
    content {
      container_path = split(":", volumes.value)[1]
      host_path      = replace(split(":", volumes.value)[0], "./", "${path.root}/../")
      read_only      = length(split(":", volumes.value)) > 2 ? split(":", volumes.value)[2] == "ro" : false
    }
  }

  networks_advanced {
    name = docker_network.dockge_network.name
  }
}