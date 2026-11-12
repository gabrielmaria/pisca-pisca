#!/bin/bash
#
# Compila o Pisca Pisca e, opcionalmente, instala-o em /Applications.
#
#   ./build.sh            -> cria build/Pisca Pisca.app
#   ./build.sh --install  -> compila e instala em /Applications
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Pisca Pisca"
BUNDLE="build/${APP_NAME}.app"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "A compilar…"
swiftc -O -swift-version 5 \
    -framework Cocoa -framework ServiceManagement \
    -o "$BUNDLE/Contents/MacOS/PiscaPisca" Sources/main.swift

codesign --force --sign - --timestamp=none "$BUNDLE"
echo "Pronto: $BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
    pkill -f "PiscaPisca" 2>/dev/null || true
    sleep 1
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "$BUNDLE" "/Applications/${APP_NAME}.app"
    xattr -cr "/Applications/${APP_NAME}.app"
    echo "Instalado em /Applications/${APP_NAME}.app"
    open "/Applications/${APP_NAME}.app"
fi
