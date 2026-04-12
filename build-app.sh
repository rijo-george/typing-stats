#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: RIJO GEORGE (K8383Q54VB)}"
TEAM_ID="${TEAM_ID:-K8383Q54VB}"
SCHEME="TypingStats"
PROJECT="TypingStats.xcodeproj"

BUILD_DIR="$SCRIPT_DIR/build"

echo "==> Building Typing Stats..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    clean build 2>&1

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "Typing Stats.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "!! Could not find built app"
    exit 1
fi

FINAL_APP="$BUILD_DIR/Typing Stats.app"
rm -rf "$FINAL_APP"
cp -R "$APP_PATH" "$FINAL_APP"

echo "==> Code signing..."
codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$FINAL_APP"

echo "==> Verifying signature..."
codesign --verify --verbose "$FINAL_APP"

echo ""
echo "Built and signed: $FINAL_APP"
echo "Run with: open \"$FINAL_APP\""
