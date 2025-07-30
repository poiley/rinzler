# GitOps Architecture with ArgoCD

## Overview
GitOps means your Git repository becomes the "source of truth" for your entire infrastructure. Any changes to your services happen via Git commits, not manual kubectl commands.

## Repository Structure

```
rinzler/
├── k8s/
│   ├── argocd/
│   │   ├── install.yaml          # ArgoCD itself
│   │   └── applications/         # App definitions
│   │       ├── media.yaml
│   │       ├── arr-stack.yaml
│   │       ├── download.yaml
│   │       ├── infrastructure.yaml
│   │       ├── network-services.yaml
│   │       └── home.yaml
│   ├── infrastructure/
│   │   ├── traefik/
│   │   │   ├── values.yaml       # Helm values
│   │   │   └── ingress-routes.yaml
│   │   ├── monitoring/
│   │   │   ├── prometheus.yaml
│   │   │   └── grafana.yaml
│   │   └── uptime-kuma/
│   ├── media/
│   │   ├── namespace.yaml
│   │   ├── plex/
│   │   ├── tautulli/
│   │   └── kavita/
│   ├── arr-stack/
│   │   ├── namespace.yaml
│   │   ├── sonarr/
│   │   ├── radarr/
│   │   └── ...
│   ├── download/
│   │   ├── gluetun-transmission/
│   │   ├── jackett/
│   │   └── ...
```

## How It Works

### 1. Initial Setup
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 2. Application Definition
Each service stack gets an ArgoCD Application:

```yaml
# k8s/argocd/applications/media.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: media
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/rinzler
    targetRevision: main
    path: k8s/media
  destination:
    server: https://kubernetes.default.svc
    namespace: media
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### 3. Service Configuration Example

```yaml
# k8s/media/plex/deployment.yaml  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: plex
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: plex
  template:
    metadata:
      labels:
        app: plex
    spec:
      nodeSelector:
        kubernetes.io/hostname: rinzler
      containers:
      - name: plex
        image: lscr.io/linuxserver/plex:latest
        env:
        - name: PUID
          value: "1000"
        - name: PGID
          value: "1000"
        - name: TZ
          value: "America/Los_Angeles"
        - name: NVIDIA_DRIVER_CAPABILITIES
          value: "compute,video,utility"
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 3Gi
          requests:
            memory: 2Gi
        volumeMounts:
        - name: config
          mountPath: /config
        - name: media
          mountPath: /media
        ports:
        - containerPort: 32400
          name: plex
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: plex-config
      - name: media
        hostPath:
          path: /storage/media
          type: Directory
```

## Workflow

### Making Changes

1. **Edit YAML files** in your local repo:
```bash
cd ~/repos/rinzler
vim k8s/media/plex/deployment.yaml
# Change image tag, resource limits, env vars, etc.
```

2. **Commit and push**:
```bash
git add .
git commit -m "Update Plex memory limit to 4Gi"
git push
```

3. **ArgoCD automatically**:
- Detects the change in Git
- Compares with cluster state
- Updates the deployment
- No manual kubectl needed!

### Adding New Services

1. Create service directory:
```bash
mkdir -p k8s/media/jellyfin
```

2. Add manifests:
- deployment.yaml
- service.yaml
- ingress.yaml

3. Commit and push - ArgoCD deploys it!

## Benefits

### 1. Version Control
- Every change is tracked in Git
- Easy rollbacks: `git revert <commit>`
- Full audit trail

### 2. Declarative
- Git repo shows exact cluster state
- No "drift" between intended and actual

### 3. Self-Healing
- If someone manually changes something, ArgoCD fixes it
- Ensures consistency

### 4. Easy Updates
- Update image tag in YAML
- Commit
- Service updates automatically

### 5. Team Friendly
- PR workflow for changes
- Code review for infrastructure
- No direct cluster access needed

## Migration Path

1. **Phase 1**: Direct manifests (like examples above)
2. **Phase 2**: Helm charts for complex services
3. **Phase 3**: Kustomize for environment variants

## Example: Updating a Service

### Current Docker Compose:
```yaml
sonarr:
  image: lscr.io/linuxserver/sonarr:latest
  environment:
    - PUID=1000
```

### With GitOps:
1. Edit `k8s/arr-stack/sonarr/deployment.yaml`
2. Change image tag: `image: lscr.io/linuxserver/sonarr:4.0.1`
3. Commit: `git commit -m "Update Sonarr to 4.0.1"`
4. Push: `git push`
5. ArgoCD updates Sonarr automatically!

No SSH, no kubectl, no manual work. Just Git!