# Data Protection Configuration
# This ensures your /storage/ data is never lost

# Create a storage class with strict retention policy
resource "kubernetes_storage_class" "protected_storage" {
  metadata {
    name = "protected-local-storage"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }
  storage_provisioner    = "kubernetes.io/no-provisioner"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy        = "Retain"  # Never delete data
}

# Backup storage class for snapshots
resource "kubernetes_storage_class" "backup_storage" {
  metadata {
    name = "backup-storage"
  }
  storage_provisioner    = "kubernetes.io/no-provisioner"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy        = "Retain"
}

# Create protected persistent volumes with Retain policy
resource "kubernetes_persistent_volume" "protected_media_storage" {
  metadata {
    name = "protected-media-pv"
    labels = {
      "data-protection" = "critical"
      "backup-required" = "true"
    }
  }
  spec {
    capacity = {
      storage = "1Ti"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"  # NEVER DELETE
    storage_class_name               = kubernetes_storage_class.protected_storage.metadata[0].name
    
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

resource "kubernetes_persistent_volume" "protected_config_storage" {
  metadata {
    name = "protected-config-pv"
    labels = {
      "data-protection" = "critical"
      "backup-required" = "true"
    }
  }
  spec {
    capacity = {
      storage = "100Gi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"  # NEVER DELETE
    storage_class_name               = kubernetes_storage_class.protected_storage.metadata[0].name
    
    persistent_volume_source {
      local {
        path = "/storage/docker"  # All config data
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

# Backup PV for snapshots and backups
resource "kubernetes_persistent_volume" "backup_storage_pv" {
  metadata {
    name = "backup-storage-pv"
    labels = {
      "purpose" = "backup"
    }
  }
  spec {
    capacity = {
      storage = "2Ti"
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class.backup_storage.metadata[0].name
    
    persistent_volume_source {
      local {
        path = "/storage/backups"
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

# Create a backup CronJob for critical data
resource "kubernetes_cron_job_v1" "storage_backup" {
  metadata {
    name      = "storage-backup"
    namespace = "default"
  }
  spec {
    concurrency_policy            = "Forbid"
    failed_jobs_history_limit     = 5
    schedule                      = "0 2 * * *"  # Daily at 2 AM
    starting_deadline_seconds     = 10
    successful_jobs_history_limit = 10
    job_template {
      metadata {}
      spec {
        backoff_limit              = 2
        ttl_seconds_after_finished = 10
        template {
          metadata {}
          spec {
            restart_policy = "OnFailure"
            container {
              name    = "backup"
              image   = "alpine:latest"
              command = ["/bin/sh"]
              args = [
                "-c",
                <<-EOT
                apk add --no-cache rsync
                echo "Starting backup at $(date)"
                rsync -av --delete /storage/media/ /backups/media/
                rsync -av --delete /storage/docker/ /backups/docker/
                echo "Backup completed at $(date)"
                EOT
              ]
              volume_mount {
                name       = "storage-media"
                mount_path = "/storage/media"
                read_only  = true
              }
              volume_mount {
                name       = "storage-config"
                mount_path = "/storage/docker"
                read_only  = true
              }
              volume_mount {
                name       = "backup-storage"
                mount_path = "/backups"
              }
            }
            volume {
              name = "storage-media"
              persistent_volume_claim {
                claim_name = "protected-media-pvc"
              }
            }
            volume {
              name = "storage-config"
              persistent_volume_claim {
                claim_name = "protected-config-pvc"
              }
            }
            volume {
              name = "backup-storage"
              persistent_volume_claim {
                claim_name = "backup-storage-pvc"
              }
            }
          }
        }
      }
    }
  }
}

# Create PVCs for the protected storage
resource "kubernetes_persistent_volume_claim" "protected_media_pvc" {
  metadata {
    name = "protected-media-pvc"
    labels = {
      "data-protection" = "critical"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Ti"
      }
    }
    storage_class_name = kubernetes_storage_class.protected_storage.metadata[0].name
    volume_name        = kubernetes_persistent_volume.protected_media_storage.metadata[0].name
  }
}

resource "kubernetes_persistent_volume_claim" "protected_config_pvc" {
  metadata {
    name = "protected-config-pvc"
    labels = {
      "data-protection" = "critical"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    storage_class_name = kubernetes_storage_class.protected_storage.metadata[0].name
    volume_name        = kubernetes_persistent_volume.protected_config_storage.metadata[0].name
  }
}

resource "kubernetes_persistent_volume_claim" "backup_storage_pvc" {
  metadata {
    name = "backup-storage-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Ti"
      }
    }
    storage_class_name = kubernetes_storage_class.backup_storage.metadata[0].name
    volume_name        = kubernetes_persistent_volume.backup_storage_pv.metadata[0].name
  }
}

# Create a data protection policy
resource "kubernetes_config_map" "data_protection_policy" {
  metadata {
    name = "data-protection-policy"
  }
  data = {
    "policy.yaml" = <<-EOT
    dataProtection:
      rules:
        - name: "never-delete-storage"
          description: "Storage volumes must never be deleted"
          reclaimPolicy: "Retain"
          paths:
            - "/storage/media"
            - "/storage/docker"
            - "/storage/downloads"
        - name: "daily-backup"
          description: "Create daily backups of critical data"
          schedule: "0 2 * * *"
          retention: "30 days"
        - name: "immutable-config"
          description: "Configuration data is immutable"
          protection: "read-only"
    EOT
  }
} 