#!/bin/bash
set -e

# GORKH DMG Builder
# Usage: ./scripts/build-dmg.sh [--sign "Developer ID Application: Your Name"]

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="GORKH"
CONFIG="Release"
BUNDLE_ID="ai.gorkh.GORKH"
APP_NAME="GORKH"

# Signing identity (empty = ad-hoc / unsigned)
SIGN_IDENTITY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build Release
echo "🔨 Building $APP_NAME in $CONFIG mode..."
cd "$PROJECT_DIR"

# Force Xcode path (in case xcode-select points to CLT)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -destination "platform=macOS" clean build

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "$APP_NAME.app" -path "*/Build/Products/$CONFIG/*" -type d -print -quit | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Could not find built app in DerivedData"
    exit 1
fi

echo "📦 Found app: $APP_PATH"

# Optional: codesign with Developer ID
if [ -n "$SIGN_IDENTITY" ]; then
    echo "🔏 Signing with: $SIGN_IDENTITY"
    codesign --force --options runtime --deep --sign "$SIGN_IDENTITY" \
        --entitlements "$PROJECT_DIR/GORKH/GORKH.entitlements" \
        "$APP_PATH"
else
    echo "⚠️  No signing identity provided. App will be unsigned."
    echo "   Users will see 'Cannot be opened because the developer cannot be verified.'"
    echo "   To fix: get an Apple Developer ID and pass --sign 'Developer ID Application: Your Name'"
fi

# DMG staging
DMG_NAME="${APP_NAME}-$(date +%Y%m%d).dmg"
STAGING_DIR="/tmp/gorkh-dmg-staging"
MOUNT_POINT="/tmp/gorkh-dmg-mount"

rm -rf "$STAGING_DIR" "$MOUNT_POINT"
mkdir -p "$STAGING_DIR" "$MOUNT_POINT"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create temp DMG
echo "💿 Creating DMG..."
hdiutil create -srcfolder "$STAGING_DIR" -volname "$APP_NAME" -fs HFS+ \
    -format UDRW -size 80m "/tmp/$DMG_NAME-temp.dmg"

# Mount and set window layout
hdiutil attach "/tmp/$DMG_NAME-temp.dmg" -mountpoint "$MOUNT_POINT" -nobrowse -noverify

# Set DMG window style using AppleScript (best-effort, may fail in non-GUI contexts)
if osascript <<EOF 2>/dev/null
tell application "Finder"
    set dmg to disk "$APP_NAME"
    open dmg
    set windowBounds to {100, 100, 540, 380}
    set the bounds of window of dmg to windowBounds
    set theView to icon view of window of dmg
    set arrangement of theView to not arranged
    set icon size of theView to 80
    set text size of theView to 12
    
    set appItem to item "$APP_NAME.app" of dmg
    set appPos to {140, 120}
    set position of appItem to appPos
    
    set appsItem to item "Applications" of dmg
    set appsPos to {340, 120}
    set position of appsItem to appsPos
    
    update dmg
    close window of dmg
end tell
EOF
then
    echo "   Window layout applied"
else
    echo "   Window layout skipped (non-GUI environment)"
fi

hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true

# Convert to compressed read-only DMG
hdiutil convert "/tmp/$DMG_NAME-temp.dmg" -format UDZO -o "$PROJECT_DIR/$DMG_NAME"

# Cleanup
rm -rf "$STAGING_DIR" "$MOUNT_POINT" "/tmp/$DMG_NAME-temp.dmg"

echo ""
echo "✅ DMG created: $PROJECT_DIR/$DMG_NAME"
echo ""

# Optional: notarize
if [ -n "$SIGN_IDENTITY" ]; then
    echo "🚀 Notarization ready. Run this to notarize:"
    echo ""
    echo "  xcrun notarytool submit \"$PROJECT_DIR/$DMG_NAME\" \\"
    echo "    --apple-id YOUR_APPLE_ID \\"
    echo "    --team-id YOUR_TEAM_ID \\"
    echo "    --password YOUR_APP_SPECIFIC_PASSWORD \\"
    echo "    --wait"
    echo ""
    echo "  xcrun stapler staple \"$PROJECT_DIR/$DMG_NAME\""
    echo ""
else
    echo "⚠️  NOTARIZATION SKIPPED — app is unsigned."
    echo "   For public distribution you MUST:"
    echo "   1. Join Apple Developer Program (\$99/year)"
    echo "   2. Get 'Developer ID Application' certificate"
    echo "   3. Re-run with: ./scripts/build-dmg.sh --sign 'Developer ID Application: Your Name'"
    echo ""
    echo "   To test locally without signing, right-click the app and choose Open."
fi
