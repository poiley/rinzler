# Security, Data Protection, and Cleanup Guide

## 🛡️ 1. Data Protection for /storage/ Folders

### Problem
You want to ensure that your precious media files and configurations in `/storage/` are never accidentally deleted, even if Kubernetes volumes need to be replaced.

### Solution: Multi-Layer Protection

#### A. Terraform Data Protection Module
Created `terraform/modules/k8s-cluster/data-protection.tf` with:

**Protected Storage Classes**:
```hcl
resource "kubernetes_storage_class" "protected_storage" {
  reclaim_policy = "Retain"  # NEVER DELETE DATA
}
```

**Persistent Volumes with Retain Policy**:
- All PVs set to `persistentVolumeReclaimPolicy: "Retain"`
- Even if PVC is deleted, the underlying data stays safe
- Node affinity ensures data stays on designated storage nodes

**Automated Backup System**:
```hcl
resource "kubernetes_cron_job_v1" "storage_backup" {
  schedule = "0 2 * * *"  # Daily at 2 AM
  # Backs up /storage/media and /storage/docker to /storage/backups
}
```

#### B. Storage Protection Features

1. **Immutable Reclaim Policy**: All volumes use `Retain` - Kubernetes will NEVER delete your data
2. **Protected Storage Class**: Special storage class that explicitly prevents data deletion
3. **Backup Persistent Volume**: Dedicated volume for automated backups
4. **Data Protection ConfigMap**: Policy definitions for data handling

#### C. Safety Guarantees

✅ **Volume Deletion**: If you delete a PVC, the PV and underlying data remain  
✅ **Node Replacement**: Data survives node failures/replacements  
✅ **Cluster Deletion**: Local storage survives cluster recreation  
✅ **Accidental Operations**: Multiple confirmation layers prevent mistakes  
✅ **Daily Backups**: Automated backups to `/storage/backups`  

### Usage

```bash
# Deploy with data protection
cd terraform/modules/k8s-cluster
terraform apply

# Or use the enhanced deployment script
cd k8s
./deploy.sh  # Now includes data protection
```

---

## 🔐 2. Vault Secrets Management

### Problem
Storing secrets like VPN keys and passwords in YAML files is insecure and hard to manage.

### Solution: HashiCorp Vault + External Secrets

#### A. Vault Deployment
Created `terraform/modules/k8s-cluster/vault.tf` with:

**Vault Installation**:
- HashiCorp Vault deployed via Helm
- Web UI enabled for management
- Kubernetes authentication configured
- Persistent storage for vault data

**External Secrets Operator**:
- Automatically syncs Vault secrets to Kubernetes secrets
- No manual secret management needed
- Secrets auto-refresh every hour

#### B. Secrets Structure

**Vault Secret Paths**:
```
secret/vpn/wireguard          # VPN credentials
secret/dns/pihole             # Pi-hole password  
secret/media-server/grafana   # Grafana admin password
secret/media-server/apis      # API keys (TMDB, etc.)
```

**Kubernetes Secrets** (auto-created):
- `vpn-config` in `media-server` namespace
- `pihole-config` in `networking` namespace  
- `grafana-config` in `monitoring` namespace

#### C. Easy Setup Script

Created `k8s/scripts/setup-vault-secrets.sh`:

```bash
# Interactive script that:
# 1. Sets up port forwarding to Vault
# 2. Prompts for all secrets securely
# 3. Stores them in Vault
# 4. Creates reference documentation
./scripts/setup-vault-secrets.sh
```

#### D. Benefits

✅ **Centralized**: All secrets in one secure location  
✅ **Encrypted**: Secrets encrypted at rest and in transit  
✅ **Audited**: Full audit trail of secret access  
✅ **Automated**: No manual secret updates in YAML  
✅ **Rotatable**: Easy secret rotation without downtime  
✅ **Role-Based**: Fine-grained access control  

### Usage

```bash
# 1. Deploy Vault (included in main deployment)
./deploy.sh

# 2. Configure secrets
./scripts/setup-vault-secrets.sh

# 3. Access Vault UI
http://your-cluster-ip/vault
```

---

## 🧹 3. Docker Cleanup

### Problem
After migrating to Kubernetes, you have old Docker containers, images, and networks taking up space.

### Solution: Comprehensive Cleanup Script

#### A. Docker Cleanup Script
Created `k8s/scripts/docker-cleanup.sh` with:

**Safety Features**:
- Verifies Kubernetes is working before cleanup
- Backs up Docker Compose files first
- Confirms each destructive operation
- Creates detailed cleanup report

**Cleanup Options**:
1. **Stop & Remove Containers**: Safely stops and removes all containers
2. **Remove Networks**: Cleans up custom Docker networks
3. **Remove Volumes**: ⚠️ DESTRUCTIVE - removes Docker volumes
4. **Remove Images**: Cleans up Docker images (can be re-downloaded)
5. **System Cleanup**: Runs `docker system prune -a`
6. **Remove Docker Compose**: Removes Docker Compose binary
7. **Remove Docker Engine**: Complete Docker removal (optional)

#### B. Interactive Menu System

```bash
🧹 Cleanup Options:
1. Stop and remove containers
2. Remove Docker networks  
3. Remove Docker volumes (⚠️ DESTRUCTIVE)
4. Remove Docker images
5. Run system cleanup
6. Remove Docker Compose
7. Remove Docker Engine (⚠️ COMPLETE REMOVAL)
8. Generate cleanup report
9. Exit
```

#### C. Safety Checks

**Pre-Cleanup Verification**:
- Checks if Kubernetes cluster is accessible
- Verifies media server pods are running
- Confirms services are healthy

**Backup Protection**:
- Backs up `compose/` directory
- Saves `.env` files
- Creates timestamped backup folder
- Records backup location

**Confirmation System**:
- Requires explicit "yes" for destructive operations
- Shows what will be affected
- Warns about permanent data loss

#### D. Cleanup Report

Generates detailed report including:
- Pre-cleanup status
- Actions performed
- Backup locations
- Kubernetes status
- Next steps

### Usage

```bash
# Run the interactive cleanup script
./scripts/docker-cleanup.sh

# The script will:
# 1. Verify Kubernetes is working
# 2. Backup Docker files
# 3. Present cleanup menu
# 4. Execute selected operations
# 5. Generate final report
```

---

## 🔄 Migration Workflow

### Complete Migration Process

1. **Pre-Migration**:
   ```bash
   # Backup existing data
   sudo cp -r /storage/docker /storage/docker-backup-$(date +%Y%m%d)
   ```

2. **Deploy Kubernetes**:
   ```bash
   cd k8s
   ./deploy.sh  # Includes Vault and data protection
   ```

3. **Configure Secrets**:
   ```bash
   ./scripts/setup-vault-secrets.sh
   ```

4. **Verify Services**:
   ```bash
   kubectl get pods --all-namespaces
   # Test each service web UI
   ```

5. **Clean Up Docker**:
   ```bash
   ./scripts/docker-cleanup.sh
   ```

### Safety Guarantees

✅ **Data Never Lost**: Retain policies protect all data  
✅ **Secrets Secure**: Vault manages all sensitive data  
✅ **Backup Protected**: Automated daily backups  
✅ **Rollback Possible**: Docker files backed up  
✅ **Verification Required**: Scripts verify Kubernetes works first  

---

## 📋 Quick Reference

### Data Protection Commands
```bash
# Check volume status
kubectl get pv,pvc --all-namespaces

# View backup job
kubectl get cronjob storage-backup

# Check backup logs
kubectl logs -l job-name=storage-backup
```

### Vault Commands
```bash
# Port forward to Vault
kubectl port-forward -n vault-system svc/vault 8200:8200

# Check vault status
kubectl exec -n vault-system vault-0 -- vault status

# List secrets
vault kv list secret/
```

### Docker Cleanup Commands
```bash
# Check Docker usage
docker system df

# List all containers
docker ps -a

# List all volumes
docker volume ls

# Run cleanup script
./scripts/docker-cleanup.sh
```

---

## 🚀 Next Steps

1. **Deploy the enhanced setup**: `./deploy.sh`
2. **Configure secrets**: `./scripts/setup-vault-secrets.sh`  
3. **Verify everything works**: Test all service UIs
4. **Clean up Docker**: `./scripts/docker-cleanup.sh`
5. **Monitor via Rancher**: Access Rancher UI for ongoing management

Your media server is now enterprise-grade with professional secrets management, bulletproof data protection, and clean migration from Docker! 🎉 