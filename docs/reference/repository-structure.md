# Repository Structure & Standards

## 📂 Directory Organization

### Root Level Files
- **README.md** - Project overview and quick links
- **01-installation-guide.md** - Main installation guide (step-by-step)
- **03-deployment-workflow.md** - Complete deployment from scratch
- **02-pre-deployment-checklist.md** - Final configuration checks
- **SECRETS-CONFIGURED.md** - Current secret values status
- **SECRETS-MANAGEMENT.md** - Strategy for handling secrets
- **QUICK-REFERENCE.md** - Common tasks and navigation help
- **REPOSITORY-STRUCTURE.md** - This file
- **.env.secret.example** - Template for secret values
- **.gitignore** - Configured to exclude secrets

### /k8s/ - Kubernetes Manifests
Organized by namespace for logical grouping:
```
k8s/
├── media/              # Media consumption services
│   ├── plex/          # Each service has its own directory
│   ├── tautulli/      # Contains: deployment, service, ingress
│   └── kavita/        # All configs for that service together
├── arr-stack/         # Media automation tools
├── download/          # Download and indexing services
├── infrastructure/    # Platform services (Traefik, ArgoCD)
├── network-services/  # Network utilities (Pi-hole, Samba)
└── home/             # Home automation (Home Assistant)
```

### /scripts/ - Automation Tools
- **README.md** - Detailed script documentation
- **k3s-install.sh** - Main K3s installer
- **nvidia-install.sh** - GPU driver setup
- **server-diagnostics.sh** - System information gathering
- **storage-cleanup.sh** - Disk space management

### /docs/ - Detailed Documentation
- **README.md** - Documentation index with glossary
- **current-server-analysis.md** - Hardware and system specs
- **k3s-migration-strategy.md** - Migration approach
- **traefik-networking.md** - Networking configuration
- **pihole-dns-setup.md** - DNS configuration guide
- Additional strategy and architecture documents

### /compose/ - Docker Reference
Original Docker Compose files preserved for reference during migration.

## 📝 Documentation Standards

### File Naming
- Use kebab-case for all files: `my-document-name.md`
- Be descriptive: `pihole-dns-setup.md` not `dns.md`
- Group related files: `*-strategy.md` for planning docs

### Document Structure
Every documentation file should include:
1. **Title** - Clear, descriptive H1 header
2. **Purpose** - Brief explanation of what the document covers
3. **Prerequisites** - What knowledge/setup is required
4. **Content** - Well-organized with clear headers
5. **Examples** - Code blocks and command examples
6. **Links** - Cross-references to related documents

### Writing Style
- **Clear**: Write for someone unfamiliar with the project
- **Concise**: Get to the point, but don't skip important details
- **Actionable**: Include exact commands and steps
- **Visual**: Use formatting, lists, and code blocks

Example:
```markdown
## Configure DNS

**What this does**: Sets up custom domain names for services.

**Prerequisites**: 
- Pi-hole installed and accessible
- Know your server's IP address

**Steps**:
1. Open Pi-hole admin panel:
   ```
   http://rinzler:8081/admin
   ```

2. Navigate to **Local DNS → DNS Records**
   
3. Add your domain...
```

## 🔧 Code Standards

### Kubernetes Manifests
- Always include resource limits
- Use explicit namespaces
- Add descriptive labels
- Include health checks where applicable

### Scripts
- Start with `#!/bin/bash`
- Include error handling: `set -euo pipefail`
- Add usage instructions in comments
- Use clear variable names
- Provide feedback to user

### Environment Variables
- Document each variable's purpose
- Provide example values
- Group related variables
- Use clear, consistent naming

## ✅ Quality Checklist

Before committing:
- [ ] Documentation is clear and complete
- [ ] All files have descriptive names
- [ ] Cross-references are working
- [ ] Examples are tested and working
- [ ] No temporary or backup files
- [ ] Scripts are executable (`chmod +x`)
- [ ] Secrets are not hardcoded (except for migration)

## 🚀 Maintenance

### Regular Tasks
1. Update documentation when configs change
2. Test scripts after system updates
3. Review and consolidate similar documents
4. Update cross-references when moving files
5. Archive old/unused configurations

### Documentation Review
- Is it still accurate?
- Can it be clearer?
- Are examples up to date?
- Do links still work?
- Is it findable?