# ArgoCD Usage Guide

> **IMPORTANT**: ArgoCD is the ONLY way you should deploy or update services. Never use kubectl directly!

## Why ArgoCD?

ArgoCD implements GitOps - your Git repository is the single source of truth for what should be running in your cluster. This means:

- **No manual kubectl commands** - Everything is managed through Git
- **Automatic deployments** - Push to Git, ArgoCD deploys automatically
- **Self-healing** - If someone manually changes something, ArgoCD fixes it
- **Easy rollbacks** - Just revert the Git commit
- **Audit trail** - Every change is tracked in Git history

## Quick Start Commands

### View All Applications
```bash
kubectl -n argocd get applications
```

### Check Sync Status
```bash
# All apps
kubectl -n argocd get app

# Specific app
kubectl -n argocd get app media
```

### Access ArgoCD UI
```bash
# Port forward (local access)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Then open https://localhost:8080

# Or use the ingress (if DNS configured)
# http://argocd.rinzler.grid
```

## Common Tasks

### Making Changes to Services

**NEVER** edit services with kubectl! Always use Git:

1. **Edit the YAML file**:
   ```bash
   cd ~/rinzler
   vim k8s/media/plex/deployment.yaml
   ```

2. **Commit and push**:
   ```bash
   git add -A
   git commit -m "Update Plex to version X.Y.Z"
   git push
   ```

3. **ArgoCD automatically syncs** (usually within 3 minutes)

4. **Force immediate sync if needed**:
   ```bash
   kubectl -n argocd app sync media
   ```

### Adding a New Service

1. **Create service directory**:
   ```bash
   mkdir -p k8s/media/new-service
   ```

2. **Add Kubernetes manifests**:
   - deployment.yaml
   - service.yaml  
   - ingress.yaml
   - pvc.yaml (if needed)

3. **Update or create ArgoCD application**:
   - If part of existing app (e.g., media stack), just push
   - If new stack, create application in `k8s/argocd/applications/`

4. **Commit and push** - ArgoCD handles the rest!

### Updating Service Versions

Example: Update Sonarr to a new version

```bash
# Edit the deployment
vim k8s/arr-stack/sonarr/deployment.yaml

# Change the image tag
# From: image: lscr.io/linuxserver/sonarr:latest
# To:   image: lscr.io/linuxserver/sonarr:4.0.1

# Commit and push
git add -A
git commit -m "Update Sonarr to 4.0.1"
git push
```

### Rolling Back Changes

Since everything is in Git:

```bash
# Find the commit to rollback
git log --oneline

# Revert the commit
git revert abc1234

# Push
git push

# ArgoCD automatically rolls back the service
```

### Debugging Sync Issues

```bash
# Check app details
kubectl -n argocd describe app media

# View sync status
kubectl -n argocd get app media -o yaml

# Check events
kubectl -n argocd events --for app/media
```

## ArgoCD Applications Structure

Each application watches a specific directory:

| Application | Git Path | Namespace | Services |
|------------|----------|-----------|----------|
| media | k8s/media/ | media | Plex, Tautulli, Kavita |
| arr-stack | k8s/arr-stack/ | arr-stack | Sonarr, Radarr, Lidarr, etc |
| download | k8s/download/ | download | Transmission, Jackett |
| infrastructure | k8s/infrastructure/ | infrastructure | Traefik, DuckDNS |
| network-services | k8s/network-services/ | network-services | Pi-hole, Samba |
| home | k8s/home/ | home | Home Assistant |

## Advanced Operations

### Enable Auto-Sync

By default, ArgoCD syncs every 3 minutes. To enable immediate auto-sync:

```bash
# For a single app
kubectl -n argocd patch app media --type merge -p \
  '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# For all apps
for app in media arr-stack download infrastructure network-services home; do
  kubectl -n argocd patch app $app --type merge -p \
    '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
done
```

### Disable Auto-Sync (for testing)

```bash
kubectl -n argocd patch app media --type merge -p \
  '{"spec":{"syncPolicy":null}}'
```

### Refresh Application (re-read from Git)

```bash
kubectl -n argocd app get media --refresh
```

### Sync with Prune

Remove resources that aren't in Git anymore:

```bash
kubectl -n argocd app sync media --prune
```

## Best Practices

### DO ✅

1. **Always use Git** for changes
2. **Test in a dev branch** first (optional)
3. **Use meaningful commit messages**
4. **Check ArgoCD UI** after pushing
5. **Let ArgoCD manage** resource lifecycle

### DON'T ❌

1. **Never use kubectl apply** directly
2. **Don't kubectl edit** resources
3. **Don't kubectl delete** managed resources
4. **Don't make emergency fixes** without Git
5. **Don't bypass ArgoCD** "just this once"

## Emergency Procedures

### If ArgoCD is Down

1. **Check ArgoCD pods**:
   ```bash
   kubectl -n argocd get pods
   ```

2. **Restart ArgoCD if needed**:
   ```bash
   kubectl -n argocd rollout restart deployment argocd-server
   ```

3. **Only if absolutely critical**, you can temporarily:
   ```bash
   # Disable ArgoCD sync for the app
   kubectl -n argocd patch app media --type merge -p \
     '{"spec":{"syncPolicy":null}}'
   
   # Make emergency change
   kubectl apply -f k8s/media/plex/
   
   # Fix in Git immediately after!
   # Re-enable ArgoCD sync
   ```

### Service Won't Sync

1. Check application status:
   ```bash
   kubectl -n argocd get app media
   ```

2. Look for sync errors:
   ```bash
   kubectl -n argocd describe app media
   ```

3. Common fixes:
   - Invalid YAML syntax - fix in Git
   - Resource conflicts - check if manually created
   - Missing namespace - ensure it exists
   - Invalid image - check tag exists

## Monitoring ArgoCD

### CLI Monitoring
```bash
# Watch all apps
watch kubectl -n argocd get applications

# Check specific app health
kubectl -n argocd get app media -o jsonpath='{.status.health.status}'
```

### Metrics and Alerts

ArgoCD exposes Prometheus metrics:
- Application sync status
- Sync operation duration  
- Git webhook events
- Controller performance

## FAQ

**Q: How quickly does ArgoCD sync after a Git push?**
A: By default, every 3 minutes. With webhooks or auto-sync, it's nearly instant.

**Q: Can I use branches for environments?**
A: Yes! You can point ArgoCD apps to different branches (dev, staging, prod).

**Q: What if I need to make an emergency fix?**
A: Make the fix in Git and push. If truly critical, see Emergency Procedures above.

**Q: How do I know if a deployment succeeded?**
A: Check the ArgoCD UI or run `kubectl -n argocd get app <name>`

**Q: Can ArgoCD manage Helm charts?**
A: Yes! Just point the application to a Helm chart directory.

## Summary

Remember: **Git is the source of truth**. Never circumvent ArgoCD except in true emergencies, and always reconcile changes back to Git immediately.

For more details, see:
- [GitOps Architecture](../gitops-architecture.md)
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)