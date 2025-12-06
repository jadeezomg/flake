{ ... }:

{
  imports = [
    ./base.nix
    ./env.nix
    ./theme.nix
    ./aliases.nix
  ];

  programs.nushell = {
    enable = true;
  };

  # Enable zoxide for smart directory navigation
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  # Enable direnv for per-directory environment variables
  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true; # Cache .envrc evaluation for better performance
  };

  programs.yazi = {
    enable = true;
  };

  # Enable fzf for fuzzy finding
  programs.fzf = {
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

}

