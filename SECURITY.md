# Security Configuration

## ⚠️ CRITICAL: Secret Management

This repository follows GitOps principles and **DOES NOT** contain any secrets or sensitive information.

### Required Secrets

The following secrets must be created manually before deploying:

#### 1. Cloudflare API Token (for Let's Encrypt)
```bash
# Run this script to securely create the Cloudflare secret
./scripts/setup-cloudflare-secret.sh
```

**Token Requirements:**
- Zone:DNS:Edit
- Zone:Zone:Read
- Create at: https://dash.cloudflare.com/profile/api-tokens

#### 2. Arr Stack Secrets
```bash
# Create arr-stack secrets
kubectl create secret generic arr-config-secrets \
  --from-literal=jackett-api-key="YOUR_JACKETT_API_KEY" \
  --from-literal=transmission-username="YOUR_USERNAME" \
  --from-literal=transmission-password="YOUR_PASSWORD" \
  --namespace arr-stack
```

#### 3. Service Passwords
```bash
# Generate all service passwords
./scripts/generate-secrets.sh

# Apply to cluster
./scripts/apply-secrets.sh
```

### Security Best Practices

1. **NEVER commit secrets to git**
   - Use `.gitignore` patterns for secret files
   - Review commits before pushing
   - Use `git-secrets` or similar tools

2. **Rotate credentials regularly**
   - API tokens every 90 days
   - Service passwords every 180 days
   - Immediately if compromised

3. **Use minimal permissions**
   - API tokens with only required scopes
   - Service accounts with least privilege
   - Network policies for pod isolation

4. **Monitor access**
   - Check ArgoCD audit logs
   - Review cert-manager logs for cert issues
   - Monitor service authentication attempts

### If Secrets Are Exposed

If you accidentally commit secrets:

1. **Immediately rotate the exposed credentials**
2. Remove from git history:
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch PATH_TO_SECRET_FILE" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. Force push to all remotes
4. Review access logs for unauthorized use
5. Consider the secret permanently compromised

### Checking for Secrets

```bash
# Scan for potential secrets
grep -r "api[_-]key\|password\|secret\|token" k8s/ --exclude="*.md"

# Check git history
git log -p | grep -i "api[_-]key\|password\|secret\|token"
```

### Secret Storage Alternatives

For production environments, consider:
- **Sealed Secrets**: Encrypt secrets that can be stored in git
- **External Secrets Operator**: Sync from HashiCorp Vault, AWS Secrets Manager, etc.
- **SOPS**: Mozilla's encrypted file editor
- **Kubernetes Secrets Store CSI Driver**: Mount secrets from external stores

### Contact

Security issues should be reported privately to the repository maintainer.