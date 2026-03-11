#!/bin/zsh
set -euo pipefail

APP_NAME="Scribbles-N-Scripts"
MODULE_NAME="ScribblesNScripts"
BUNDLE_ID="edu.northeastern.leaton.scribbles-n-scripts"
VERSION="1.0.1"
SHORT_VERSION="1.0.1"
CONFIGURATION="release"
INSTALL_DIR=""
SIGN_IDENTITY=""
WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<EOF
Usage: Tools/package_app.sh [--debug] [--install-dir PATH] [--sign IDENTITY]

Builds Scribbles-N-Scripts as a standalone macOS .app bundle.

Options:
  --debug               Build a debug app instead of release.
  --install-dir PATH    Copy the finished .app into PATH after bundling.
  --sign IDENTITY       Codesign the .app with the provided identity.

If --install-dir is omitted, the app bundle is written to:
  $WORKDIR/dist/$APP_NAME.app
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      CONFIGURATION="debug"
      shift
      ;;
    --install-dir)
      INSTALL_DIR="${2:-}"
      [[ -n "$INSTALL_DIR" ]] || { echo "Missing path for --install-dir" >&2; exit 1; }
      shift 2
      ;;
    --sign)
      SIGN_IDENTITY="${2:-}"
      [[ -n "$SIGN_IDENTITY" ]] || { echo "Missing identity for --sign" >&2; exit 1; }
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cd "$WORKDIR"

LOCAL_HOME="$WORKDIR/.build/local-home"
LOCAL_CACHE="$LOCAL_HOME/cache"
LOCAL_CLANG_CACHE="$WORKDIR/.build/clang-module-cache"
mkdir -p "$LOCAL_CACHE" "$LOCAL_CLANG_CACHE"

echo "Building $APP_NAME ($CONFIGURATION)..."
HOME="$LOCAL_HOME" \
XDG_CACHE_HOME="$LOCAL_CACHE" \
CLANG_MODULE_CACHE_PATH="$LOCAL_CLANG_CACHE" \
swift build -c "$CONFIGURATION"

BUILD_ROOT="$(find .build -type d -path "*/$CONFIGURATION" | sort | head -n 1)"
[[ -n "$BUILD_ROOT" ]] || { echo "Could not locate .build output for configuration '$CONFIGURATION'." >&2; exit 1; }

EXECUTABLE_PATH="$BUILD_ROOT/$APP_NAME"
RESOURCE_BUNDLE_PATH="$BUILD_ROOT/${APP_NAME}_${MODULE_NAME}.bundle"
ICON_PATH="Sources/Manuscript/Resources/Branding/${APP_NAME}.icns"
APP_BUNDLE_PATH="$WORKDIR/dist/$APP_NAME.app"
CONTENTS_PATH="$APP_BUNDLE_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

[[ -x "$EXECUTABLE_PATH" ]] || { echo "Missing built executable at $EXECUTABLE_PATH" >&2; exit 1; }
[[ -d "$RESOURCE_BUNDLE_PATH" ]] || { echo "Missing SwiftPM resource bundle at $RESOURCE_BUNDLE_PATH" >&2; exit 1; }
[[ -f "$ICON_PATH" ]] || { echo "Missing icon at $ICON_PATH" >&2; exit 1; }

rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"

cp "$EXECUTABLE_PATH" "$MACOS_PATH/$APP_NAME"
cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_PATH/"
cp "$ICON_PATH" "$RESOURCES_PATH/"

cat > "$CONTENTS_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

printf "APPL????" > "$CONTENTS_PATH/PkgInfo"
chmod +x "$MACOS_PATH/$APP_NAME"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing app with identity: $SIGN_IDENTITY"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE_PATH"
else
  echo "Leaving app unsigned for local-machine use."
fi

if [[ -n "$INSTALL_DIR" ]]; then
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
  cp -R "$APP_BUNDLE_PATH" "$INSTALL_DIR/"
  APP_BUNDLE_PATH="$INSTALL_DIR/$APP_NAME.app"
fi

echo "Created app bundle:"
echo "  $APP_BUNDLE_PATH"
