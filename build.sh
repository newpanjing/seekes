#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJECT_DIR/ElasticClient"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="SeekES"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🧹 Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "📦 Collecting Swift source files..."
SWIFT_FILES=$(find "$SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')

echo "🔨 Compiling Swift sources..."
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
TARGET="arm64-apple-macosx14.0"

swiftc \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    -framework Combine \
    -o "$MACOS_DIR/$APP_NAME" \
    $SWIFT_FILES

echo "📋 Copying Info.plist..."
cp "$SRC_DIR/Info-Static.plist" "$CONTENTS_DIR/Info.plist"

echo "🎨 Copying resources..."
if [ -d "$SRC_DIR/Assets.xcassets" ]; then
    cp -R "$SRC_DIR/Assets.xcassets" "$RESOURCES_DIR/"
fi
for locale_dir in "$SRC_DIR"/*.lproj; do
    if [ -d "$locale_dir" ]; then
        cp -R "$locale_dir" "$RESOURCES_DIR/"
    fi
done

echo "📝 Creating PkgInfo..."
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "✅ Build complete!"
echo "📍 App bundle: $APP_BUNDLE"
echo ""
if [ "${SKIP_OPEN:-0}" != "1" ]; then
    echo "🚀 Launching app..."
    open "$APP_BUNDLE"
fi
