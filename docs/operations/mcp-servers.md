# MCP Servers Configuration

## Available MCP Servers

### 1. Kubernetes MCP Server (stdio transport)
- **Type**: stdio-based MCP server
- **Purpose**: Kubernetes cluster management and operations
- **Capabilities**: 
  - kubectl commands
  - ArgoCD operations
  - Cluster resource management

### 2. Grafana MCP Server  
- **Type**: HTTP-based MCP server
- **URL**: `http://grafana-mcp.rinzler.grid`
- **Purpose**: Grafana dashboard and datasource management
- **Capabilities**:
  - Dashboard creation/modification
  - Datasource configuration
  - Alert management

## Adding to Claude

### For k8s-mcp-server (stdio transport):
Since this uses stdio transport, you need to run it locally:

```bash
# Option 1: Port forward and run locally
kubectl port-forward -n mcp-servers svc/k8s-mcp-server 8080:8080

# Option 2: Extract and run the server binary locally
# (Requires downloading the k8s-mcp-server binary)
```

### For grafana-mcp (HTTP transport):
```bash
claude mcp add --transport http grafana-mcp http://grafana-mcp.rinzler.grid
```

## Network Requirements

- Add entries to `/etc/hosts` for `.rinzler.grid` domains pointing to `192.168.1.227`
- k8s-mcp-server uses stdio transport (not HTTP accessible)
- grafana-mcp uses HTTP transport

## Current Status
- k8s-mcp-server: Running in cluster but needs local execution or port-forwarding for Claude
- grafana-mcp: Should be directly accessible via HTTP