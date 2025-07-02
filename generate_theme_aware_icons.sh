#!/bin/bash

# WolfWhisper Theme-Aware Icon Generator
# Generates both light and dark versions of wolf icons

echo "🐺 Generating theme-aware WolfWhisper icons..."

SOURCE_ICON="wolf_icon_original.png"
WHITE_ICON="wolf_icon_white.png"
ICON_DIR="WolfWhisper/Assets.xcassets/WolfIcon.imageset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "❌ Error: Source icon $SOURCE_ICON not found!"
    exit 1
fi

echo "📱 Generating light theme icons (dark wolf)..."
# Light theme icons (original dark wolf)
sips -z 32 32 "$SOURCE_ICON" --out "${ICON_DIR}/wolf-icon-light.png"
sips -z 64 64 "$SOURCE_ICON" --out "${ICON_DIR}/wolf-icon-light@2x.png"
sips -z 128 128 "$SOURCE_ICON" --out "${ICON_DIR}/wolf-icon-light@3x.png"

echo "🌙 Generating dark theme icons (white wolf)..."
# Check if white version exists
if [ -f "$WHITE_ICON" ]; then
    echo "   Using existing white wolf icon: $WHITE_ICON"
    sips -z 32 32 "$WHITE_ICON" --out "${ICON_DIR}/wolf-icon-dark.png"
    sips -z 64 64 "$WHITE_ICON" --out "${ICON_DIR}/wolf-icon-dark@2x.png"
    sips -z 128 128 "$WHITE_ICON" --out "${ICON_DIR}/wolf-icon-dark@3x.png"
else
    echo "   ⚠️  White wolf icon not found. Creating placeholder dark icons..."
    echo "   📝 To create a white version:"
    echo "      1. Open $SOURCE_ICON in Preview"
    echo "      2. Tools → Adjust Color..."
    echo "      3. Move 'Black Point' slider all the way right"
    echo "      4. Move 'White Point' slider to create white wolf"
    echo "      5. Save as $WHITE_ICON"
    echo "      6. Run this script again"
    echo ""
    
    # For now, use the original as placeholder (will be dark on dark)
    sips -z 32 32 "$SOURCE_ICON" --out "${ICON_DIR}/wolf-icon-dark.png"
    sips -z 64 64 "$SOURCE_ICON" --out "${ICON_DIR}/wolf-icon-dark@2x.png"
    sips -z 128 128 "$SOURCE_ICON" --out "${ICON_DIR}/wolf-icon-dark@3x.png"
fi

echo "✅ Theme-aware wolf icons generated!"
echo "📂 Icons saved to: $ICON_DIR"

echo ""
echo "🔍 Generated icons:"
for file in "${ICON_DIR}"/wolf-icon-*.png; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        size=$(sips -g pixelWidth "$file" | tail -1 | cut -d: -f2 | xargs)
        theme=$(echo "$filename" | grep -o "light\|dark")
        echo "  $filename: ${size}x${size} ($theme theme)"
    fi
done

echo ""
echo "🔄 Next steps:"
echo "1. Run: xcodebuild -project WolfWhisper.xcodeproj -scheme WolfWhisper clean build"
echo "2. Test in System Preferences → General → Appearance (Light/Dark)"
echo ""
echo "💡 How it works:"
echo "   - Light mode: Shows dark wolf (better contrast on light backgrounds)"
echo "   - Dark mode: Shows white wolf (better contrast on dark backgrounds)"
echo "   - macOS automatically chooses the right version based on system theme" 