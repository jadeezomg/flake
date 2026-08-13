{
  config,
  dotfilesLib,
  pkgs,
  lib,
  ...
}:
let
  aliases = (import ./data/aliases.nix).commonAliases;
  paths = dotfilesLib.shellPaths.commonPaths;

  configRel = builtins.replaceStrings [ "$HOME/" ] [ "" ] paths.config;
  downloadsRel = builtins.replaceStrings [ "$HOME/" ] [ "" ] paths.downloads;
  # Local git shortcuts. Keep these boring: shell conveniences should not pull
  # mutable upstream source into the system closure.
in
{
  programs.nushell = {
    enable = true;
    shellAliases =
      aliases
      // {
        # The sesh HM module's `enableAlias` emits `sesh connect $(...)`, which is
        # valid POSIX command substitution for bash/fish but a parse error in
        # nushell (it uses `(...)` subexpressions). `home.shellAliases` is fed into
        # every shell via home-environment.nix, so override just the nushell form.
        s = lib.mkForce "sesh connect (sesh list --icons | fzf --ansi)";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        trash = "gio trash";
      };

    settings = {
      show_banner = false;

      history = {
        max_size = 100000;
        sync_on_enter = true;
        file_format = "sqlite";
        isolation = false;
      };

      completions = {
        case_sensitive = false;
        quick = true;
        partial = true;
        algorithm = "fuzzy";
        external = {
          enable = true;
          max_results = 100;
          completer = null;
        };
      };
    };

    extraConfig = ''
      def gs [...args: string] { ^git status ...$args }
      def gl [...args: string] { ^git log --oneline --decorate --graph ...$args }
      def gb [...args: string] { ^git branch ...$args }
      def gp [...args: string] { ^git push ...$args }
      def ga [...args: string] { ^git add ...$args }
      def gc [...args: string] { ^git commit -v ...$args }
      def gd [...args: string] { ^git diff ...$args }
      def gm [...args: string] { ^git merge ...$args }
      def gr [...args: string] {
        if ($args | is-empty) {
          ^git remote -v
        } else {
          ^git remote ...$args
        }
      }
      def --env zz [] { cd ''$env.HOME }
      def --env zc [] { cd $"(''$env.HOME)/${configRel}" }
      def --env zd [] { cd $"(''$env.HOME)/${downloadsRel}" }
      def p [...question: string] {
        let prompt = ($question | str join " ")
        let input = $in
        if ($input | is-empty) {
          pi -p $prompt
        } else {
          $input | pi -p $prompt
        }
      }
    '';
  };

  # nushell resolves its config dir to `$XDG_CONFIG_HOME/nushell` when the var
  # is set, else the macOS-native `~/Library/Application Support/nushell`. With
  # `xdg.enable = true` HM writes config only to `~/.config/nushell`, so a nu
  # launched before XDG_CONFIG_HOME is exported (login-shell / first terminal at
  # login, before the launchd `xdg-env` agent wins the race) falls back to the
  # Library path, finds nothing, and starts with stock defaults + banner.
  # Mirror the live config files into the Library path so nu is initialized in
  # BOTH resolution modes, independent of the env var.
  home.file = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.genAttrs
      [
        "Library/Application Support/nushell/config.nu"
        "Library/Application Support/nushell/env.nu"
      ]
      (name: {
        source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/nushell/${baseNameOf name}";
      })
  );
}
