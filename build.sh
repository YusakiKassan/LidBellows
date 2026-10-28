#!/bin/sh
# Builds build/LidBellows.app. `./build.sh --install` also copies it to ~/Applications.
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/LidBellows.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/LidBellows" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>LidBellows</string>
    <key>CFBundleDisplayName</key><string>LidBellows</string>
    <key>CFBundleIdentifier</key><string>io.github.yusakikassan.lidbellows</string>
    <key>CFBundleExecutable</key><string>LidBellows</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
if [ "$1" = "--install" ]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/LidBellows.app
    cp -R "$APP" ~/Applications/
    echo "Installed to ~/Applications/LidBellows.app"
fi
