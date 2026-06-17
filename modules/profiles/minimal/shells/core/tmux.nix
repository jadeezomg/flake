{
  config,
  pkgs,
  hostKey ? "unknown",
  ...
}: let
  flakeRoot = config.dotfiles.flakeRoot;
in {
  # tmux is a shell baseline: every host gets the multiplexer, while sesh owns
  # runtime session discovery/creation. Sessions are runtime state, not Nix
  # services; keep only durable entry points declarative here.
  programs.tmux = {
    enable = true;
    package = pkgs.tmux;

    clock24 = true;
    focusEvents = true;
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";

    extraConfig = ''
      set -g detach-on-destroy off
      set -g renumber-windows on
      set -g set-clipboard on
      set -g status-interval 5
      set -as terminal-overrides ',*:RGB'

      bind-key r source-file ~/.config/tmux/tmux.conf \; display-message 'tmux config reloaded'
      bind-key c new-window -c '#{pane_current_path}'
      bind-key '|' split-window -h -c '#{pane_current_path}'
      bind-key '-' split-window -v -c '#{pane_current_path}'
      bind-key x kill-pane
      bind-key T display-popup -E -w 80% -h 70% -d '#{pane_current_path}' -T 'Sesh' 'tv sesh'
    '';
  };

  programs.fzf.tmux.enableShellIntegration = true;

  programs.sesh = {
    enable = true;
    enableAlias = true;
    enableTmuxIntegration = true;
    package = pkgs.sesh;
    fzfPackage = pkgs.fzf;
    zoxidePackage = pkgs.zoxide;
    tmuxKey = "s";
    icons = true;

    settings = {
      cache = true;
      dir_length = 2;
      sort_order = [
        "tmux"
        "config"
        "zoxide"
      ];

      tui = {
        prompt = "⚡ ";
        placeholder = "Pick session";
        show_icons = true;
      };

      default_session.preview_command = "eza --all --git --icons --color=always {}";

      session = [
        {
          name = "flake";
          path = flakeRoot;
          preview_command = "bat --style=plain --color=always ${flakeRoot}/CONTEXT.md";
        }
        {
          name = "host-${hostKey}";
          path = "${flakeRoot}/hosts/${hostKey}";
          preview_command = "eza --all --git --icons --color=always ${flakeRoot}/hosts/${hostKey}";
        }
      ];
    };
  };

  home.shellAliases = {
    ta = "tmux attach || tmux new";
    tl = "tmux list-sessions";
  };
}
