// Package config loads smacbar's widget configuration.
package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type Widget struct {
	ID       string  `json:"id"`
	Type     string  `json:"type,omitempty"` // "appbadge" (default), "web", "web_file", "web_url"
	Icon     string  `json:"icon,omitempty"`
	Label    string  `json:"label,omitempty"`
	BundleID string  `json:"bundle_id,omitempty"`
	HTML     string  `json:"html,omitempty"`
	Path     string  `json:"path,omitempty"`    // relative to ~/.config/smacbar/widgets/ or absolute path
	URL      string  `json:"url,omitempty"`     // http/https URL or file URL
	Open     string  `json:"open,omitempty"`    // URL, app bundle ID, or path to open on tap
	Command  string  `json:"command,omitempty"` // Shell command to execute on tap
	Width    float64 `json:"width,omitempty"`
}

type Config struct {
	PollIntervalSeconds int      `json:"poll_interval_seconds"`
	Widgets             []Widget `json:"widgets"`
}

func DefaultDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", "smacbar"), nil
}

func DefaultWidgetsDir() (string, error) {
	dir, err := DefaultDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "widgets"), nil
}

func DefaultPath() (string, error) {
	dir, err := DefaultDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "config.json"), nil
}

var defaultConfig = Config{
	PollIntervalSeconds: 5,
	Widgets: []Widget{
		{ID: "mattermost", Icon: "message.fill", Label: "MM", BundleID: "Mattermost.Desktop"},
		{ID: "warp", Icon: "terminal", Label: "Warp", BundleID: "dev.warp.Warp-Stable"},
		{ID: "clock-widget", Type: "web_file", Path: "clock.html", Width: 180},
		{ID: "stats-widget", Type: "web_file", Path: "stats.html", Width: 160},
	},
}

// Load reads the config at path, creating a default one if it doesn't exist.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			return nil, err
		}
		data, err = json.MarshalIndent(defaultConfig, "", "  ")
		if err != nil {
			return nil, err
		}
		if err := os.WriteFile(path, data, 0o644); err != nil {
			return nil, err
		}
		cfg := defaultConfig
		return &cfg, nil
	}
	if err != nil {
		return nil, err
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
