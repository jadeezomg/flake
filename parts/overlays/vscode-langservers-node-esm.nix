# vscode-langservers-extracted 4.x (npm bundle) ships minified servers whose output
# contains `import.meta` tokens. Node 22+/24 auto-detects ESM and crashes on the
# first `require()` with "require is not defined in ES module scope" — Zed surfaces
# this as json-language-server / css / html failures.
#
# nixpkgs >= 1.121 repackages servers from VSCodium with node binary wrappers and
# a different layout under lib/extensions/…; skip patching when those paths are used.
_final: prev: {
  vscode-langservers-extracted = prev.vscode-langservers-extracted.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      root="$out/lib/node_modules/vscode-langservers-extracted/lib"
      if [ -f "$root/json-language-server/node/jsonServerMain.js" ]; then
        for f in \
          "$root/json-language-server/node/jsonServerMain.js" \
          "$root/css-language-server/node/cssServerMain.js" \
          "$root/html-language-server/node/htmlServerMain.js"; do
          substituteInPlace "$f" \
            --replace-quiet "import.meta.dirname" "__dirname" \
            --replace-quiet "import.meta.url" "__filename"
          if grep -q "import\.meta" "$f"; then
            echo "ERROR: unhandled import.meta token remains in $f" >&2
            grep -oE ".{40}import\.meta.{40}" "$f" >&2
            exit 1
          fi
        done
      fi
    '';
  });
}
