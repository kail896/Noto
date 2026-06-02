#!/bin/bash
# ==========================================================
# Noto Build Script — macOS Native App + DMG
# ==========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PRODUCT_NAME="Noto"
BUNDLE_ID="com.noto.app"
BUILD_DIR=".build"
APP_BUNDLE_PATH="$BUILD_DIR/$PRODUCT_NAME.app"
DMG_PATH="$BUILD_DIR/$PRODUCT_NAME.dmg"
RESOURCES_DIR="Resources"
SOURCE_DIR="Sources/Noto/Resources"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}══════════════════════════════════${NC}"
echo -e "${BLUE}  Building $PRODUCT_NAME for macOS${NC}"
echo -e "${BLUE}══════════════════════════════════${NC}"

# Step 1: Build with SwiftPM
echo -e "\n${GREEN}[1/4] Building Swift project...${NC}"
swift build -c release --product "$PRODUCT_NAME"

# Locate the built binary
BINARY_PATH=$(swift build -c release --show-bin-path)/$PRODUCT_NAME
echo "  Binary: $BINARY_PATH"

# Step 2: Create .app bundle structure
echo -e "\n${GREEN}[2/4] Creating .app bundle...${NC}"

# Remove existing bundle if present
rm -rf "$APP_BUNDLE_PATH"

# Create standard macOS app bundle structure
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS"
mkdir -p "$APP_BUNDLE_PATH/Contents/Resources"

# Copy binary
cp "$BINARY_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"

# Copy Info.plist (try both locations)
if [ -f "$RESOURCES_DIR/Info.plist" ]; then
    cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE_PATH/Contents/Info.plist"
elif [ -f "$SOURCE_DIR/Info.plist" ]; then
    cp "$SOURCE_DIR/Info.plist" "$APP_BUNDLE_PATH/Contents/Info.plist"
else
    echo -e "${RED}  Error: Info.plist not found${NC}"
    exit 1
fi

# Copy pre-generated icon from Resources
echo "  Copying app icon..."
ICON_DIR="$APP_BUNDLE_PATH/Contents/Resources"
ICON_PATH="$ICON_DIR/$PRODUCT_NAME.icns"
if [ -f "$RESOURCES_DIR/$PRODUCT_NAME.icns" ]; then
    cp "$RESOURCES_DIR/$PRODUCT_NAME.icns" "$ICON_PATH"
    echo "  ✅ Icon copied: $PRODUCT_NAME.icns"
elif [ -f "$SOURCE_DIR/$PRODUCT_NAME.icns" ]; then
    cp "$SOURCE_DIR/$PRODUCT_NAME.icns" "$ICON_PATH"
    echo "  ✅ Icon copied from Sources"
else
    echo "  ⚠️  No .icns file found, skipping icon"
fi

# Generate PkgInfo
printf "APPL????" > "$APP_BUNDLE_PATH/Contents/PkgInfo"

echo -e "${GREEN}  ✅ App bundle created at: $APP_BUNDLE_PATH${NC}"

# Step 3: Codesign
echo -e "\n${GREEN}[3/4] Code signing...${NC}"
codesign -s - --force --deep "$APP_BUNDLE_PATH" 2>/dev/null || true
if codesign -dv "$APP_BUNDLE_PATH" 2>/dev/null; then
    echo "  ✅ App signed"
fi

# Verify
codesign -dv "$APP_BUNDLE_PATH" 2>/dev/null && echo "  ✅ Signature verified" || true

# Step 4: Create DMG
echo -e "\n${GREEN}[4/4] Creating DMG package...${NC}"

# Remove existing DMG
rm -f "$DMG_PATH"

# Create DMG using hdiutil
DMG_TMP="$BUILD_DIR/${PRODUCT_NAME}_tmp.dmg"
VOLUME_NAME="$PRODUCT_NAME"

# Create a temporary directory for DMG contents
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy the app bundle
cp -R "$APP_BUNDLE_PATH" "$STAGING_DIR/$PRODUCT_NAME.app"

# Create a symlink to Applications folder for easy install
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
DMG_SIZE_MB=50
hdiutil create -size ${DMG_SIZE_MB}m -fs HFS+ \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" 2>/dev/null

# Clean up staging
rm -rf "$STAGING_DIR"

# Verify DMG
if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo -e "${GREEN}  ✅ DMG created: $DMG_PATH ($DMG_SIZE)${NC}"
else
    echo -e "${RED}  ❌ Failed to create DMG${NC}"
    exit 1
fi

# Summary
echo -e "\n${BLUE}══════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Build Complete!${NC}"
echo -e "${BLUE}══════════════════════════════════${NC}"
echo -e "  App Bundle: ${GREEN}$APP_BUNDLE_PATH${NC}"
echo -e "  DMG Package: ${GREEN}$DMG_PATH${NC}"
echo -e "\n  To install, open the DMG and drag Noto.app to Applications."
echo -e "  Or run directly: ${BLUE}open $APP_BUNDLE_PATH${NC}"
