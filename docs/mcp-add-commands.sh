#!/bin/bash
# Commands to add MCP servers on your laptop

# Remove any existing configs first (optional)
claude mcp remove grafana-mcp 2>/dev/null
claude mcp remove kubernetes-mcp 2>/dev/null
claude mcp remove k8s-stdio 2>/dev/null

# Add Grafana MCP (this one is confirmed working)
claude mcp add --transport sse grafana-mcp http://grafana-mcp.rinzler.grid

# Add Kubernetes MCP (if it's working now)
claude mcp add --transport sse kubernetes-mcp http://kubernetes-mcp.rinzler.grid

# Add K8s stdio proxy (if deployed and working)
claude mcp add --transport sse k8s-stdio http://k8s-stdio.rinzler.grid/servers/k8s/sse

# List to verify
claude mcp list