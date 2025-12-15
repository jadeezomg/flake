#!/usr/bin/env bash

# Script to update Pear Desktop to the latest version
# Run this before building to ensure you have the latest version
set -e

echo "🔍 Fetching latest Pear Desktop release info..."

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required. Install with: nix-shell -p jq"
    exit 1
fi

RELEASE_INFO=$(curl -s https://api.github.com/repos/pear-devs/pear-desktop/releases/latest)

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to fetch release info from GitHub API"
    exit 1
fi

VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name' | sed 's/^v//')
echo "📦 Latest version: $VERSION"

# Find the AppImage asset (x86_64)
APPIMAGE_ASSET=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | test(\"YouTube-Music-${VERSION}.AppImage$\"))")

if [ -z "$APPIMAGE_ASSET" ] || [ "$APPIMAGE_ASSET" = "null" ]; then
    echo "❌ Error: No AppImage found for version $VERSION"
    echo "Available assets:"
    echo "$RELEASE_INFO" | jq -r '.assets[].name'
    exit 1
fi

URL=$(echo "$APPIMAGE_ASSET" | jq -r '.browser_download_url')
SHA512=$(echo "$APPIMAGE_ASSET" | jq -r '.sha512')

if [ -z "$SHA512" ] || [ "$SHA512" = "null" ]; then
    echo "⚠️  Warning: No SHA512 hash found in release, downloading to calculate..."
    # Download and calculate SHA512 if not provided
    TMP_FILE=$(mktemp)
    curl -L -o "$TMP_FILE" "$URL"
    SHA512=$(sha512sum "$TMP_FILE" | cut -d' ' -f1)
    rm "$TMP_FILE"
    echo "✅ Calculated SHA512: $SHA512"
else
    echo "✅ Found SHA512: $SHA512"
fi

echo "🔗 URL: $URL"

# Backup original file
cp overlays/pear-desktop.nix overlays/pear-desktop.nix.backup

# Update the nix file
sed -i "s/version = \"[^\"]*\";/version = \"$VERSION\";/" overlays/pear-desktop.nix
sed -i "s/sha512 = \"[^\"]*\";/sha512 = \"$SHA512\";/" overlays/pear-desktop.nix

echo "✅ Updated overlays/pear-desktop.nix to version $VERSION"
echo ""
echo "🧪 Test the build with:"
echo "   nix build .#packages.x86_64-linux.pear-desktop"
echo ""
echo "💾 To restore backup:"
echo "   mv overlays/pear-desktop.nix.backup overlays/pear-desktop.nix"
