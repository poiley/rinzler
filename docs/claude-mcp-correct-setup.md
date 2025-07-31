# Claude MCP Server Setup - Correct Approach

## Important: Claude Desktop vs Claude CLI

**Claude Desktop** only supports **stdio** MCP servers (NOT HTTP/SSE).
**Claude CLI** has issues with stdio servers due to protocolVersion bug.

## For Your Laptop (Claude Desktop)

### Option 1: Local Installation (Recommended)

1. **Install kubectl-mcp-tool locally:**
```bash
pip install kubectl-mcp-tool
```

2. **Configure Claude Desktop:**
Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (Mac) or equivalent:

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "python",
      "args": ["-m", "kubectl_mcp_tool.mcp_server"],
      "env": {
        "KUBECONFIG": "/path/to/your/.kube/config"
      }
    }
  }
}
```

3. **Restart Claude Desktop**

### Option 2: Using Docker Locally

```bash
# Pull the image
docker pull rohitghumare64/kubectl-mcp-server:latest

# Run with your kubeconfig mounted
docker run -it --rm \
  -v $HOME/.kube:/root/.kube \
  rohitghumare64/kubectl-mcp-server:latest
```

Then configure Claude Desktop to use the docker command.

## For Claude CLI

Currently, Claude CLI has issues with stdio servers. The HTTP/SSE servers we deployed won't work because:
1. They don't implement Claude's registration protocol
2. Claude CLI expects specific endpoints that don't exist

## Summary

- **Use local stdio MCP servers with Claude Desktop**
- **The Kubernetes deployments we created won't work with Claude**
- **For remote MCP access, you need a stdio-to-HTTP bridge running locally**

## What's in Your Cluster

You still have:
- `grafana-mcp` - Running but incompatible with Claude
- `k8s-mcp-server` - stdio server, can't be accessed via HTTP

These can be removed as they won't work with Claude's current implementation.