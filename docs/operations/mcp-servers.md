# MCP Servers Configuration

## Available MCP Servers

### 1. Kubernetes MCP Server
- **URL**: `http://k8s-mcp.rinzler.grid`
- **Purpose**: Kubernetes cluster management and operations
- **Capabilities**: 
  - kubectl commands
  - ArgoCD operations
  - Cluster resource management

### 2. Grafana MCP Server  
- **URL**: `http://grafana-mcp.rinzler.grid`
- **Purpose**: Grafana dashboard and datasource management
- **Capabilities**:
  - Dashboard creation/modification
  - Datasource configuration
  - Alert management

## Adding to Claude

To add these MCP servers to Claude:

1. Open Claude Desktop settings
2. Navigate to MCP Servers configuration
3. Add each server with its URL:
   - Name: `k8s-mcp`
   - URL: `http://k8s-mcp.rinzler.grid`
   
   - Name: `grafana-mcp`
   - URL: `http://grafana-mcp.rinzler.grid`

## Network Requirements

- Ensure your machine can resolve `.rinzler.grid` domains
- Both servers are accessible on the local network only
- No authentication required for local access

## Verification

Test connectivity:
```bash
curl http://k8s-mcp.rinzler.grid/health
curl http://grafana-mcp.rinzler.grid/health
```