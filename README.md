# SMacBar 🚀

[![macOS](https://img.shields.io/badge/OS-macOS_10.14+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![Go Version](https://img.shields.io/badge/Go-1.20+-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://go.dev)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

**SMacBar** is a lightweight, high-performance Touch Bar utility for macOS written in **Go & Objective-C (CGo)**. It transforms your Touch Bar into a persistent, interactive system dashboard featuring **60 FPS Web Widgets** (HTML/CSS/JS, Canvas, Animations), a **Live RSS Scrolling News Ticker**, real-time **Dock Badge Counters**, and **Interactive Touch Actions**.

---

## ✨ Features

- **Persistent Control Strip Tray Icon**: Integrates directly into the macOS Control Strip (`dev.smacbar.tray`). Tap the tray icon (🐼) to toggle your dashboard anytime.
- **60 FPS WebWidgets Engine**: Render custom HTML5, CSS animations, JavaScript, Canvas motion graphics, and live widgets directly onto Touch Bar items at a smooth 60 FPS.
- **Live RSS Scrolling News Ticker**: Smooth 60 FPS news marquee fetching live RSS feeds (such as [Vex Dynamics RSS](https://vexdynamics.com/rss.xml)).
- **Interactive Tap Actions**: Tap any widget on your Touch Bar to launch applications, open URLs, focus open apps, or execute custom shell scripts. Tapping the RSS Ticker instantly opens the currently visible news article in your browser.
- **Real-Time App Dock Badges**: Live Dock badge counter monitoring (`lsappinfo`) with custom badge overlays on SF Symbols icons.
- **Multi-Workspace & Multi-Space Support**: Joins all macOS Spaces (`CanJoinAllSpaces`), maintaining 60 FPS performance across all Desktop Workspaces and Fullscreen applications.

---

## 🛠️ Prerequisites

- **macOS** 10.14+ (macOS with physical Touch Bar or [Touch Bar Simulator](https://github.com/sveinbjo/TouchBarSimulator)).
- **Go 1.20+**
- **Xcode Command Line Tools** (`xcode-select --install`).

---

## 📦 Building & Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/vexdynamics/smacbar.git
   cd smacbar
   ```

2. **Build & Sign SMacBar**:
   Run the included build script to compile the Go binary, generate `Info.plist`, build `SMacBar.app`, and sign it:
   ```bash
   ./scripts/build.sh
   ```

3. **Launch SMacBar**:
   ```bash
   open build/SMacBar.app
   ```
   The **SMacBar tray icon** (🐼) will appear in your Touch Bar Control Strip. Tap it to expand your dashboard!

---

## ⚙️ Configuration (`~/.config/smacbar/config.json`)

`SMacBar` loads its configuration from `~/.config/smacbar/config.json`. If it doesn't exist, a default config is automatically generated.

### Example Configuration:

```json
{
  "poll_interval_seconds": 5,
  "widgets": [
    {
      "id": "rss-ticker-widget",
      "type": "web_file",
      "path": "rss_ticker.html",
      "width": 180
    },
    {
      "id": "animation-widget",
      "type": "web_file",
      "path": "animation.html",
      "open": "com.apple.ActivityMonitor",
      "width": 130
    },
    {
      "id": "mattermost",
      "icon": "message.fill",
      "label": "MM",
      "bundle_id": "Mattermost.Desktop"
    },
    {
      "id": "warp",
      "icon": "terminal",
      "label": "Warp",
      "bundle_id": "dev.warp.Warp-Stable"
    }
  ]
}
```

---

## 🖱️ Interactive Touch Actions

Any widget (App Badge or WebWidget) can perform a tap action when touched on the Touch Bar:

| Property | Example Value | Description |
| :--- | :--- | :--- |
| `"open"` | `"com.apple.ActivityMonitor"` or `"https://vexdynamics.com"` | Focuses/opens an app by Bundle ID, opens a URL, or opens a file |
| `"command"` | `"osascript -e 'set volume input volume 0'"` | Executes an arbitrary shell script on tap |
| `"bundle_id"` | `"Mattermost.Desktop"` | Displays Dock unread badge count & launches app on tap |
| `"url"` | `"https://news.ycombinator.com"` | Opens the web URL on tap |

---

## 🎨 How to Create & Add Custom HTML Web Widgets

Place custom `.html`, `.js`, or `.css` files inside `~/.config/smacbar/widgets/`.

### 1. Create Your HTML Widget File:
Create a file named `~/.config/smacbar/widgets/my_widget.html`:

```html
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    background: #0d0e15;
    color: #00f0ff;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 30px;
    width: 100%;
    padding: 0 8px;
    overflow: hidden;
  }
  .title { font-size: 11px; font-weight: 700; }
  .pulse { width: 10px; height: 10px; border-radius: 50%; background: #30d158; box-shadow: 0 0 8px #30d158; }
</style>
</head>
<body>
  <span class="title">MY WIDGET</span>
  <div class="pulse"></div>
</body>
</html>
```

### 2. Register It in `config.json`:
Add your widget to `~/.config/smacbar/config.json`:

```json
{
  "id": "my-custom-widget",
  "type": "web_file",
  "path": "my_widget.html",
  "open": "https://vexdynamics.com",
  "width": 140
}
```

---

## 📰 Customizing the RSS Ticker Widget

The RSS Ticker widget (`rss_ticker.html`) fetches live news headlines and scrolls them seamlessly across your Touch Bar.

To use your own RSS feed (e.g. Vex Dynamics, Hacker News, BBC, NYT), edit `~/.config/smacbar/widgets/rss_ticker.html` and update the RSS feed URL:

```javascript
const urls = [
  "https://vexdynamics.com/rss.xml",
  "https://corsproxy.io/?https://vexdynamics.com/rss.xml"
];
```

---

## 🧠 Architecture Overview

- **Go Core Engine** (`cmd/smacbar`): Configuration loader, widget polling, HTTP local widget server (`http://127.0.0.1:<port>`), and tap action dispatcher.
- **Objective-C / CGo Bridge** (`internal/touchbar`): Interoperates with macOS private frameworks (`DFRFoundation`) to manage system Control Strip presence and present persistent system modal Touch Bars.
- **Unthrottled WebKit Renderer**: Hosts WebViews inside a transparent 1x1 on-screen anchor window joining all macOS Spaces (`CanJoinAllSpaces`), capturing high-resolution snapshot images into native Touch Bar buttons at 60 FPS.

---

## 📄 License

Distributed under the MIT License. Developed by **Vex Dynamics** ([vexdynamics.com](https://vexdynamics.com)).
