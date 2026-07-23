package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"smacbar/internal/config"
	"smacbar/internal/touchbar"
	"smacbar/internal/widgets/appbadge"
)

var (
	activeRSSURLMu sync.Mutex
	activeRSSURL   = "https://news.ycombinator.com"
)

func getActiveRSSURL() string {
	activeRSSURLMu.Lock()
	defer activeRSSURLMu.Unlock()
	return activeRSSURL
}

func setActiveRSSURL(url string) {
	activeRSSURLMu.Lock()
	defer activeRSSURLMu.Unlock()
	if url != "" {
		activeRSSURL = url
	}
}

func main() {
	cfgPath, err := config.DefaultPath()
	if err != nil {
		log.Fatalf("resolving config path: %v", err)
	}
	cfg, err := config.Load(cfgPath)
	if err != nil {
		log.Fatalf("loading config %s: %v", cfgPath, err)
	}

	widgetMap := make(map[string]config.Widget, len(cfg.Widgets))
	for _, w := range cfg.Widgets {
		widgetMap[w.ID] = w
	}

	touchbar.SetTapHandler(func(id string) {
		w, ok := widgetMap[id]
		if !ok {
			return
		}

		if strings.Contains(w.Path, "rss_ticker") || w.ID == "rss-ticker-widget" {
			url := getActiveRSSURL()
			log.Printf("Opening active RSS article for %s: %s", id, url)
			_ = exec.Command("open", url).Start()
			return
		}

		if w.Command != "" {
			log.Printf("Executing tap command for %s: %s", id, w.Command)
			_ = exec.Command("sh", "-c", w.Command).Start()
			return
		}

		targetOpen := w.Open
		if targetOpen == "" {
			if w.BundleID != "" {
				targetOpen = w.BundleID
			} else if w.URL != "" {
				targetOpen = w.URL
			}
		}

		if targetOpen != "" {
			log.Printf("Opening target for %s: %s", id, targetOpen)
			if strings.HasPrefix(targetOpen, "http://") || strings.HasPrefix(targetOpen, "https://") || strings.HasPrefix(targetOpen, "/") {
				_ = exec.Command("open", targetOpen).Start()
			} else {
				_ = appbadge.Open(targetOpen)
			}
		}
	})

	const testAnimationHTML = `
<html><body style="margin:0;background:black;overflow:hidden;">
<div style="width:18px;height:18px;border-radius:50%;background:#30d158;
position:absolute;top:6px;left:0;animation:bounce 1.4s infinite ease-in-out;"></div>
<style>@keyframes bounce {0%{left:0;} 50%{left:260px;} 100%{left:0;}}</style>
</body></html>`

	var serverBaseURL string
	widgetsDir, err := config.DefaultWidgetsDir()
	if err != nil {
		log.Printf("resolving widgets dir: %v", err)
	} else {
		_ = os.MkdirAll(widgetsDir, 0o755)
		ensureSampleWidgets(widgetsDir)
		serverBaseURL = startLocalWidgetServer(widgetsDir)
	}

	touchbar.Run(func() {
		interval := time.Duration(cfg.PollIntervalSeconds) * time.Second
		for _, w := range cfg.Widgets {
			width := w.Width
			if width <= 0 {
				width = 200
			}

			if w.URL != "" || w.Type == "web_url" {
				log.Printf("Registering web widget URL: %s (%s)", w.ID, w.URL)
				touchbar.RegisterWebWidgetURL(w.ID, w.URL, width)
			} else if w.Path != "" || w.Type == "web_file" {
				if serverBaseURL != "" && !filepath.IsAbs(w.Path) {
					widgetURL := serverBaseURL + "/" + w.Path
					log.Printf("Registering web widget HTTP URL: %s (%s)", w.ID, widgetURL)
					touchbar.RegisterWebWidgetURL(w.ID, widgetURL, width)
				} else {
					filePath := w.Path
					if !filepath.IsAbs(filePath) && widgetsDir != "" {
						filePath = filepath.Join(widgetsDir, w.Path)
					}
					log.Printf("Registering web widget file: %s (%s)", w.ID, filePath)
					touchbar.RegisterWebWidgetURL(w.ID, filePath, width)
				}
			} else if w.HTML != "" || w.Type == "web" {
				log.Printf("Registering web widget HTML: %s", w.ID)
				touchbar.RegisterWebWidget(w.ID, w.HTML, width)
			} else if w.BundleID != "" || w.Type == "appbadge" || w.Type == "" {
				log.Printf("Registering appbadge widget: %s (%s)", w.ID, w.BundleID)
				touchbar.RegisterWidget(w.ID, w.Icon, "")
				go appbadge.Poll(context.Background(), w.ID, w.BundleID, interval)
			}
		}

		touchbar.Present()

		if capturePath := os.Getenv("SMACBAR_CAPTURE"); capturePath != "" {
			go func() {
				time.Sleep(2 * time.Second)
				touchbar.CaptureDashboard(capturePath)
			}()
		}
	})
}

func ensureSampleWidgets(dir string) {
	clockPath := filepath.Join(dir, "clock.html")
	if _, err := os.Stat(clockPath); os.IsNotExist(err) {
		const clockHTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #000; color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
    display: flex; align-items: center; justify-content: center;
    height: 30px; width: 100%; overflow: hidden; user-select: none;
  }
  .clock-container {
    display: flex; align-items: baseline; gap: 6px;
    background: rgba(255, 255, 255, 0.1);
    padding: 3px 10px; border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.15);
  }
  .time { font-size: 15px; font-weight: 600; color: #00f0ff; text-shadow: 0 0 8px rgba(0,240,255,0.5); }
  .seconds { font-size: 11px; font-weight: 400; color: #ff007f; }
  .date { font-size: 11px; color: #a0a0a0; text-transform: uppercase; }
</style>
</head>
<body>
  <div class="clock-container">
    <span class="date" id="date">JAN 1</span>
    <span class="time" id="time">00:00</span>
    <span class="seconds" id="seconds">:00</span>
  </div>
  <script>
    function updateClock() {
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      const months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
      const days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
      document.getElementById('time').textContent = hours + ':' + minutes;
      document.getElementById('seconds').textContent = ':' + seconds;
      document.getElementById('date').textContent = days[now.getDay()] + ' ' + months[now.getMonth()] + ' ' + now.getDate();
    }
    setInterval(updateClock, 1000); updateClock();
  </script>
</body>
</html>`
		_ = os.WriteFile(clockPath, []byte(clockHTML), 0o644)
	}

	statsPath := filepath.Join(dir, "stats.html")
	if _, err := os.Stat(statsPath); os.IsNotExist(err) {
		const statsHTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #000; color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
    display: flex; align-items: center; justify-content: center; gap: 8px;
    height: 30px; width: 100%; overflow: hidden;
  }
  .stat-pill {
    display: flex; align-items: center; gap: 6px;
    background: rgba(255, 255, 255, 0.1); padding: 3px 10px;
    border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.15); font-size: 12px; font-weight: 500;
  }
  .bar-bg { width: 50px; height: 6px; background: rgba(255, 255, 255, 0.2); border-radius: 3px; overflow: hidden; }
  .bar-fill { height: 100%; width: 45%; background: linear-gradient(90deg, #30d158, #ffd60a); transition: width 0.5s ease; }
  .label { color: #30d158; font-size: 10px; font-weight: 700; text-transform: uppercase; }
</style>
</head>
<body>
  <div class="stat-pill">
    <span class="label">CPU</span>
    <div class="bar-bg"><div class="bar-fill" id="cpu-bar"></div></div>
    <span id="cpu-val" style="width:28px;">32%</span>
  </div>
  <script>
    function updateStats() {
      const cpu = Math.floor(15 + Math.random() * 35);
      document.getElementById('cpu-bar').style.width = cpu + '%';
      document.getElementById('cpu-val').textContent = cpu + '%';
    }
    setInterval(updateStats, 2000); updateStats();
  </script>
</body>
</html>`
		_ = os.WriteFile(statsPath, []byte(statsHTML), 0o644)
	}
}

func startLocalWidgetServer(dir string) string {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Printf("Failed starting local widget server: %v", err)
		return ""
	}
	port := listener.Addr().(*net.TCPAddr).Port

	mux := http.NewServeMux()
	mux.Handle("/", http.FileServer(http.Dir(dir)))
	mux.HandleFunc("/active_rss", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			var payload struct {
				URL   string `json:"url"`
				Title string `json:"title"`
			}
			if err := json.NewDecoder(r.Body).Decode(&payload); err == nil && payload.URL != "" {
				setActiveRSSURL(payload.URL)
			}
		}
		w.WriteHeader(http.StatusOK)
	})

	srv := &http.Server{
		Handler: mux,
	}
	go func() {
		_ = srv.Serve(listener)
	}()
	url := fmt.Sprintf("http://127.0.0.1:%d", port)
	log.Printf("Started local widget HTTP server at %s", url)
	return url
}
