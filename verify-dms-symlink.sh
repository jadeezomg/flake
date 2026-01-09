#!/usr/bin/env bash
# Script to verify DMS settings.json symlink and ensure it's writing to the flake

FLAKE_DIR=$(dirname "$(readlink -f "$0")")
DMS_CONFIG_FILE="$HOME/.config/DankMaterialShell/settings.json"
FLAKE_CONFIG_FILE="$FLAKE_DIR/home/nixos/desktop/dms/config/settings.json"

echo "=== Verifying DMS settings.json symlink ==="
echo ""

# Check if the config file exists in ~/.config
if [ ! -e "$DMS_CONFIG_FILE" ]; then
    echo "✗ $DMS_CONFIG_FILE does not exist"
    echo "  You may need to rebuild your system first"
    exit 1
fi

# Check if it's a symlink
if [ -L "$DMS_CONFIG_FILE" ]; then
    echo "✓ $DMS_CONFIG_FILE is a symlink"
    target=$(readlink -f "$DMS_CONFIG_FILE")
    echo "  Target: $target"
    
    if [ "$target" = "$(readlink -f "$FLAKE_CONFIG_FILE")" ]; then
        echo "  ✓ Symlink points to the correct flake file"
    else
        echo "  ✗ Symlink points to wrong location!"
        echo "    Expected: $FLAKE_CONFIG_FILE"
        echo "    Actual: $target"
        echo ""
        echo "  To fix, rebuild your system:"
        echo "    nh os switch"
        exit 1
    fi
elif [ -f "$DMS_CONFIG_FILE" ]; then
    echo "✗ $DMS_CONFIG_FILE is a regular file (not a symlink)"
    echo ""
    echo "  This means DMS is writing to a regular file instead of the symlink."
    echo "  To fix:"
    echo "    1. Backup the current file:"
    echo "       cp $DMS_CONFIG_FILE $DMS_CONFIG_FILE.backup"
    echo "    2. Rebuild your system to recreate the symlink:"
    echo "       nh os switch"
    echo "    3. If needed, merge changes from backup to the flake file"
    exit 1
else
    echo "✗ $DMS_CONFIG_FILE exists but is not a file or symlink"
    exit 1
fi

echo ""
echo "=== Testing write access ==="
echo ""

# Test if we can write to the symlink (which should write to the flake file)
if [ -w "$DMS_CONFIG_FILE" ]; then
    echo "✓ File is writable"
    
    # Get modification times
    config_mtime=$(stat -c %Y "$DMS_CONFIG_FILE" 2>/dev/null || stat -f %m "$DMS_CONFIG_FILE" 2>/dev/null)
    flake_mtime=$(stat -c %Y "$FLAKE_CONFIG_FILE" 2>/dev/null || stat -f %m "$FLAKE_CONFIG_FILE" 2>/dev/null)
    
    if [ "$config_mtime" = "$flake_mtime" ]; then
        echo "✓ Modification times match (symlink is working correctly)"
    else
        echo "⚠ Modification times differ:"
        echo "  Config: $(stat -c %y "$DMS_CONFIG_FILE" 2>/dev/null || stat -f %Sm "$DMS_CONFIG_FILE" 2>/dev/null)"
        echo "  Flake:  $(stat -c %y "$FLAKE_CONFIG_FILE" 2>/dev/null || stat -f %Sm "$FLAKE_CONFIG_FILE" 2>/dev/null)"
        echo ""
        echo "  This might indicate the symlink was recently created or the file was modified"
    fi
else
    echo "✗ File is not writable"
    exit 1
fi

echo ""
echo "=== Summary ==="
echo ""
echo "✓ Symlink is correctly configured"
echo "  Edits via DMS GUI should be written to:"
echo "  $FLAKE_CONFIG_FILE"
echo ""
echo "To verify changes are being written:"
echo "  1. Make a change in DMS settings (via GUI)"
echo "  2. Check if the change appears in:"
echo "     $FLAKE_CONFIG_FILE"
echo "  3. If not, check if DMS created a backup or temp file"

