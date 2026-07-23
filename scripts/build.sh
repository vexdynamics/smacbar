#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/SMacBar.app"

mkdir -p "$APP/Contents/MacOS"

cat <<'EOF' > "$APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>smacbar</string>
	<key>CFBundleIdentifier</key>
	<string>dev.smacbar.app</string>
	<key>CFBundleName</key>
	<string>SMacBar</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.14</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
</dict>
</plist>
EOF

CGO_ENABLED=1 go build -o "$APP/Contents/MacOS/smacbar" "$ROOT/cmd/smacbar"
codesign --force --deep --sign - "$APP"

echo "Built and signed $APP"
