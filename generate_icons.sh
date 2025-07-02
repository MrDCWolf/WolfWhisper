#!/bin/bash

# Script to generate all required macOS app icon sizes
# Usage: Place your source icon as 'wolf_icon_original.png' in the project root and run this script

SOURCE_ICON="wolf_icon_original.png"
ICON_DIR="WolfWhisper/Assets.xcassets/AppIcon.appiconset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "❌ Error: Please save your wolf icon as 'wolf_icon_original.png' in the project root directory"
    exit 1
fi

echo "🐺 Generating WolfWhisper app icons from $SOURCE_ICON..."

# Create the icon directory if it doesn't exist
mkdir -p "$ICON_DIR"

# Generate all required sizes
echo "📱 Generating 16x16..."
sips -z 16 16 "$SOURCE_ICON" --out "$ICON_DIR/icon_16x16.png" > /dev/null

echo "📱 Generating 32x32 (@2x for 16x16)..."
sips -z 32 32 "$SOURCE_ICON" --out "$ICON_DIR/icon_16x16@2x.png" > /dev/null

echo "📱 Generating 32x32..."
sips -z 32 32 "$SOURCE_ICON" --out "$ICON_DIR/icon_32x32.png" > /dev/null

echo "📱 Generating 64x64 (@2x for 32x32)..."
sips -z 64 64 "$SOURCE_ICON" --out "$ICON_DIR/icon_32x32@2x.png" > /dev/null

echo "📱 Generating 128x128..."
sips -z 128 128 "$SOURCE_ICON" --out "$ICON_DIR/icon_128x128.png" > /dev/null

echo "📱 Generating 256x256 (@2x for 128x128)..."
sips -z 256 256 "$SOURCE_ICON" --out "$ICON_DIR/icon_128x128@2x.png" > /dev/null

echo "📱 Generating 256x256..."
sips -z 256 256 "$SOURCE_ICON" --out "$ICON_DIR/icon_256x256.png" > /dev/null

echo "📱 Generating 512x512 (@2x for 256x256)..."
sips -z 512 512 "$SOURCE_ICON" --out "$ICON_DIR/icon_256x256@2x.png" > /dev/null

echo "📱 Generating 512x512..."
sips -z 512 512 "$SOURCE_ICON" --out "$ICON_DIR/icon_512x512.png" > /dev/null

echo "📱 Generating 1024x1024 (@2x for 512x512)..."
sips -z 1024 1024 "$SOURCE_ICON" --out "$ICON_DIR/icon_512x512@2x.png" > /dev/null

echo "✅ All app icons generated successfully!"
echo "🏗️  Now building the app to see your new icon..."

# Build the app to apply the new icons
xcodebuild -project WolfWhisper.xcodeproj -scheme WolfWhisper -configuration Debug build > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ App built successfully with new icons!"
    echo "🎉 Your wolf icon is now applied to WolfWhisper!"
else
    echo "⚠️  App icons generated, but build failed. You may need to build manually in Xcode."
fi

echo ""
echo "📋 Generated files:"
ls -la "$ICON_DIR"/*.png 2>/dev/null || echo "No PNG files found - please check the generation process" 