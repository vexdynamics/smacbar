# SMacBar 🚀

**SMacBar** is a lightweight, customizable macOS Touch Bar utility written in **Go & Objective-C (CGo)**. It presents a persistent, system-wide Touch Bar dashboard using macOS private APIs (`DFRFoundation`), featuring real-time app badge status indicators, high-performance 60 FPS Web Widgets (HTML/CSS/JS, Canvas, Animations, Videos, GIFs), and interactive tap actions.

---

## ✨ Features

- **Persistent Touch Bar Dashboard**: Integrates with the macOS Control Strip (`dev.smacbar.tray`) and presents a persistent system modal dashboard.
- **Dock Badge Counters**: Real-time Dock badge count monitoring (`lsappinfo`) with custom badge overlays on SF Symbols icons.
- **60 FPS Web Widgets**: Render custom HTML5, CSS animations, JavaScript, HTML Canvas, GIFs, and videos directly onto Touch Bar items.
- **Interactive Click / Tap Actions**: Tap any widget on your Touch Bar to launch applications, open URLs, or execute custom shell scripts.
- **Hot Configuration**: Easily customize widgets, layouts, and frame widths in `~/.config/smacbar/config.json`.

---

## 🛠️ Prerequisites

- **macOS** 10.14+ (macOS with physical Touch Bar or [Touch Bar Simulator](https://github.com/sveinbjo/TouchBarSimulator)).
- **Go 1.20+**
- **Xcode Command Line Tools** (`xcode-select --install`).

---

## 📦 Building & Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/smacbar.git
   cd smacbar
   ```

2. **Build and Sign the Application**:
   Run the included build script to compile the Go binary, build `SMacBar.app`, and sign it:
   ```bash
   ./scripts/build.sh
   ```

3. **Launch SMacBar**:
   ```bash
   open build/SMacBar.app
   ```
   You will see the **SMacBar icon** (🐼) appear in your Touch Bar Control Strip. Tap it to reveal your dashboard!

---

## ⚙️ Configuration (`~/.config/smacbar/config.json`)

`SMacBar` loads configuration from `~/.config/smacbar/config.json`. If it doesn't exist, a default config is created automatically.

### Example Configuration:

```json
{
  "poll_interval_seconds": 5,
  "widgets": [
    {
      "id": "animation-widget",
      "type": "web_file",
      "path": "animation.html",
      "open": "com.apple.ActivityMonitor",
      "width": 260
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

## 🖱️ Making Widgets Clickable / Interactive

Any widget (App Badge or Web Widget) can perform an action when tapped on the Touch Bar!

### Tap Action Properties:

| Property | Example Value | Description |
| :--- | :--- | :--- |
| `"open"` | `"com.apple.ActivityMonitor"` or `"https://github.com"` | Opens an app by Bundle ID, a URL in browser, or a file path |
| `"command"` | `"say 'Hello World'"` or `"open -a Terminal"` | Executes any arbitrary shell command on tap |
| `"bundle_id"` | `"Mattermost.Desktop"` | Focuses / launches the app and displays its Dock badge counter |
| `"url"` | `"https://news.ycombinator.com"` | Opens the web URL on tap |

#### Examples:

- **Launch Activity Monitor on tap**:
  ```json
  {
    "id": "cyber-pulse",
    "type": "web_file",
    "path": "animation.html",
    "open": "com.apple.ActivityMonitor",
    "width": 260
  }
  ```

- **Execute Shell Command on tap**:
  ```json
  {
    "id": "mute-mic",
    "type": "web_file",
    "path": "mic.html",
    "command": "osascript -e 'set volume input volume 0'",
    "width": 120
  }
  ```

---

## 🎨 Writing Custom Web Widgets

Place custom `.html`, `.js`, or `.css` files inside `~/.config/smacbar/widgets/`.

### Animated Canvas & HTML5 Template:

```html
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #0d0e15; color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
    display: flex; align-items: center; justify-content: space-between;
    height: 30px; width: 260px; padding: 0 10px; overflow: hidden;
  }
  .badge { background: linear-gradient(135deg, #ff007f, #7928ca); padding: 2px 6px; border-radius: 4px; font-size: 10px; font-weight: 800; }
</style>
</head>
<body>
  <span class="badge">LIVE</span>
  <span style="font-size:11px; font-weight:700;">MY CUSTOM WIDGET</span>
  <script>
    // Drive animations via setInterval for 60 FPS offscreen execution
    setInterval(() => {
      // Your update logic here
    }, 25);
  </script>
</body>
</html>
```

---

## 🧠 Architecture Overview

- **Go Main Runtime** (`cmd/smacbar`): Manages config loading, event loops, widget polling goroutines, and tap handlers.
- **Objective-C Bridge** (`internal/touchbar`): Uses private frameworks (`DFRFoundation`) to manage Control Strip items (`dev.smacbar.tray`) and present system modal Touch Bars.
- **Offscreen WebKit Renderer**: Hosts WebViews inside an unthrottled on-screen 1x1 transparent anchor window, capturing snapshots into native wide `NSButton` image views at 60 FPS.

---

## 📄 License

MIT License. Feel free to customize and extend!
