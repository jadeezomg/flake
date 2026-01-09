#!/usr/bin/env bash
# Script to check if DMS and Niri config symlinks are set up correctly

echo "=== Checking DMS Config Symlinks ==="
echo ""
echo "Checking ~/.config/DankMaterialShell/ symlinks:"
if [ -d ~/.config/DankMaterialShell ]; then
    for file in ~/.config/DankMaterialShell/*; do
        if [ -L "$file" ]; then
            target=$(readlink -f "$file")
            echo "  ✓ $(basename "$file") -> $target"
            if [ -f "$target" ]; then
                echo "    ✓ Target file exists"
            else
                echo "    ✗ Target file missing!"
            fi
        elif [ -f "$file" ]; then
            echo "  ✗ $(basename "$file") is a regular file (not a symlink)"
        fi
    done
else
    echo "  ✗ ~/.config/DankMaterialShell/ directory does not exist"
fi

echo ""
echo "=== Checking Niri Config Symlinks ==="
echo ""
echo "Checking ~/.config/niri/ symlinks:"
if [ -d ~/.config/niri ]; then
    for file in ~/.config/niri/*; do
        if [ -L "$file" ]; then
            target=$(readlink -f "$file")
            echo "  ✓ $(basename "$file") -> $target"
            if [ -f "$target" ]; then
                echo "    ✓ Target file exists"
            else
                echo "    ✗ Target file missing!"
            fi
        elif [ -f "$file" ]; then
            echo "  ✗ $(basename "$file") is a regular file (not a symlink)"
        fi
    done
else
    echo "  ✗ ~/.config/niri/ directory does not exist"
fi

echo ""
echo "=== Checking Quickshell Config ==="
echo ""
if [ -L ~/.config/quickshell/config.kdl ]; then
    target=$(readlink -f ~/.config/quickshell/config.kdl)
    echo "  ✓ ~/.config/quickshell/config.kdl -> $target"
    if [ -f "$target" ]; then
        echo "    ✓ Target file exists"
    else
        echo "    ✗ Target file missing!"
    fi
elif [ -f ~/.config/quickshell/config.kdl ]; then
    echo "  ✗ ~/.config/quickshell/config.kdl is a regular file (not a symlink)"
else
    echo "  ⚠ ~/.config/quickshell/config.kdl does not exist"
fi

echo ""
echo "=== Summary ==="
echo ""
echo "Expected symlinks:"
echo "  ~/.config/DankMaterialShell/* -> ~/.dotfiles/flake/home/nixos/desktop/dms/config/*"
echo "  ~/.config/niri/* -> ~/.dotfiles/flake/home/nixos/desktop/niri/*"
echo "  ~/.config/quickshell/config.kdl -> ~/.dotfiles/flake/home/nixos/desktop/dms/config/config.kdl"
echo ""
echo "To test if changes are reflected:"
echo "  1. Edit a file in ~/.dotfiles/flake/home/nixos/desktop/dms/config/"
echo "  2. Check if the change appears in ~/.config/DankMaterialShell/ immediately"

