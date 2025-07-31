# MCP Server Connection Test

## Overview
We have two MCP servers deployed in Kubernetes that need to be tested from a machine with access to `.rinzler.grid` domain.

## MCP Servers
1. **k8s-mcp-server**: `http://k8s-mcp.rinzler.grid`
   - Kubernetes management operations
   - Should be running on port 8080

2. **grafana-mcp**: `http://grafana-mcp.rinzler.grid`  
   - Grafana dashboard management
   - Should be running on port 80

## Testing Steps

1. **Test DNS Resolution**:
   ```bash
   nslookup k8s-mcp.rinzler.grid
   nslookup grafana-mcp.rinzler.grid
   ```

2. **Test HTTP Connectivity**:
   ```bash
   curl -v http://k8s-mcp.rinzler.grid
   curl -v http://grafana-mcp.rinzler.grid
   ```

3. **Add to Claude CLI**:
   ```bash
   claude mcp add --transport http k8s-mcp http://k8s-mcp.rinzler.grid
   claude mcp add --transport http grafana-mcp http://grafana-mcp.rinzler.grid
   ```

4. **Verify Configuration**:
   ```bash
   claude mcp list
   ```

## Expected Results
- DNS should resolve to `192.168.1.227`
- HTTP requests might fail (MCP uses stdio, not HTTP)
- Claude should show both servers configured

## Troubleshooting
If DNS doesn't resolve, check:
- Is PiHole configured as DNS server?
- Can you access other `.rinzler.grid` services like `argocd.rinzler.grid`?
- Try using IP directly: `http://192.168.1.227` with appropriate port