#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# build-dmg.sh — Build, sign, notarize, and package Resource Planner
#
# Usage:  ./build-dmg.sh
#
# Prerequisites:
#   - Xcode with Developer ID signing identity
#   - Notarization credentials stored in keychain:
#     xcrun notarytool store-credentials "ResourcePlanner" \
#       --apple-id YOUR_APPLE_ID --team-id 4RQBJ49K9T
# ──────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/Resource Planner"
PROJECT="$PROJECT_DIR/Resource Planner.xcodeproj"
SCHEME="Resource Planner"
BUILD_DIR="/tmp/ResourcePlannerBuild"
DMG_STAGING="/tmp/ResourcePlannerDMG"
DMG_OUTPUT="$SCRIPT_DIR/Resource Planner.dmg"

SIGNING_IDENTITY="Developer ID Application: Thomas Robertson (4RQBJ49K9T)"
TEAM_ID="4RQBJ49K9T"
NOTARY_PROFILE="ResourcePlanner"

APP_PATH="$BUILD_DIR/Build/Products/Release/Resource Planner.app"

# ── Step 1: Build ────────────────────────────────────────────
echo "==> Building Release..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS=--timestamp \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    clean build \
    | tail -3

echo "==> Build succeeded."

# ── Step 2: Verify signing ──────────────────────────────────
echo "==> Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH" 2>&1
echo "    Signature OK."

# ── Step 3: Create DMG ──────────────────────────────────────
echo "==> Creating DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_OUTPUT"
hdiutil create \
    -volname "Resource Planner" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_OUTPUT" \
    | tail -1

echo "    DMG created: $DMG_OUTPUT"

# ── Step 4: Notarize ────────────────────────────────────────
echo "==> Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_OUTPUT" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# ── Step 5: Staple ──────────────────────────────────────────
echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_OUTPUT"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo "==> Done! Notarized DMG at:"
echo "    $DMG_OUTPUT"
echo ""
ls -lh "$DMG_OUTPUT"
