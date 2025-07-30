# Secrets Management Strategy

## Recommended Approach: Environment Variable Injection

### 1. Create a `.env.secret` File (Git-Ignored)
```bash
# .env.secret - NEVER COMMIT THIS FILE
PIHOLE_PASSWORD=your-actual-password
MULLVAD_PRIVATE_KEY=your-actual-vpn-key
MULLVAD_IP=10.64.197.249/32
DUCKDNS_TOKEN=your-actual-token
SAMBA_USER=poile
SAMBA_PASS=your-actual-password
PLEX_USER=your.email@example.com
```

### 2. Use ConfigMaps and Secrets Templates

Create template files that reference environment variables:

**k8s/infrastructure/secrets/secrets-template.yaml**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: pihole-secrets
  namespace: network-services
type: Opaque
stringData:
  webpassword: ${PIHOLE_PASSWORD}
---
apiVersion: v1
kind: Secret
metadata:
  name: mullvad-secrets
  namespace: download
type: Opaque
stringData:
  private-key: ${MULLVAD_PRIVATE_KEY}
  addresses: ${MULLVAD_IP}
---
apiVersion: v1
kind: Secret
metadata:
  name: duckdns-secrets
  namespace: infrastructure
type: Opaque
stringData:
  token: ${DUCKDNS_TOKEN}
```

### 3. Use envsubst to Generate Real Secrets

Create a script to generate secrets from templates:

**scripts/generate-secrets.sh**:
```bash
#!/bin/bash
set -euo pipefail

# Source the secret environment file
if [ ! -f ".env.secret" ]; then
    echo "Error: .env.secret file not found!"
    echo "Copy .env.secret.example to .env.secret and fill in your values"
    exit 1
fi

source .env.secret

# Create output directory
mkdir -p k8s-generated/secrets

# Generate secrets from templates
for template in k8s/infrastructure/secrets/*-template.yaml; do
    output_file="k8s-generated/secrets/$(basename "$template" -template.yaml).yaml"
    echo "Generating $output_file..."
    envsubst < "$template" > "$output_file"
done

echo "Secrets generated in k8s-generated/secrets/"
echo "Apply with: kubectl apply -f k8s-generated/secrets/"
```

### 4. Update Deployments to Use Secrets

**Before** (hardcoded):
```yaml
env:
- name: WEBPASSWORD
  value: "password"
```

**After** (using secrets):
```yaml
env:
- name: WEBPASSWORD
  valueFrom:
    secretKeyRef:
      name: pihole-secrets
      key: webpassword
```

### 5. Create Example Files for Public Repo

**.env.secret.example**:
```bash
# Copy this to .env.secret and fill in your actual values
PIHOLE_PASSWORD=change-me
MULLVAD_PRIVATE_KEY=get-from-mullvad-account
MULLVAD_IP=10.x.x.x/32
DUCKDNS_TOKEN=get-from-duckdns.org
SAMBA_USER=your-username
SAMBA_PASS=your-password
PLEX_USER=your-plex-email
```

## Alternative Approaches

### Option 1: Sealed Secrets
Use Bitnami Sealed Secrets to encrypt secrets in the repo:
```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create a secret
echo -n "mypassword" | kubectl create secret generic pihole-secret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > pihole-sealed-secret.yaml
```

### Option 2: SOPS (Secrets Operations)
Encrypt secret files with Mozilla SOPS:
```bash
# Install sops
brew install sops

# Create a .sops.yaml config
creation_rules:
  - path_regex: .*secret.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    key_groups:
    - age:
      - age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Encrypt secrets
sops -e secrets.yaml > secrets.enc.yaml
```

### Option 3: External Secrets Operator
Pull secrets from external systems:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: pihole-secret
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: pihole-secret
  data:
  - secretKey: password
    remoteRef:
      key: secret/data/pihole
      property: password
```

## Repository Structure for Secrets

```
rinzler/
├── .gitignore                    # MUST include .env.secret and k8s-generated/
├── .env.secret.example           # Template for users
├── k8s/
│   └── infrastructure/
│       └── secrets/
│           └── *-template.yaml   # Secret templates with ${VARS}
├── k8s-generated/               # Generated files (git-ignored)
│   └── secrets/
│       └── *.yaml               # Actual secrets with real values
└── scripts/
    └── generate-secrets.sh      # Script to process templates
```

## .gitignore Updates

```gitignore
# Secrets - NEVER commit these
.env.secret
.env.local
*.secret
*-secret.yaml
k8s-generated/

# But DO commit these
!.env.secret.example
!*-template.yaml
```

## Migration Path

1. **Phase 1**: Keep hardcoded values for initial deployment (current state)
2. **Phase 2**: Test secret generation locally
3. **Phase 3**: Update deployments to use secrets
4. **Phase 4**: Remove hardcoded values from deployments
5. **Phase 5**: Commit cleaned manifests

## Benefits

1. **Security**: Real secrets never in Git
2. **Usability**: Others can use your configs with their values
3. **Maintainability**: One place to update secrets
4. **Flexibility**: Easy to switch between environments
5. **Shareability**: Safe to make repository public

## For Public Repository Users

Add this to your README:

```markdown
## Setting Up Secrets

1. Copy the example file:
   ```bash
   cp .env.secret.example .env.secret
   ```

2. Edit `.env.secret` with your values:
   ```bash
   nano .env.secret
   ```

3. Generate Kubernetes secrets:
   ```bash
   ./scripts/generate-secrets.sh
   ```

4. Apply secrets before deploying services:
   ```bash
   kubectl apply -f k8s-generated/secrets/
   ```
```