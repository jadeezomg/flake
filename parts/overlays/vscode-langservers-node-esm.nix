# vscode-langservers-extracted 4.10.0 ships Babel-bundled language servers
# (json/css/html) whose minified output contains `import.meta` tokens
# (`import.meta.url` for createRequire, `import.meta.dirname` in the html
# server). Under Node's CJS loader (seen with both nodejs_22 and nodejs_24)
# a lone `import.meta` token makes Node auto-detect the file as ESM when it is
# `require()`d, then crash on the first `require` call with "require is not
# defined in ES module scope". This breaks Zed's json-language-server (and
# would break the css/html servers the same way).
#
# These files actually run as CommonJS, where `__filename`/`__dirname` are
# defined (and `__filename` is an accepted argument to createRequire), so swap
# the tokens in. Drop this overlay once nixpkgs (or upstream's Babel config)
# stops emitting `import.meta` here.
_final: prev: {
  vscode-langservers-extracted = prev.vscode-langservers-extracted.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        root="$out/lib/node_modules/vscode-langservers-extracted/lib"
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
      '';
  });
}
