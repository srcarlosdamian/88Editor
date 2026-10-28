#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "  Empaquetador Universal de 88 Editor     "
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "1. Compilando binario para Apple Silicon (arm64)..."
swift build -c release --triple arm64-apple-macosx

echo "2. Compilando binario para Intel (x86_64)..."
swift build -c release --triple x86_64-apple-macosx

echo "3. Fusionando arquitecturas en binario Universal 2 (lipo)..."
mkdir -p dist/bin
lipo -create -output dist/bin/88Editor_universal \
    .build/arm64-apple-macosx/release/88Editor \
    .build/x86_64-apple-macosx/release/88Editor

echo "4. Estructurando 88Editor.app..."
APP_DIR="dist/88Editor.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp dist/bin/88Editor_universal "$APP_DIR/Contents/MacOS/88Editor"
chmod +x "$APP_DIR/Contents/MacOS/88Editor"

cp Sources/88Editor/Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
cp Sources/88Editor/Resources/AppIcon_Rounded.png "$APP_DIR/Contents/Resources/AppIcon_Rounded.png" 2>/dev/null || true
if [ -d ".build/arm64-apple-macosx/release/88Editor_88Editor.bundle" ]; then
    cp -R .build/arm64-apple-macosx/release/88Editor_88Editor.bundle "$APP_DIR/"
    cp -R .build/arm64-apple-macosx/release/88Editor_88Editor.bundle "$APP_DIR/Contents/Resources/"
    cp -R .build/arm64-apple-macosx/release/88Editor_88Editor.bundle "$APP_DIR/Contents/MacOS/"
fi

echo -n "APPL88ED" > "$APP_DIR/Contents/PkgInfo"

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleExecutable</key>
    <string>88Editor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.damian.editor88</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>88Editor</string>
    <key>CFBundleDisplayName</key>
    <string>88 Editor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>88 Editor Project</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.damian.editor88.project</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.damian.editor88.project</string>
            <key>UTTypeDescription</key>
            <string>88 Editor Project</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.content</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>88proj</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "5. Firmando aplicación con Ad-Hoc Code Sign..."
codesign --force --deep --sign - "$APP_DIR"

echo "6. Exportando al Escritorio..."
DESKTOP_DIR="$HOME/Desktop"
rm -rf "$DESKTOP_DIR/88Editor.app" "$DESKTOP_DIR/88Editor.zip" "$DESKTOP_DIR/88Editor.dmg"

# Copia directa .app
cp -R "$APP_DIR" "$DESKTOP_DIR/88Editor.app"

# Archivo .zip para compartir fácilmente
ditto -c -k --keepParent "$DESKTOP_DIR/88Editor.app" "$DESKTOP_DIR/88Editor.zip"

# Imagen de disco .dmg con acceso directo a Aplicaciones
STAGING="/tmp/88editor_dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Aplicaciones"
hdiutil create -volname "88 Editor" -srcfolder "$STAGING" -ov -format UDZO "$DESKTOP_DIR/88Editor.dmg"
rm -rf "$STAGING"

echo "=========================================="
echo "  ¡Exportación Completada con Éxito!      "
echo "  Ubicación: $DESKTOP_DIR                 "
echo "  - 88Editor.dmg (Instalador arrastrable) "
echo "  - 88Editor.zip (Listo para enviar)      "
echo "  - 88Editor.app (Aplicación directa)     "
echo "=========================================="
