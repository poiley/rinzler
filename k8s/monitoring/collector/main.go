package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

type ServiceStatus struct {
	Name         string    `json:"name"`
	Type         string    `json:"type"`
	Healthy      bool      `json:"healthy"`
	LastChecked  time.Time `json:"lastChecked"`
	Message      string    `json:"message"`
	Details      map[string]interface{} `json:"details"`
}

type Dashboard struct {
	Services map[string]*ServiceStatus `json:"services"`
	mu       sync.RWMutex
}

type Config struct {
	PlexURL           string
	PlexToken         string
	RadarrURL         string
	RadarrAPIKey      string
	SonarrURL         string
	SonarrAPIKey      string
	ReadarrURL        string
	ReadarrAPIKey     string
	LidarrURL         string
	LidarrAPIKey      string
	BazarrURL         string
	BazarrAPIKey      string
	JackettURL        string
	JackettAPIKey     string
	TransmissionURL   string
	TransmissionUser  string
	TransmissionPass  string
	ArgoURL           string
	ArgoToken         string
	TautulliURL       string
	TautulliAPIKey    string
}

func loadConfig() *Config {
	return &Config{
		PlexURL:           getEnvOrDefault("PLEX_URL", "http://plex.media:32400"),
		PlexToken:         os.Getenv("PLEX_TOKEN"),
		RadarrURL:         getEnvOrDefault("RADARR_URL", "http://radarr.arr-stack:7878"),
		RadarrAPIKey:      os.Getenv("RADARR_API_KEY"),
		SonarrURL:         getEnvOrDefault("SONARR_URL", "http://sonarr.arr-stack:8989"),
		SonarrAPIKey:      os.Getenv("SONARR_API_KEY"),
		ReadarrURL:        getEnvOrDefault("READARR_URL", "http://readarr.arr-stack:8787"),
		ReadarrAPIKey:     os.Getenv("READARR_API_KEY"),
		LidarrURL:         getEnvOrDefault("LIDARR_URL", "http://lidarr.arr-stack:8686"),
		LidarrAPIKey:      os.Getenv("LIDARR_API_KEY"),
		BazarrURL:         getEnvOrDefault("BAZARR_URL", "http://bazarr.arr-stack:6767"),
		BazarrAPIKey:      os.Getenv("BAZARR_API_KEY"),
		JackettURL:        getEnvOrDefault("JACKETT_URL", "http://jackett.download:9117"),
		JackettAPIKey:     os.Getenv("JACKETT_API_KEY"),
		TransmissionURL:   getEnvOrDefault("TRANSMISSION_URL", "http://gluetun-transmission.download:9091"),
		TransmissionUser:  os.Getenv("TRANSMISSION_USER"),
		TransmissionPass:  os.Getenv("TRANSMISSION_PASS"),
		ArgoURL:           getEnvOrDefault("ARGO_URL", "http://argocd-server.argocd:8080"),
		ArgoToken:         os.Getenv("ARGO_TOKEN"),
		TautulliURL:       getEnvOrDefault("TAUTULLI_URL", "http://tautulli.media:8181"),
		TautulliAPIKey:    os.Getenv("TAUTULLI_API_KEY"),
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func (d *Dashboard) updateService(name, serviceType string, healthy bool, message string, details map[string]interface{}) {
	d.mu.Lock()
	defer d.mu.Unlock()
	
	d.Services[name] = &ServiceStatus{
		Name:        name,
		Type:        serviceType,
		Healthy:     healthy,
		LastChecked: time.Now(),
		Message:     message,
		Details:     details,
	}
}

func (d *Dashboard) checkPlexHealth(config *Config) {
	if config.PlexToken == "" {
		d.updateService("plex", "media", false, "No API token configured", nil)
		return
	}

	url := fmt.Sprintf("%s/?X-Plex-Token=%s", config.PlexURL, config.PlexToken)
	resp, err := http.Get(url)
	if err != nil {
		d.updateService("plex", "media", false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		d.updateService("plex", "media", true, "Server is running", map[string]interface{}{
			"version": resp.Header.Get("X-Plex-Version"),
		})
	} else {
		d.updateService("plex", "media", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
	}
}

func (d *Dashboard) checkArrHealth(name, url, apiKey, serviceType string) {
	if apiKey == "" {
		d.updateService(name, serviceType, false, "No API key configured", nil)
		return
	}

	details := make(map[string]interface{})
	
	// Check health endpoint
	healthURL := fmt.Sprintf("%s/api/v3/health?apiKey=%s", url, apiKey)
	resp, err := http.Get(healthURL)
	if err != nil {
		d.updateService(name, serviceType, false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var healthItems []map[string]interface{}
	healthOK := true
	healthMessage := "All systems operational"
	
	if err := json.Unmarshal(body, &healthItems); err == nil {
		if len(healthItems) > 0 {
			healthOK = false
			healthMessage = fmt.Sprintf("%d health issues detected", len(healthItems))
			details["health_issues"] = healthItems
		}
	}

	// Check queue
	queueURL := fmt.Sprintf("%s/api/v3/queue?apiKey=%s", url, apiKey)
	resp, err = http.Get(queueURL)
	if err == nil {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		var queueData map[string]interface{}
		if json.Unmarshal(body, &queueData) == nil {
			if records, ok := queueData["records"].([]interface{}); ok {
				details["queue_size"] = len(records)
			}
		}
	}

	// Check system status
	statusURL := fmt.Sprintf("%s/api/v3/system/status?apiKey=%s", url, apiKey)
	resp, err = http.Get(statusURL)
	if err == nil {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		var statusData map[string]interface{}
		if json.Unmarshal(body, &statusData) == nil {
			if version, ok := statusData["version"].(string); ok {
				details["version"] = version
			}
		}
	}

	d.updateService(name, serviceType, healthOK, healthMessage, details)
}

func (d *Dashboard) checkTransmissionHealth(config *Config) {
	// Simple health check - just see if we can connect
	resp, err := http.Get(config.TransmissionURL + "/transmission/web/")
	if err != nil {
		d.updateService("transmission", "download", false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 || resp.StatusCode == 301 || resp.StatusCode == 302 {
		d.updateService("transmission", "download", true, "Web UI accessible", nil)
	} else {
		d.updateService("transmission", "download", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
	}
}

func (d *Dashboard) checkArgoHealth(config *Config) {
	if config.ArgoToken == "" {
		// Try without auth first
		resp, err := http.Get(config.ArgoURL + "/api/v1/session")
		if err != nil {
			d.updateService("argocd", "infrastructure", false, fmt.Sprintf("Connection error: %v", err), nil)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode == 200 {
			d.updateService("argocd", "infrastructure", true, "API accessible (no auth)", nil)
		} else {
			d.updateService("argocd", "infrastructure", false, "No token configured", nil)
		}
		return
	}

	// Check with auth
	req, _ := http.NewRequest("GET", config.ArgoURL+"/api/v1/applications", nil)
	req.Header.Add("Authorization", "Bearer "+config.ArgoToken)
	
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		d.updateService("argocd", "infrastructure", false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		body, _ := io.ReadAll(resp.Body)
		var appList map[string]interface{}
		details := make(map[string]interface{})
		
		if json.Unmarshal(body, &appList) == nil {
			if items, ok := appList["items"].([]interface{}); ok {
				synced := 0
				outOfSync := 0
				degraded := 0
				
				for _, item := range items {
					if app, ok := item.(map[string]interface{}); ok {
						if status, ok := app["status"].(map[string]interface{}); ok {
							if sync, ok := status["sync"].(map[string]interface{}); ok {
								if syncStatus, ok := sync["status"].(string); ok {
									switch syncStatus {
									case "Synced":
										synced++
									case "OutOfSync":
										outOfSync++
									}
								}
							}
							if health, ok := status["health"].(map[string]interface{}); ok {
								if healthStatus, ok := health["status"].(string); ok {
									if healthStatus == "Degraded" {
										degraded++
									}
								}
							}
						}
					}
				}
				
				details["total_apps"] = len(items)
				details["synced"] = synced
				details["out_of_sync"] = outOfSync
				details["degraded"] = degraded
			}
		}
		
		d.updateService("argocd", "infrastructure", true, "Connected to ArgoCD", details)
	} else {
		d.updateService("argocd", "infrastructure", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
	}
}

func (d *Dashboard) checkBazarrHealth(config *Config) {
	if config.BazarrAPIKey == "" {
		d.updateService("bazarr", "arr-stack", false, "No API key configured", nil)
		return
	}

	// Bazarr uses a different API structure
	healthURL := fmt.Sprintf("%s/api/system/health?apikey=%s", config.BazarrURL, config.BazarrAPIKey)
	resp, err := http.Get(healthURL)
	if err != nil {
		d.updateService("bazarr", "arr-stack", false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	details := make(map[string]interface{})
	
	if resp.StatusCode == 200 {
		// Get system status
		statusURL := fmt.Sprintf("%s/api/system/status?apikey=%s", config.BazarrURL, config.BazarrAPIKey)
		resp2, err := http.Get(statusURL)
		if err == nil {
			defer resp2.Body.Close()
			body, _ := io.ReadAll(resp2.Body)
			var statusData map[string]interface{}
			if json.Unmarshal(body, &statusData) == nil {
				if data, ok := statusData["data"].(map[string]interface{}); ok {
					if version, ok := data["bazarr_version"].(string); ok {
						details["version"] = version
					}
				}
			}
		}
		
		d.updateService("bazarr", "arr-stack", true, "Service is running", details)
	} else {
		d.updateService("bazarr", "arr-stack", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
	}
}

func (d *Dashboard) checkJackettHealth(config *Config) {
	// Jackett health check
	healthURL := config.JackettURL + "/UI/Dashboard"
	if config.JackettAPIKey != "" {
		healthURL = fmt.Sprintf("%s/api/v2.0/indexers/all/results?apikey=%s", config.JackettURL, config.JackettAPIKey)
	}
	
	resp, err := http.Get(healthURL)
	if err != nil {
		d.updateService("jackett", "download", false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		d.updateService("jackett", "download", true, "Service is running", nil)
	} else {
		d.updateService("jackett", "download", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
	}
}

func (d *Dashboard) checkTautulliHealth(config *Config) {
	if config.TautulliAPIKey == "" {
		// Try basic health check
		resp, err := http.Get(config.TautulliURL)
		if err != nil {
			d.updateService("tautulli", "media", false, fmt.Sprintf("Connection error: %v", err), nil)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode == 200 {
			d.updateService("tautulli", "media", true, "Web UI accessible", nil)
		} else {
			d.updateService("tautulli", "media", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
		}
		return
	}

	// With API key, get more details
	url := fmt.Sprintf("%s/api/v2?apikey=%s&cmd=get_activity", config.TautulliURL, config.TautulliAPIKey)
	resp, err := http.Get(url)
	if err != nil {
		d.updateService("tautulli", "media", false, fmt.Sprintf("Connection error: %v", err), nil)
		return
	}
	defer resp.Body.Close()

	details := make(map[string]interface{})
	
	if resp.StatusCode == 200 {
		body, _ := io.ReadAll(resp.Body)
		var data map[string]interface{}
		if json.Unmarshal(body, &data) == nil {
			if response, ok := data["response"].(map[string]interface{}); ok {
				if result, ok := response["result"].(string); ok && result == "success" {
					if responseData, ok := response["data"].(map[string]interface{}); ok {
						if streamCount, ok := responseData["stream_count"].(float64); ok {
							details["active_streams"] = int(streamCount)
						}
					}
				}
			}
		}
		
		d.updateService("tautulli", "media", true, "Connected to Tautulli", details)
	} else {
		d.updateService("tautulli", "media", false, fmt.Sprintf("HTTP %d", resp.StatusCode), nil)
	}
}

func (d *Dashboard) collectMetrics(config *Config) {
	for {
		log.Println("Collecting metrics...")
		
		// Check all services
		d.checkPlexHealth(config)
		d.checkTautulliHealth(config)
		d.checkArrHealth("radarr", config.RadarrURL, config.RadarrAPIKey, "arr-stack")
		d.checkArrHealth("sonarr", config.SonarrURL, config.SonarrAPIKey, "arr-stack")
		if config.ReadarrAPIKey != "" {
			d.checkArrHealth("readarr", config.ReadarrURL, config.ReadarrAPIKey, "arr-stack")
		}
		d.checkArrHealth("lidarr", config.LidarrURL, config.LidarrAPIKey, "arr-stack")
		d.checkBazarrHealth(config)
		d.checkJackettHealth(config)
		d.checkTransmissionHealth(config)
		d.checkArgoHealth(config)
		
		time.Sleep(30 * time.Second)
	}
}

func (d *Dashboard) handleAPI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	d.mu.RLock()
	defer d.mu.RUnlock()
	
	json.NewEncoder(w).Encode(d.Services)
}

func handleDashboard(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html")
	fmt.Fprintf(w, dashboardHTML)
}

func main() {
	config := loadConfig()
	dashboard := &Dashboard{
		Services: make(map[string]*ServiceStatus),
	}
	
	// Start metrics collection in background
	go dashboard.collectMetrics(config)
	
	// API endpoints
	http.HandleFunc("/api/status", dashboard.handleAPI)
	http.HandleFunc("/", handleDashboard)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	
	log.Println("Starting dashboard server on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

const dashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rinzler Grid Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0a0a0a;
            color: #e0e0e0;
            line-height: 1.6;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #00d4ff;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-align: center;
            text-shadow: 0 0 20px rgba(0, 212, 255, 0.5);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .service-card {
            background: #1a1a1a;
            border: 1px solid #333;
            border-radius: 8px;
            padding: 20px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        .service-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(0, 212, 255, 0.2);
        }
        .service-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        .service-name {
            font-size: 1.3em;
            font-weight: 600;
            color: #fff;
        }
        .service-type {
            font-size: 0.9em;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        .status-healthy {
            background: #00ff00;
            box-shadow: 0 0 10px rgba(0, 255, 0, 0.5);
        }
        .status-unhealthy {
            background: #ff0000;
            box-shadow: 0 0 10px rgba(255, 0, 0, 0.5);
        }
        .status-unknown {
            background: #ffaa00;
            box-shadow: 0 0 10px rgba(255, 170, 0, 0.5);
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .service-message {
            color: #aaa;
            margin-bottom: 10px;
        }
        .service-details {
            font-size: 0.9em;
            color: #888;
        }
        .detail-item {
            display: flex;
            justify-content: space-between;
            padding: 5px 0;
            border-bottom: 1px solid #2a2a2a;
        }
        .detail-item:last-child {
            border-bottom: none;
        }
        .detail-value {
            color: #00d4ff;
        }
        .last-checked {
            font-size: 0.8em;
            color: #666;
            margin-top: 10px;
        }
        .loading {
            text-align: center;
            padding: 50px;
            font-size: 1.2em;
            color: #666;
        }
        .error {
            background: #2a1a1a;
            border: 1px solid #ff0000;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            color: #ff6666;
        }
        .refresh-timer {
            text-align: center;
            color: #666;
            font-size: 0.9em;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Rinzler Grid Monitor</h1>
        <div class="refresh-timer" id="refresh-timer">Next refresh in: 30s</div>
        <div id="services" class="grid">
            <div class="loading">Loading services...</div>
        </div>
    </div>

    <script>
        let refreshInterval = 30;
        let refreshCountdown = refreshInterval;

        function formatTimestamp(timestamp) {
            const date = new Date(timestamp);
            const now = new Date();
            const diff = Math.floor((now - date) / 1000);
            
            if (diff < 60) return '${diff}s ago';
            if (diff < 3600) return '${Math.floor(diff / 60)}m ago';
            if (diff < 86400) return '${Math.floor(diff / 3600)}h ago';
            return '${Math.floor(diff / 86400)}d ago';
        }

        function renderService(name, service) {
            const statusClass = service.healthy ? 'status-healthy' : 'status-unhealthy';
            let detailsHTML = '';
            
            if (service.details) {
                for (const [key, value] of Object.entries(service.details)) {
                    if (key !== 'health_issues') {
                        const displayKey = key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                        detailsHTML += '<div class="detail-item"><span>${displayKey}</span><span class="detail-value">${value}</span></div>';
                    }
                }
            }

            return '<div class="service-card"><div class="service-header"><div><div class="service-name">${name.toUpperCase()}</div><div class="service-type">${service.type}</div></div><div class="status-indicator ${statusClass}"></div></div><div class="service-message">${service.message}</div>${detailsHTML ? '<div class="service-details">' + detailsHTML + '</div>' : ''}<div class="last-checked">Last checked: ${formatTimestamp(service.lastChecked)}</div></div>';
        }

        async function fetchStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                const container = document.getElementById('services');
                const services = Object.entries(data).sort(([a], [b]) => a.localeCompare(b));
                
                container.innerHTML = services.map(([name, service]) => renderService(name, service)).join('');
            } catch (error) {
                document.getElementById('services').innerHTML = '<div class="error">Failed to fetch service status: ' + error.message + '</div>';
            }
        }

        function updateRefreshTimer() {
            document.getElementById('refresh-timer').textContent = 'Next refresh in: ${refreshCountdown}s';
            refreshCountdown--;
            
            if (refreshCountdown < 0) {
                refreshCountdown = refreshInterval;
                fetchStatus();
            }
        }

        // Initial fetch
        fetchStatus();

        // Update every second for countdown
        setInterval(updateRefreshTimer, 1000);
    </script>
</body>
</html>
`