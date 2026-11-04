#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/direct
for arch in x86_64 arm64; do
  mkdir -p ".build/direct/$arch"
  swiftc "${SWIFT_FLAGS[@]}" -target "$arch-apple-macosx13.0" -parse-as-library -emit-object -emit-module -module-name PowerCore Sources/PowerCore/PowerReading.swift -o ".build/direct/$arch/PowerCore.o" -emit-module-path ".build/direct/$arch/PowerCore.swiftmodule"
  swiftc "${SWIFT_FLAGS[@]}" -target "$arch-apple-macosx13.0" -parse-as-library -I ".build/direct/$arch" Sources/Powermeter/*.swift ".build/direct/$arch/PowerCore.o" -o ".build/direct/$arch/Powermeter"
done
APP="$PWD/dist/Powermeter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
lipo -create .build/direct/x86_64/Powermeter .build/direct/arm64/Powermeter -output "$APP/Contents/MacOS/Powermeter"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.powermeter.app</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>Powermeter</string>
<key>CFBundleExecutable</key><string>Powermeter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
lipo -info "$APP/Contents/MacOS/Powermeter"
echo "Built $APP"
