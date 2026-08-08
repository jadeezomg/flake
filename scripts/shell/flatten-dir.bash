#!/usr/bin/env bash
# Move every file from the subdirectories of the target directory into it.
#
# A file is skipped when its name is already taken, so nothing is overwritten.
# Two subdirectories can hold the same name: the first one wins, the second is
# skipped. Empty subdirectories stay behind.
#
#   flake flatten-dir-dry                # preview the current shell directory
#   flake flatten-dir                    # move the files
#   flake flatten-dir /path/to/dir       # work on another directory
#
# The target does not come from the working directory. The recipe passes
# FLATTEN_DIR_FROM=`invocation_directory()`, because the working directory is
# not reliable: just starts in the directory of the justfile unless the recipe
# carries `[no-cd]`, and the `tv just-recipes` picker runs recipes through
# `bash -lc`, which starts a login shell somewhere else again. An explicit
# directory argument wins over both.
set -euo pipefail
source "${FLAKE:?FLAKE unset — run via the 'flake' wrapper}/scripts/shell/common.sh"

dry_run=false
target=""

for arg in "$@"; do
    case "$arg" in
        -n | --dry-run) dry_run=true ;;
        -*)
            print_error "Unknown option: $arg"
            exit 2
            ;;
        *) target="$arg" ;;
    esac
done

# Precedence: explicit argument, then the directory just was invoked from, then
# the working directory.
target="${target:-${FLATTEN_DIR_FROM:-$PWD}}"

if [[ ! -d $target ]]; then
    print_error "Not a directory: $target"
    exit 1
fi

cd -- "$target"

print_header "FLATTEN"
print_info "Target: $PWD"

# Read the whole list before the first move. find must not walk a tree that
# changes under it.
files=()
mapfile -d '' -t files < <(find . -mindepth 2 -type f -print0)

if [[ ${#files[@]} -eq 0 ]]; then
    print_success "No files in subdirectories."
    print_header "END"
    exit 0
fi

if [[ $dry_run == false ]]; then
    confirm "Move ${#files[@]} file(s) into $PWD?" || {
        print_error "Cancelled."
        exit 0
    }
fi

moved=0
skipped=0
# Names claimed by earlier files in this run. The dry run needs this set too,
# because it moves nothing for the next test to find.
declare -A taken=()

for src in "${files[@]}"; do
    name="$(basename -- "$src")"
    dest="./$name"
    # -e is false for a broken symlink, so test -L too.
    if [[ -e $dest || -L $dest || -n ${taken[$name]-} ]]; then
        print_error "skip  ${src#./} — name taken"
        skipped=$((skipped + 1))
        continue
    fi
    taken[$name]=1
    if [[ $dry_run == true ]]; then
        print_info "would move  ${src#./}"
    else
        mv -- "$src" "$dest"
        print_success "moved ${src#./}"
    fi
    moved=$((moved + 1))
done

echo ""
print_info "$moved moved, $skipped skipped"
print_header "END"
