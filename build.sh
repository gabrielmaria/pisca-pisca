#!/bin/bash
#
# Compila a Pausa 20-20-20 e, opcionalmente, instala-a em /Applications.
#
#   ./build.sh            -> cria build/Pausa 20-20-20.app
#   ./build.sh --install  -> compila e instala em /Applications
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Pausa 20-20-20"
BUNDLE="build/${APP_NAME}.app"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "A compilar…"
swiftc -O -swift-version 5 \
    -framework Cocoa -framework ServiceManagement \
    -o "$BUNDLE/Contents/MacOS/Pausa2020" Sources/main.swift

codesign --force --sign - --timestamp=none "$BUNDLE"
echo "Pronto: $BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
    pkill -f "Pausa2020" 2>/dev/null || true
    sleep 1
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "$BUNDLE" "/Applications/${APP_NAME}.app"
    xattr -cr "/Applications/${APP_NAME}.app"
    echo "Instalada em /Applications/${APP_NAME}.app"
    open "/Applications/${APP_NAME}.app"
fi
