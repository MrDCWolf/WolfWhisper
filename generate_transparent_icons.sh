#!/bin/bash

# Script to generate transparent WolfWhisper app icons
# Usage: Uses WolfTransparent.png as source

SOURCE_ICON="wolf_icon_original.png"
ICON_DIR="WolfWhisper/Assets.xcassets/WolfIcon.imageset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "❌ Error: Please ensure 'WolfTransparent.png' exists in the project root"
    exit 1
fi

echo "🐺 Generating WolfWhisper app icons from $SOURCE_ICON..."

# Create the icon directory if it doesn't exist
mkdir -p "$ICON_DIR"

# Generate all required sizes
echo "📱 Generating 32x32 (1x)..."
sips -z 32 32 "$SOURCE_ICON" --out "$ICON_DIR/wolf-icon.png" > /dev/null

echo "📱 Generating 64x64 (2x)..."
sips -z 64 64 "$SOURCE_ICON" --out "$ICON_DIR/wolf-icon@2x.png" > /dev/null

echo "📱 Generating 128x128 (3x)..."
sips -z 128 128 "$SOURCE_ICON" --out "$ICON_DIR/wolf-icon@3x.png" > /dev/null

echo ""
echo "✅ Wolf icons generated successfully!"
echo "📂 Icons saved to: $ICON_DIR"

# Check if the generated icons have transparency
echo ""
echo "🔍 Checking transparency of generated icons..."
for icon in "$ICON_DIR"/wolf-icon*.png; do
    if [ -f "$icon" ]; then
        alpha_status=$(sips -g hasAlpha "$icon" | grep hasAlpha | awk '{print $2}')
        echo "  $(basename "$icon"): hasAlpha = $alpha_status"
    fi
done

echo ""
echo "🔄 Next steps:"
echo "1. Run: xcodebuild -project WolfWhisper.xcodeproj -scheme WolfWhisper clean build"
echo "2. Run: open /path/to/WolfWhisper.app"
echo ""
echo "💡 If icons still have white backgrounds, you may need to:"
echo "   1. Open WolfTransparent.png in Preview"
echo "   2. Tools → Instant Alpha → Click white background"
echo "   3. File → Export → Save as PNG" 