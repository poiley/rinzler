# Complete Deployment Workflow

## On Your Local Machine

### 1. Prepare Secrets File
```bash
# Create your real secrets file (ONE TIME)
cp .env.secret.example .env.secret
nano .env.secret  # Add your actual values

# This file contains your real passwords/tokens
# NEVER commit this file!
```

### 2. Copy Secrets to Server
```bash
# Copy the secrets file to your server
scp .env.secret user@rinzler:~/

# Or if using SSH key
scp -i ~/.ssh/your-key .env.secret user@rinzler:~/
```

## On Your Server

### 3. Clone and Deploy
```bash
# Clone the repository
git clone https://github.com/yourusername/rinzler.git
cd rinzler

# Move the secrets file into place
mv ~/.env.secret .

# Generate Kubernetes secrets
./scripts/generate-secrets.sh

# Install K3s
sudo ./scripts/k3s-install.sh

# Install ArgoCD for GitOps management
./scripts/install-argocd.sh

# Apply the generated secrets
kubectl apply -f k8s-generated/secrets/

# Deploy ALL services with ArgoCD (one command!)
kubectl apply -f k8s/argocd/applications/
```

## Complete Server Commands

Here's a single script you can run on the server:

```bash
#!/bin/bash
# deploy-from-scratch.sh

# Ensure .env.secret exists
if [ ! -f ".env.secret" ]; then
    echo "Error: .env.secret not found!"
    echo "Copy it from your local machine first"
    exit 1
fi

# Generate secrets
./scripts/generate-secrets.sh

# Install K3s
sudo ./scripts/k3s-install.sh

# Wait for K3s to be ready
sleep 30
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install ArgoCD
./scripts/install-argocd.sh

# Apply secrets first
kubectl apply -f k8s-generated/secrets/

# Deploy ALL services with ArgoCD
kubectl apply -f k8s/argocd/applications/

echo "Deployment complete!"
echo "ArgoCD is now managing all services"
echo "Configure DNS for .grid domain in Pi-hole"
echo "Access ArgoCD at http://argocd.rinzler.grid"
```

## What Gets Committed vs What Doesn't

### ✅ In Git (Safe to Commit)
- All K8s manifests with hardcoded values (for now)
- `.env.secret.example` (template)
- `scripts/generate-secrets.sh`
- All documentation
- `.gitignore` (excludes secrets)

### ❌ NOT in Git (Local Only)
- `.env.secret` (your real passwords)
- `k8s-generated/` directory
- Any `*-secret.yaml` files

## For Public Repository Users

They would:
1. Clone your repo
2. Copy `.env.secret.example` to `.env.secret`
3. Edit with their values
4. Run the same deployment process

## Important Notes

1. **Current State**: Your manifests still have hardcoded values, so everything works immediately
2. **Future State**: When you update manifests to use secrets, the workflow remains the same
3. **Backup**: Keep a backup of your `.env.secret` file somewhere safe
4. **Security**: The `.env.secret` file is the ONLY thing that needs to be kept private

## Quick Verification

Before pushing to GitHub:
```bash
# Make sure secrets aren't staged
git status
# Should NOT show .env.secret or k8s-generated/

# Check .gitignore is working
git check-ignore .env.secret
# Should output: .env.secret
```

## One-Liner Deploy (After Setup)

Once `.env.secret` is on the server:
```bash
cd rinzler && ./scripts/generate-secrets.sh && kubectl apply -f k8s-generated/secrets/ && kubectl apply -f k8s/argocd/applications/
```

## Why ArgoCD Instead of kubectl?

### ❌ Old Way (Manual kubectl)
- Run kubectl for each service
- Easy to forget a service
- No automatic updates
- Manual rollbacks
- No sync verification

### ✅ New Way (ArgoCD GitOps)
- One command deploys everything
- Git commits trigger updates
- Automatic sync from Git
- Self-healing deployments
- Easy rollbacks via Git
- Visual UI for monitoring

## Making Changes After Deployment

**Never use kubectl to edit services!** Instead:

1. Edit the YAML file in `k8s/`
2. Commit and push to Git
3. ArgoCD automatically applies changes

Example:
```bash
# Update Plex memory limit
vim k8s/media/plex/deployment.yaml
git add -A
git commit -m "Increase Plex memory to 4Gi"
git push

# ArgoCD detects and applies the change automatically!
```