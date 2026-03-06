{
  config,
  pkgs,
  lib,
  isDarwin ? false,
  ...
}: let
  themeColors = import ../../assets/theme/theme.nix;
  sharedConfig = import ./config.nix;
  sharedPaths = import ./paths.nix;

  # All \uXXXX / \ueXXX sequences used in the theme (without leading backslash).
  # When adding new \u or \ue icons below, add the corresponding "uXXXX"/"ueXXX" here.
  # builtins.toJSON can output these as literal "uXXXX" or as UTF-8; we fix both.
  themeUnicodeEscapes = [
    "u001b"
    "u2026"
    "u276f"
    "ue235"
    "ue626"
    "ue628"
    "ue718"
    "ue727"
    "ue728"
    "ue725"
    "ue29b"
    "ue77f"
    "ue7a8"
    "ueba9"
    "ueb5c"
    "uebcc"
    "uf0e7"
    "uf417"
    "uf0c3"
    "uf0e2"
    "uf412"
    "uf6a6"
  ];

  # Placeholder for each escape (must not contain the escape as substring)
  escapePlaceholder = e: "P" + builtins.substring 1 999 e;
  protectedForms = map (e: "\\" + e) themeUnicodeEscapes;
  placeholders = map escapePlaceholder themeUnicodeEscapes;
  jsonEscaped = map (e: "\\" + e) themeUnicodeEscapes;

  poshThemeJsonRaw = builtins.toJSON {
    "$schema" = sharedConfig.ohMyPoshConfig.schemaUrl;
    blocks = [
      {
        alignment = "left";
        segments = [
          {
            background = themeColors.accent-blue;
            foreground = themeColors.bg-primary;
            options = {
              style = "austin";
              threshold = 321;
            };
            style = "plain";
            template = " {{ .FormattedMs }} ";
            type = "executiontime";
          }
          {
            background = themeColors.accent-red;
            foreground = themeColors.text-primary;
            style = "plain";
            template = "{{ if gt .Code 0 }} {{ .Code }} {{ end }}";
            type = "status";
          }
          {
            background = themeColors.accent-yellow;
            foreground = themeColors.bg-primary;
            style = "plain";
            template = "\uf0e7";
            type = "root";
          }
          {
            background = themeColors.bg-primary;
            foreground = themeColors.accent-blue;
            style = "plain";
            template = " {{ if .WSL }}\uebcc {{ end }}{{.Icon}}";
            type = "os";
          }
          {
            background = themeColors.bg-primary;
            foreground = themeColors.text-primary;
            style = "plain";
            template = " {{ if .SSHSession }}\ueba9 {{ end }}{{ .UserName }}@{{ .HostName }} ";
            type = "session";
          }
          {
            background = themeColors.bg-tertiary;
            foreground = themeColors.text-primary;
            options = {
              folder_icon = "\u2026";
              style = "mixed";
            };
            style = "plain";
            template = " {{ .Path }} ";
            type = "path";
          }
          {
            background = themeColors.ansi-green;
            foreground = themeColors.bg-primary;
            options = {
              branch_icon = "\ue725 ";
              cherry_pick_icon = "\ue29b ";
              commit_icon = "\uf417 ";
              fetch_status = false;
              fetch_upstream_icon = false;
              merge_icon = "\ue727 ";
              no_commits_icon = "\uf0c3 ";
              rebase_icon = "\ue728 ";
              revert_icon = "\uf0e2 ";
              tag_icon = "\uf412 ";
            };
            style = "plain";
            template = " {{ .HEAD }} ";
            type = "git";
          }
          {
            background = themeColors.ansi-magenta;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ue77f ";
            type = "dotnet";
          }
          {
            background = themeColors.ansi-cyan;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ue626 ";
            type = "go";
          }
          {
            background = themeColors.ansi-yellow;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ue235 ";
            type = "python";
          }
          {
            background = themeColors.ansi-red;
            foreground = themeColors.text-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ue7a8 ";
            type = "rust";
          }
          {
            background = themeColors.ansi-green;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ue718 ";
            type = "node";
          }
          {
            background = themeColors.ansi-bright-blue;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ue628 ";
            type = "typescript";
          }
          {
            background = themeColors.accent-blue;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \uf6a6 ";
            type = "yarn";
          }
          {
            background = themeColors.ansi-yellow;
            foreground = themeColors.bg-primary;
            options = {
              fetch_version = false;
            };
            style = "plain";
            template = " \ueb5c ";
            type = "bun";
          }
        ];
        type = "prompt";
      }
      {
        alignment = "right";
        segments = [
          {
            background = themeColors.bg-primary;
            foreground = themeColors.accent-blue;
            style = "plain";
            template = " {{ .CurrentDate |date .Format }} ";
            type = "time";
            options = {
              time_format = "15:04:05 MEZ";
            };
          }
        ];
        type = "prompt";
      }
      {
        alignment = "left";
        newline = true;
        segments = [
          {
            style = "plain";
            # Nushell: #6ba18a (ansi-green), Fish: #6b98bb (accent-blue), Bash: #eeac36 (ansi-yellow)
            template = "{{ if eq .Shell \"nushell\" }}\u001b[38;2;107;161;138m:)\u001b[0m{{ else if eq .Shell \"fish\" }}\u001b[38;2;107;152;187m~>\u001b[0m{{ else if eq .Shell \"bash\" }}\u001b[38;2;238;172;54m$\u001b[0m{{ else if eq .Shell \"zsh\" }}\u001b[38;2;107;152;187m%\u001b[0m{{ else if eq .Shell \"pwsh\" }}\u001b[38;2;107;152;187m\u276f\u001b[0m{{ else }}{{ .Name }}{{ end }} ";
            type = "shell";
          }
        ];
        type = "prompt";
      }
    ];
    version = 4;
  };

  # Fix Unicode in generated JSON. On Darwin, toJSON often breaks \uXXXX (shows "u2026" etc. in prompt),
  # so we run the full 4-step fix. On NixOS the old setup worked; only fix the ANSI ESC u001b.
  charFromEscape = e: builtins.fromJSON ("\"\\" + e + "\"");
  themeUnicodeChars = map charFromEscape themeUnicodeEscapes;

  poshThemeJson =
    if isDarwin
    then
      let
        # 1) Protect already-correct \uXXXX (if present) with placeholders
        protected = builtins.replaceStrings protectedForms placeholders poshThemeJsonRaw;
        # 2) Fix literal "uXXXX" (no backslash) -> proper JSON escape
        fixed = builtins.replaceStrings themeUnicodeEscapes jsonEscaped protected;
        # 3) Replace UTF-8 chars (if toJSON wrote them) with JSON escape
        withEscapes = builtins.replaceStrings themeUnicodeChars jsonEscaped fixed;
        # 4) Restore placeholders
        restored = builtins.replaceStrings placeholders jsonEscaped withEscapes;
      in
        restored
    else
      # NixOS: only fix ANSI escape so shell prompt colors work
      builtins.replaceStrings ["u001b"] ["\\u001b"] poshThemeJsonRaw;
in {
  # Install oh-my-posh package
  home.packages = with pkgs; [
    oh-my-posh
  ];

  # Create theme configuration file
  home.file."${sharedConfig.ohMyPoshConfig.configDir}/${sharedConfig.ohMyPoshConfig.themeName}" = {
    text = poshThemeJson;
  };
}
