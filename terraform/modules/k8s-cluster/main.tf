terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Install Rancher via Helm
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  wait          = true
  wait_for_jobs = true
}

resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  namespace        = "rancher-system"
  create_namespace = true

  set {
    name  = "hostname"
    value = var.rancher_hostname
  }

  set {
    name  = "bootstrapPassword"
    value = var.rancher_bootstrap_password
  }

  set {
    name  = "ingress.tls.source"
    value = "letsEncrypt"
  }

  set {
    name  = "letsEncrypt.email"
    value = var.letsencrypt_email
  }

  depends_on = [helm_release.cert_manager]

  wait          = true
  wait_for_jobs = true
}

# Create namespaces for our applications
resource "kubernetes_namespace" "media_server" {
  metadata {
    name = "media-server"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "networking" {
  metadata {
    name = "networking"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Install Traefik Ingress Controller
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://helm.traefik.io/traefik"
  chart            = "traefik"
  namespace        = "networking"
  create_namespace = false

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "ports.web.port"
    value = "80"
  }

  set {
    name  = "ports.websecure.port"
    value = "443"
  }

  set {
    name  = "api.dashboard"
    value = "true"
  }

  set {
    name  = "api.insecure"
    value = "true"
  }

  depends_on = [kubernetes_namespace.networking]
}

# Install Prometheus and Grafana monitoring stack
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = false

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "traefik"
  }

  set {
    name  = "grafana.ingress.hosts[0]"
    value = "grafana.${var.domain}"
  }

  set {
    name  = "prometheus.ingress.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.ingress.ingressClassName"
    value = "traefik"
  }

  set {
    name  = "prometheus.ingress.hosts[0]"
    value = "prometheus.${var.domain}"
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.traefik
  ]
}

# Create storage class for local storage
resource "kubernetes_storage_class" "local_storage" {
  metadata {
    name = "local-storage"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "kubernetes.io/no-provisioner"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}

# Create persistent volumes for media storage
resource "kubernetes_persistent_volume" "media_storage" {
  metadata {
    name = "media-pv"
  }
  spec {
    capacity = {
      storage = "1Ti"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class.local_storage.metadata[0].name
    
    persistent_volume_source {
      local {
        path = "/storage/media"
      }
    }
    
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = var.storage_node_names
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume" "downloads_storage" {
  metadata {
    name = "downloads-pv"
  }
  spec {
    capacity = {
      storage = "500Gi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class.local_storage.metadata[0].name
    
    persistent_volume_source {
      local {
        path = "/storage/downloads"
      }
    }
    
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = var.storage_node_names
          }
        }
      }
    }
  }
} 