#!/usr/bin/env python3
"""Replace the icon generation section in build.sh with a simple copy."""

with open('/Users/mima0000/Documents/沙凯龙/app/build.sh', 'r') as f:
    content = f.read()

start_marker = '# Generate app icon'
end_marker = 'fi\n\n# Generate PkgInfo'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx >= 0 and end_idx >= 0:
    # Find the actual end (the 'fi' before '# Generate PkgInfo')
    # We want to replace from start_marker through the end of that section
    # The section ends just before '# Generate PkgInfo'

    replacement = '''# Copy pre-generated icon from Resources
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

'''

    new_content = content[:start_idx] + replacement + content[end_idx:]
    with open('/Users/mima0000/Documents/沙凯龙/app/build.sh', 'w') as f:
        f.write(new_content)
    print("✅ build.sh updated successfully")
else:
    print(f"❌ Could not find markers")
    print(f"start_marker found at: {start_idx}")
    print(f"end_marker found at: {end_idx}")
