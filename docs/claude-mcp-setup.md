# Claude Code MCP Server Configuration

## Prerequisites
- Machine must be on the same network
- Can resolve `.rinzler.grid` domains (either via PiHole DNS or hosts file)

## Available MCP Servers

### 1. Kubernetes MCP (SSE)
- **URL**: `http://kubernetes-mcp.rinzler.grid`
- **Purpose**: Kubernetes cluster management
- **Transport**: SSE

### 2. Grafana MCP (SSE)
- **URL**: `http://grafana-mcp.rinzler.grid`
- **Purpose**: Grafana dashboard and datasource management
- **Transport**: SSE

### 3. K8s MCP via Proxy (SSE) - If deployed
- **URL**: `http://k8s-stdio.rinzler.grid/servers/k8s/sse`
- **Purpose**: Alternative Kubernetes management via stdio bridge
- **Transport**: SSE

## Setup Instructions

### Option 1: Using Claude CLI Commands

```bash
# Add Kubernetes MCP server
claude mcp add --transport sse kubernetes-mcp http://kubernetes-mcp.rinzler.grid

# Add Grafana MCP server
claude mcp add --transport sse grafana-mcp http://grafana-mcp.rinzler.grid

# Add K8s stdio proxy (if available)
claude mcp add --transport sse k8s-stdio http://k8s-stdio.rinzler.grid/servers/k8s/sse

# List configured servers
claude mcp list
```

### Option 2: Manual Configuration

Edit `~/.claude.json` or your project's `.claude.json` and add:

```json
{
  "mcpServers": {
    "kubernetes-mcp": {
      "type": "sse",
      "url": "http://kubernetes-mcp.rinzler.grid"
    },
    "grafana-mcp": {
      "type": "sse",
      "url": "http://grafana-mcp.rinzler.grid"
    }
  }
}
```

## DNS Configuration

If `.rinzler.grid` domains don't resolve, add to `/etc/hosts`:

```bash
# Rinzler MCP Servers
192.168.1.227 kubernetes-mcp.rinzler.grid
192.168.1.227 grafana-mcp.rinzler.grid
192.168.1.227 k8s-stdio.rinzler.grid
```

Or configure DNS to use PiHole at `192.168.1.227`.

## Testing Connection

1. Test DNS resolution:
```bash
nslookup kubernetes-mcp.rinzler.grid
```

2. Test HTTP connectivity:
```bash
curl -I http://kubernetes-mcp.rinzler.grid
```

3. Test SSE endpoint:
```bash
curl -N -H "Accept: text/event-stream" http://kubernetes-mcp.rinzler.grid/sse
```

## Usage in Claude

Once configured, you can use commands like:
- `/mcp kubernetes-mcp "list all pods"`
- `/mcp grafana-mcp "list dashboards"`

## Troubleshooting

1. **"Failed to connect" in `claude mcp list`**
   - This is often a false negative if the health check format differs
   - Test the SSE endpoint directly with curl

2. **DNS not resolving**
   - Ensure machine is using PiHole DNS (192.168.1.227)
   - Or add entries to /etc/hosts

3. **Connection refused**
   - Check if services are running: `curl http://IP:PORT`
   - Verify ingress is properly configured