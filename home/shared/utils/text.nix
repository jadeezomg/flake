{...}: {
  programs = {
    fzf = {
      enable = true;
      defaultCommand = "fd --type f --strip-cwd-prefix";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
        "--preview='bat --color=always --style=plain {}'"
      ];
      fileWidgetCommand = "fd --type f";
      fileWidgetOptions = [
        "--preview='bat --color=always --style=plain {}'"
      ];
      changeDirWidgetCommand = "fd --type d";
      changeDirWidgetOptions = [
        "--preview='tree -C {} | head -40'"
      ];
    };
  };
  # https://discourse.nixos.org/t/slow-build-at-building-man-cache/52365/7
  # https://github.com/NixOS/nixpkgs/issues/384499
  # disabled for now because of slow build time & warnings
  programs.man.generateCaches = false;
}
