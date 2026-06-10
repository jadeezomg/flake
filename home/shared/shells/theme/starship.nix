{
  lib,
  osConfig,
  ...
}: let
  themeColors = import ../../../../modules/profiles/theme/theme.nix;

  # Nix doesn't support \uXXXX escapes — use builtins.fromJSON to get real UTF-8.
  u = code: builtins.fromJSON ''"\u${code}"'';

  icons = {
    ellipsis = u "2026"; # …
    chevron = u "276f"; # ❯
    chevron-left = u "276e"; # ❮
    git-branch = u "e725"; #
    dotnet = u "e77f"; #
    go = u "e626"; #
    python = u "e235"; #
    rust = u "e7a8"; #
    node = u "e718"; #
    bun = u "eb5c"; #
    ssh = u "eba9"; #
    nix = u "f313"; #
    nixos = u "f313"; #
    linux = u "f17c"; #
    macos = u "f179"; #
    container = u "f308"; #
    sudo = u "f0e7"; #
    lock = u "f023"; #
    # git status
    git-stash = u "f01c"; #
    git-modified = u "f040"; #
    git-staged = u "f067"; #
    git-untracked = u "f128"; #
    git-renamed = u "f553"; #
    git-deleted = u "f014"; #
    git-conflicted = u "e727"; #
    git-ahead = u "f062"; #
    git-behind = u "f063"; #
    git-diverged = u "f047"; #
  };
in
  lib.mkIf (osConfig.dotfiles.profiles.essentials.enable or true) {
    programs.starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;

      settings = {
        # --- Global options ---
        add_newline = true;
        scan_timeout = 10;
        command_timeout = 1000;
        continuation_prompt = "[:::](dimmed white) ";

        palette = lib.mkForce "birds-of-paradise";

        palettes.birds-of-paradise = {
          bg-primary = themeColors.bg-primary;
          bg-secondary = themeColors.bg-secondary;
          bg-tertiary = themeColors.bg-tertiary;
          text-primary = themeColors.text-primary;
          text-secondary = themeColors.text-secondary;
          accent-blue = themeColors.accent-blue;
          accent-yellow = themeColors.accent-yellow;
          accent-red = themeColors.accent-red;
          ansi-green = themeColors.ansi-green;
          ansi-cyan = themeColors.ansi-cyan;
          ansi-magenta = themeColors.ansi-magenta;
          ansi-red = themeColors.ansi-red;
          ansi-yellow = themeColors.ansi-yellow;
          ansi-bright-blue = themeColors.ansi-bright-blue;
        };

        # --- Prompt format (left block) ---
        format = lib.concatStrings [
          "[ ](accent-blue)"
          "$cmd_duration"
          "$status"
          "$sudo"
          "$os"
          "$username"
          "$hostname"
          "$directory"
          "$git_branch"
          "$git_status"
          "$nix_shell"
          "$container"
          "$dotnet"
          "$golang"
          "$python"
          "$rust"
          "$nodejs"
          "$bun"
          "$fill"
          "$time"
          "\n$shell$character"
        ];

        right_format = "";

        fill = {
          symbol = " ";
        };

        # --- Left segments ---

        cmd_duration = {
          min_time = 321;
          format = "[ $duration ]($style)";
          style = "bg:accent-blue fg:bg-primary";
        };

        status = {
          disabled = false;
          format = "[ $status ](bg:accent-red fg:text-primary)";
        };

        sudo = {
          disabled = false;
          format = "[ ${icons.sudo} ](bg:ansi-yellow fg:bg-primary)";
        };

        os = {
          disabled = false;
          format = "[ $symbol](bg:bg-primary fg:accent-blue)";
        };

        os.symbols = {
          NixOS = "${icons.nixos} ";
          Linux = "${icons.linux} ";
          Macos = "${icons.macos} ";
        };

        username = {
          show_always = true;
          format = "[ $user](bg:bg-primary fg:text-primary)";
        };

        hostname = {
          ssh_only = false;
          format = "[@$hostname ](bg:bg-primary fg:text-primary)";
          ssh_symbol = "${icons.ssh} ";
        };

        directory = {
          format = "[ $path ](bg:bg-tertiary fg:text-primary)";
          repo_root_format = "[ $before_root_path$repo_root$path ](bg:bg-tertiary fg:text-primary)";
          repo_root_style = "bg:bg-tertiary fg:accent-blue bold";
          before_repo_root_style = "bg:bg-tertiary fg:text-primary dimmed";
          truncation_length = 4;
          truncate_to_repo = false;
          truncation_symbol = "${icons.ellipsis} /";
          read_only = " ${icons.lock}";
          style = "bg:bg-tertiary fg:text-primary";
        };

        directory.substitutions = {
          ".dotfiles/flake" = "${icons.nixos} flake";
        };

        git_branch = {
          format = "[ $symbol$branch ](bg:ansi-green fg:bg-primary)";
          symbol = "${icons.git-branch} ";
        };

        git_status = {
          format = "[ $all_status$ahead_behind ](bg:ansi-green fg:bg-primary)";
          stashed = " ${icons.git-stash} ";
          modified = " ${icons.git-modified} ";
          staged = " ${icons.git-staged} ";
          untracked = " ${icons.git-untracked} ";
          renamed = " ${icons.git-renamed} ";
          deleted = " ${icons.git-deleted} ";
          conflicted = " ${icons.git-conflicted} ";
          ahead = " ${icons.git-ahead} ";
          behind = " ${icons.git-behind} ";
          diverged = " ${icons.git-diverged} ";
        };

        # --- Nix / container ---

        nix_shell = {
          format = "[ ${icons.nix} $state ](bg:ansi-bright-blue fg:bg-primary)";
          impure_msg = "impure";
          pure_msg = "pure";
          unknown_msg = "";
        };

        container = {
          format = "[ ${icons.container} $name ](bg:ansi-cyan fg:bg-primary)";
        };

        # --- Language detectors ---

        dotnet = {
          format = "[ $symbol ](bg:ansi-magenta fg:bg-primary)";
          symbol = " ${icons.dotnet} ";
        };

        golang = {
          format = "[ $symbol ](bg:ansi-cyan fg:bg-primary)";
          symbol = " ${icons.go} ";
        };

        python = {
          format = "[ $symbol ](bg:ansi-yellow fg:bg-primary)";
          symbol = " ${icons.python} ";
        };

        rust = {
          format = "[ $symbol ](bg:ansi-red fg:text-primary)";
          symbol = " ${icons.rust} ";
        };

        nodejs = {
          format = "[ $symbol ](bg:ansi-green fg:bg-primary)";
          symbol = " ${icons.node} ";
        };

        bun = {
          format = "[ $symbol ](bg:ansi-yellow fg:bg-primary)";
          symbol = " ${icons.bun} ";
        };

        # --- Right side ---

        time = {
          disabled = false;
          format = "[ $time ](bg:bg-primary fg:accent-blue)";
          time_format = "%H:%M:%S";
        };

        # --- Shell indicator + prompt character ---
        character = {
          success_symbol = "[${icons.chevron}](ansi-green)";
          error_symbol = "[${icons.chevron}](accent-red)";
          vimcmd_symbol = "[${icons.chevron-left}](ansi-green)";
          vimcmd_replace_one_symbol = "[${icons.chevron-left}](ansi-magenta)";
          vimcmd_replace_symbol = "[${icons.chevron-left}](ansi-magenta)";
          vimcmd_visual_symbol = "[${icons.chevron-left}](ansi-yellow)";
        };

        shell = {
          disabled = false;
          bash_indicator = "[#](accent-yellow)";
          fish_indicator = "[~](accent-blue)";
          zsh_indicator = "[%](ansi-magenta)";
          nu_indicator = "[:](ansi-green)";
          format = "$indicator";
        };
      };
    };
  }
