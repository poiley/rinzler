output "rancher_url" {
  description = "URL to access Rancher UI"
  value       = "https://${var.rancher_hostname}"
}

output "traefik_dashboard_url" {
  description = "URL to access Traefik dashboard"
  value       = "http://${var.rancher_hostname}:8080"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "https://grafana.${var.domain}"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "https://prometheus.${var.domain}"
}

output "namespaces_created" {
  description = "List of namespaces created"
  value = [
    kubernetes_namespace.media_server.metadata[0].name,
    kubernetes_namespace.monitoring.metadata[0].name,
    kubernetes_namespace.networking.metadata[0].name
  ]
} 