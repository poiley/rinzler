# Docker Server Configuration

Infrastructure-as-code for personal media server.

## Project Structure

```
.
├── compose/                 # Docker Compose configurations
│   ├── docker-compose.jackett.yml
│   ├── docker-compose.plex.yml
│   └── ...                 # Other service configurations
├── terraform/              # Terraform configurations
│   ├── versions.tf         # Terraform version constraints
│   └── .terraform-version  # tfenv version specification
└── README.md
```

## Setup

1. Clone repository
2. Copy .env.example to .env:
   ```bash
   cp .env.example .env
   ```
3. Edit .env and fill in your secure values:
   - Generate a new WireGuard private key
   - Set a secure Pihole password
   - Generate Base64 encoded credentials for Basic Auth
   - Adjust timezone if needed
   - Set appropriate PUID/PGID for your system
4. Deploy Dockge:
   ```bash
   docker compose -f docker-compose.dockge.yml up -d
   ```
5. Access Dockge at http://localhost:5001
   - Stacks will be automatically detected from the `compose` directory

## Usage

### Docker Compose

To start a service:
```bash
docker compose -f compose/docker-compose.SERVICE.yml up -d
```
Replace `SERVICE` with the service name (e.g., plex, jackett).

### Terraform

Ensure you have the correct Terraform version:
```bash
tfenv install
tfenv use $(cat terraform/.terraform-version)
```

## Requirements

- Docker & Docker Compose
- Terraform >= 1.0.0
- tfenv (recommended)

## Future Enhancements
- [ ] Docker Swarm migration
- [ ] Backup/restore procedures
- [ ] Monitoring and alerting
- [ ] CI/CD pipeline
