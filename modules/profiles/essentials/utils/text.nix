_: {
  programs = {
    fzf = {
      enable = true;
      defaultCommand = "fd --type f --strip-cwd-prefix";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
      fileWidget = {
        command = "fd --type f";
        options = [
          "--preview='bat --color=always --style=plain {}'"
        ];
      };
      changeDirWidget = {
        command = "fd --type d";
        options = [
          "--preview='tree -C {} | head -40'"
        ];
      };
      # Atuin owns Ctrl-R; silence HM conflict warning.
      historyWidget.command = "";
    };
  };
  # https://discourse.nixos.org/t/slow-build-at-building-man-cache/52365/7
  # https://github.com/NixOS/nixpkgs/issues/384499
  # disabled for now because of slow build time & warnings
  programs.man.generateCaches = false;
}
