// Package appbadge polls a running app's Dock badge count via lsappinfo and
// reflects it on a Touch Bar widget.
package appbadge

import (
	"context"
	"os/exec"
	"regexp"
	"time"

	"smacbar/internal/touchbar"
)

var labelPattern = regexp.MustCompile(`"label"="([^"]*)"`)

// Poll periodically reads bundleID's Dock badge label and reflects it as the
// widget's title (the icon, set at registration, stays fixed). It blocks
// until ctx is done.
func Poll(ctx context.Context, widgetID, bundleID string, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	update := func() {
		touchbar.UpdateWidgetBadge(widgetID, readBadge(bundleID))
	}

	update()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			update()
		}
	}
}

// readBadge returns the app's current Dock badge label, or "" if unset.
func readBadge(bundleID string) string {
	out, err := exec.Command("lsappinfo", "info", "-only", "StatusLabel", bundleID).Output()
	if err != nil {
		return ""
	}
	m := labelPattern.FindSubmatch(out)
	if m == nil {
		return ""
	}
	return string(m[1])
}

// Open focuses or launches the app for the given bundle ID.
func Open(bundleID string) error {
	return exec.Command("open", "-b", bundleID).Run()
}
