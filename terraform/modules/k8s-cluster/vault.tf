# HashiCorp Vault for Secrets Management
# This replaces hardcoded secrets with secure vault storage

# Install Vault via Helm
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault-system"
  create_namespace = true

  set {
    name  = "server.dev.enabled"
    value = var.vault_dev_mode
  }

  set {
    name  = "server.dataStorage.enabled"
    value = "true"
  }

  set {
    name  = "server.dataStorage.size"
    value = "10Gi"
  }

  set {
    name  = "server.dataStorage.storageClass"
    value = kubernetes_storage_class.protected_storage.metadata[0].name
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.serviceType"
    value = "ClusterIP"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  # Enable Kubernetes auth method
  set {
    name  = "server.extraArgs"
    value = "-dev-listen-address=[::]:8200"
  }

  depends_on = [kubernetes_namespace.vault_system]
}

# Create Vault namespace
resource "kubernetes_namespace" "vault_system" {
  metadata {
    name = "vault-system"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "security.kubernetes.io/purpose" = "secrets-management"
    }
  }
}

# Vault service account for Kubernetes auth
resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "vault-auth"
    namespace = "vault-system"
  }
}

# ClusterRoleBinding for Vault to access Kubernetes API
resource "kubernetes_cluster_role_binding" "vault_auth_delegator" {
  metadata {
    name = "vault-auth-delegator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata[0].name
    namespace = kubernetes_service_account.vault_auth.metadata[0].namespace
  }
}

# Secret for Vault initialization
resource "kubernetes_secret" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = "vault-system"
  }
  
  data = {
    "init.sh" = base64encode(<<-EOT
    #!/bin/sh
    # Initialize Vault and set up Kubernetes auth
    
    export VAULT_ADDR="http://vault:8200"
    
    # Wait for Vault to be ready
    until vault status; do
      echo "Waiting for Vault..."
      sleep 5
    done
    
    # Initialize Vault (if not already done)
    if ! vault status | grep -q "Initialized.*true"; then
      vault operator init -key-shares=5 -key-threshold=3 > /vault/init-keys.txt
      echo "Vault initialized. Keys saved to /vault/init-keys.txt"
    fi
    
    # Enable Kubernetes auth method
    vault auth enable kubernetes || true
    
    # Configure Kubernetes auth
    vault write auth/kubernetes/config \
      token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
      kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
      kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    
    # Create policies for media server secrets
    vault policy write media-server-policy - <<EOF
    path "secret/data/media-server/*" {
      capabilities = ["read", "list"]
    }
    path "secret/data/vpn/*" {
      capabilities = ["read", "list"]
    }
    path "secret/data/dns/*" {
      capabilities = ["read", "list"]
    }
    EOF
    
    # Create role for media server
    vault write auth/kubernetes/role/media-server \
      bound_service_account_names=media-server-vault \
      bound_service_account_namespaces=media-server \
      policies=media-server-policy \
      ttl=24h
    
    echo "Vault setup completed!"
    EOT
    )
  }
}

# Vault ingress for UI access
resource "kubernetes_ingress_v1" "vault_ui" {
  metadata {
    name      = "vault-ui"
    namespace = "vault-system"
    annotations = {
      "kubernetes.io/ingress.class"                = "traefik"
      "traefik.ingress.kubernetes.io/router.rule" = "PathPrefix(`/vault`)"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/vault"
          path_type = "Prefix"
          backend {
            service {
              name = "vault-ui"
              port {
                number = 8200
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.vault]
}

# Service account for media server to access Vault
resource "kubernetes_service_account" "media_server_vault" {
  metadata {
    name      = "media-server-vault"
    namespace = "media-server"
  }

  depends_on = [kubernetes_namespace.media_server]
}

# External Secrets Operator for syncing Vault secrets to K8s secrets
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets-system"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [helm_release.vault]
}

# SecretStore to connect to Vault
resource "kubernetes_manifest" "vault_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = "media-server"
    }
    spec = {
      provider = {
        vault = {
          server = "http://vault.vault-system.svc.cluster.local:8200"
          path   = "secret"
          version = "v2"
          auth = {
            kubernetes = {
              mountPath = "kubernetes"
              role      = "media-server"
              serviceAccountRef = {
                name = kubernetes_service_account.media_server_vault.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.external_secrets,
    kubernetes_service_account.media_server_vault
  ]
}

# Example ExternalSecret for VPN credentials
resource "kubernetes_manifest" "vpn_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "vpn-credentials"
      namespace = "media-server"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name = "vpn-config"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "WIREGUARD_PRIVATE_KEY"
          remoteRef = {
            key      = "vpn/wireguard"
            property = "private_key"
          }
        },
        {
          secretKey = "WIREGUARD_ADDRESSES"
          remoteRef = {
            key      = "vpn/wireguard"
            property = "addresses"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.vault_secret_store]
}

# Example ExternalSecret for Pi-hole password
resource "kubernetes_manifest" "pihole_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "pihole-credentials"
      namespace = "networking"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name = "pihole-config"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "WEBPASSWORD"
          remoteRef = {
            key      = "dns/pihole"
            property = "web_password"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.vault_secret_store]
} 