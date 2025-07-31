# MCP Connection Debug Tests

Run these commands from your laptop to help debug the connection:

## 1. Test Grafana MCP SSE endpoint (this one should work):
```bash
curl -v -N -H "Accept: text/event-stream" http://grafana-mcp.rinzler.grid/sse 2>&1 | head -20
```

## 2. Check if you can reach the services:
```bash
# Should show the HTML response or connection info
curl -v http://grafana-mcp.rinzler.grid 2>&1 | grep -E "(Connected|HTTP|<)"
```

## 3. Test with a simple HTTP request to see the response:
```bash
# This should show what the MCP server returns
curl -s http://grafana-mcp.rinzler.grid/ | head -20
```

## 4. Check your Claude configuration:
```bash
cat ~/.claude.json | grep -A 10 "mcpServers"
```

## 5. Try a direct SSE connection test:
```bash
# This will connect and wait for events
timeout 5 curl -N -H "Accept: text/event-stream" http://grafana-mcp.rinzler.grid/sse
```

## 6. Check DNS resolution:
```bash
dig grafana-mcp.rinzler.grid +short
# or
nslookup grafana-mcp.rinzler.grid
```

Share the output of these commands so we can see what's happening.