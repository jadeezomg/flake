{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "shell"
  ];
  packages =
    pkgs: with pkgs; [
      # bash — bash-language-server is the front-end; it calls shellcheck for
      # diagnostics and shfmt for formatting, both resolved from PATH.
      # Wired into helix, Zed, and VSCode.
      bash-language-server
      shellcheck
      shfmt
    ];
} args
