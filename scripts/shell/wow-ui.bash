#!/usr/bin/env bash
# Save and restore WoW UI settings (the .lua files under WTF/).
#
# The beta client wipes UI/add-on settings on restart. The workaround from the
# Blizzard forums, in three steps:
#
#   flake wow-ui save      # in game: /reload or log out first, then back up
#   flake wow-ui wipe      # before you play: trash every .lua under WTF/
#                          #   then start the client, zone in, go back to
#                          #   character select (this writes fresh .lua files)
#   flake wow-ui restore   # overwrite the fresh files with the backup, log in
#
# WOW_DIR points at the client directory (the one that holds WTF/). The default
# is the Steam Proton path of the classic beta. Backups go to
# $XDG_DATA_HOME/wow-ui/<client dir name>/.
set -euo pipefail
source "${FLAKE:?FLAKE unset — run via the 'flake' wrapper}/scripts/shell/common.sh"

wow_dir="${WOW_DIR:-$HOME/.local/share/Steam/steamapps/compatdata/3026738831/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_}"
wtf="$wow_dir/WTF"
backup="${XDG_DATA_HOME:-$HOME/.local/share}/wow-ui/$(basename -- "$wow_dir")"

[[ -d $wtf ]] || {
    print_error "No WTF folder at: $wtf (set WOW_DIR)"
    exit 1
}

# Mirror only .lua files, keep the directory tree.
lua_sync() { rsync -a --include='*/' --include='*.lua' --exclude='*' --prune-empty-dirs "$1"/ "$2"/; }

case "${1:-}" in
    save)
        print_header "WOW-UI SAVE"
        mkdir -p "$backup"
        lua_sync "$wtf" "$backup"
        print_success "$(find "$backup" -name '*.lua' | wc -l) .lua files -> $backup"
        ;;
    wipe)
        print_header "WOW-UI WIPE"
        mapfile -d '' -t files < <(find "$wtf" -name '*.lua' -print0)
        [[ ${#files[@]} -gt 0 ]] || {
            print_success "Nothing to wipe."
            exit 0
        }
        confirm "Trash ${#files[@]} .lua file(s) under $wtf?" || exit 0
        gio trash -- "${files[@]}"
        print_success "Trashed. Now start WoW, zone in, return to character select, then run: flake wow-ui restore"
        ;;
    restore)
        print_header "WOW-UI RESTORE"
        [[ -d $backup ]] || {
            print_error "No backup at $backup — run 'flake wow-ui save' first"
            exit 1
        }
        confirm "Overwrite .lua files in $wtf from $backup?" || exit 0
        lua_sync "$backup" "$wtf"
        print_success "Restored. Log back into your character."
        ;;
    *)
        echo "usage: wow-ui save|wipe|restore   (WOW_DIR=<client dir> to override)" >&2
        exit 2
        ;;
esac
