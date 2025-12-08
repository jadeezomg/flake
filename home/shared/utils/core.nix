{ pkgs, ... }:

{
  programs = {
    pay-respects = {
      enable = true;
      enableNushellIntegration = true;
      aiIntegration = false;
      alias = "fuck";
      packages = [ pkgs.pay-respects ];
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };

    direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
    };

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
}
