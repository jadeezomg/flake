# Default desktop applications (XDG MIME defaults) for desktop hosts.
#
# Handler ids live in one attrset option, `dotfiles.desktop.mimeHandlers`, so an
# app profile can claim its own role. This file sets the baseline with
# lib.mkDefault (priority 1000). An app profile that owns a role sets it with
# lib.mkOverride 900: that beats the baseline and still loses to a plain host
# assignment. The notes profile does this for `markdown` (Typora).
#
# Yazi reads `markdown` from the same option (essentials/utils/yazi), so the
# TUI open-with rule and the XDG default stay in sync.
#
# Feature profiles install tools. They do not own global MIME policy. Headless
# hosts have none of these apps, so the whole table is gated on the desktop
# profile.
{ config, lib, ... }:
let
  cfg = config.dotfiles.profiles.desktop;
  h = config.dotfiles.desktop.mimeHandlers;
in
{
  options.dotfiles.desktop.mimeHandlers =
    let
      inherit (lib) mkOption types;
    in
    {
      editor = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "dev.zed.Zed";
        description = "Desktop id (without .desktop) that opens: Text, code, config, and data files.";
      };
      browser = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "zen-twilight";
        description = "Desktop id (without .desktop) that opens: HTML and the http, https, mailto schemes.";
      };
      markdown = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "typora";
        description = "Desktop id (without .desktop) that opens: Markdown documents.";
      };
      image = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.gnome.Loupe";
        description = "Desktop id (without .desktop) that opens: Images.";
      };
      pdf = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.gnome.Papers";
        description = "Desktop id (without .desktop) that opens: PDF documents.";
      };
      video = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.gnome.Showtime";
        description = "Desktop id (without .desktop) that opens: Video.";
      };
      audio = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.gnome.Music";
        description = "Desktop id (without .desktop) that opens: Audio.";
      };
      fileManager = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.gnome.Nautilus";
        description = "Desktop id (without .desktop) that opens: Directories.";
      };
      archive = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "org.gnome.FileRoller";
        description = "Desktop id (without .desktop) that opens: Archives.";
      };
    };

  config = lib.mkIf cfg.enable {
    dotfiles.desktop.mimeHandlers = {
      editor = lib.mkDefault "dev.zed.Zed";
      browser = lib.mkDefault "zen-twilight";
      # Falls back to the editor. The notes profile raises this to Typora.
      markdown = lib.mkDefault h.editor;
      image = lib.mkDefault "org.gnome.Loupe";
      pdf = lib.mkDefault "org.gnome.Papers";
      video = lib.mkDefault "org.gnome.Showtime";
      audio = lib.mkDefault "org.gnome.Music";
      fileManager = lib.mkDefault "org.gnome.Nautilus";
      archive = lib.mkDefault "org.gnome.FileRoller";
    };

    home-manager.sharedModules = [
      {
        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            # General
            "inode/directory" = [ "${h.fileManager}.desktop" ];
            "text/x-nushell" = [ "${h.editor}.desktop" ];
            "application/x-nushell" = [ "${h.editor}.desktop" ];
            "application/pdf" = [ "${h.pdf}.desktop" ];
            "application/x-zerosize" = [ "${h.editor}.desktop" ];
            # Archives
            "application/zip" = [ "${h.archive}.desktop" ];
            "application/x-zip" = [ "${h.archive}.desktop" ];
            "application/x-zip-compressed" = [ "${h.archive}.desktop" ];
            "application/vnd.rar" = [ "${h.archive}.desktop" ];
            "application/x-rar" = [ "${h.archive}.desktop" ];
            "application/x-rar-compressed" = [ "${h.archive}.desktop" ];
            "application/x-7z-compressed" = [ "${h.archive}.desktop" ];
            "application/x-tar" = [ "${h.archive}.desktop" ];
            "application/x-compressed-tar" = [ "${h.archive}.desktop" ];
            "application/gzip" = [ "${h.archive}.desktop" ];
            "application/x-gzip" = [ "${h.archive}.desktop" ];
            "application/bzip2" = [ "${h.archive}.desktop" ];
            "application/x-bzip" = [ "${h.archive}.desktop" ];
            "application/x-xz" = [ "${h.archive}.desktop" ];
            "application/zstd" = [ "${h.archive}.desktop" ];

            # Audio
            "audio/flac" = [ "${h.audio}.desktop" ];
            "audio/mp3" = [ "${h.audio}.desktop" ];
            "audio/mp4" = [ "${h.audio}.desktop" ];
            "audio/mpeg" = [ "${h.audio}.desktop" ];
            "audio/ogg" = [ "${h.audio}.desktop" ];
            "audio/x-m4a" = [ "${h.audio}.desktop" ];
            "audio/x-wav" = [ "${h.audio}.desktop" ];

            # Image
            "image/bmp" = [ "${h.image}.desktop" ];
            "image/gif" = [ "${h.image}.desktop" ];
            "image/jpeg" = [ "${h.image}.desktop" ];
            "image/png" = [ "${h.image}.desktop" ];
            "image/svg+xml" = [ "${h.image}.desktop" ];
            "image/tiff" = [ "${h.image}.desktop" ];
            "image/webp" = [ "${h.image}.desktop" ];
            "image/heic" = [ "${h.image}.desktop" ];
            "image/avif" = [ "${h.image}.desktop" ];

            # Video
            "video/avi" = [ "${h.video}.desktop" ];
            "video/mp4" = [ "${h.video}.desktop" ];
            "video/ogg" = [ "${h.video}.desktop" ];
            "video/webm" = [ "${h.video}.desktop" ];
            "video/x-matroska" = [ "${h.video}.desktop" ];
            "video/x-msvideo" = [ "${h.video}.desktop" ];

            # Web
            "text/html" = [ "${h.browser}.desktop" ];
            "x-scheme-handler/mailto" = [ "${h.browser}.desktop" ];
            "application/x-extension-htm" = [ "${h.browser}.desktop" ];
            "application/x-extension-html" = [ "${h.browser}.desktop" ];
            "application/x-extension-shtml" = [ "${h.browser}.desktop" ];
            "application/x-extension-xht" = [ "${h.browser}.desktop" ];
            "application/x-extension-xhtml" = [ "${h.browser}.desktop" ];
            "application/xhtml+xml" = [ "${h.browser}.desktop" ];
            "x-scheme-handler/chrome" = [ "${h.browser}.desktop" ];
            "x-scheme-handler/http" = [ "${h.browser}.desktop" ];
            "x-scheme-handler/https" = [ "${h.browser}.desktop" ];

            # Programming Languages - All use editor
            "text/plain" = [ "${h.editor}.desktop" ];
            "text/x-shellscript" = [ "${h.editor}.desktop" ];
            "text/x-script.python" = [ "${h.editor}.desktop" ];
            "text/x-script.bash" = [ "${h.editor}.desktop" ];
            "text/x-c" = [ "${h.editor}.desktop" ];
            "text/x-c++" = [ "${h.editor}.desktop" ];
            "text/x-java" = [ "${h.editor}.desktop" ];
            "text/x-java-source" = [ "${h.editor}.desktop" ];
            "text/x-pascal" = [ "${h.editor}.desktop" ];
            "text/x-script.perl" = [ "${h.editor}.desktop" ];
            "text/x-script.ruby" = [ "${h.editor}.desktop" ];
            "text/x-rust" = [ "${h.editor}.desktop" ];
            "text/x-haskell" = [ "${h.editor}.desktop" ];
            "text/x-literate-haskell" = [ "${h.editor}.desktop" ];
            "text/x-lua" = [ "${h.editor}.desktop" ];
            "text/x-php" = [ "${h.editor}.desktop" ];
            "text/x-ruby" = [ "${h.editor}.desktop" ];
            "text/x-python" = [ "${h.editor}.desktop" ];
            "text/x-R" = [ "${h.editor}.desktop" ];
            "text/x-scala" = [ "${h.editor}.desktop" ];
            "text/x-scheme" = [ "${h.editor}.desktop" ];
            "text/x-typescript" = [ "${h.editor}.desktop" ];
            "text/javascript" = [ "${h.editor}.desktop" ];
            "text/x-csrc" = [ "${h.editor}.desktop" ];
            "text/x-chdr" = [ "${h.editor}.desktop" ];
            "text/x-c++src" = [ "${h.editor}.desktop" ];
            "text/x-c++hdr" = [ "${h.editor}.desktop" ];
            "text/x-csharp" = [ "${h.editor}.desktop" ];
            "text/x-go" = [ "${h.editor}.desktop" ];
            "text/x-fortran" = [ "${h.editor}.desktop" ];
            "text/x-erlang" = [ "${h.editor}.desktop" ];
            "text/x-elixir" = [ "${h.editor}.desktop" ];
            "text/x-diff" = [ "${h.editor}.desktop" ];
            "text/x-dart" = [ "${h.editor}.desktop" ];
            "text/x-cmake" = [ "${h.editor}.desktop" ];
            "text/x-clojure" = [ "${h.editor}.desktop" ];

            # Config Files
            "application/json" = [ "${h.editor}.desktop" ];
            "application/toml" = [ "${h.editor}.desktop" ];
            "application/x-yaml" = [ "${h.editor}.desktop" ];
            "text/yaml" = [ "${h.editor}.desktop" ];
            "text/x-ini" = [ "${h.editor}.desktop" ];
            "application/xml" = [ "${h.editor}.desktop" ];
            "text/xml" = [ "${h.editor}.desktop" ];
            "application/x-wine-extension-ini" = [ "${h.editor}.desktop" ];
            "application/vnd.coffeescript" = [ "${h.editor}.desktop" ];
            "application/x-ndjson" = [ "${h.editor}.desktop" ];
            "application/ld+json" = [ "${h.editor}.desktop" ];

            # Web Development
            "text/css" = [ "${h.editor}.desktop" ];
            "text/scss" = [ "${h.editor}.desktop" ];
            "text/sass" = [ "${h.editor}.desktop" ];
            "text/less" = [ "${h.editor}.desktop" ];
            "application/javascript" = [ "${h.editor}.desktop" ];
            "application/typescript" = [ "${h.editor}.desktop" ];
            "application/x-typescript" = [ "${h.editor}.desktop" ];
            "application/x-httpd-php" = [ "${h.editor}.desktop" ];
            "application/x-php" = [ "${h.editor}.desktop" ];
            "application/jsx" = [ "${h.editor}.desktop" ];
            "application/x-jsx" = [ "${h.editor}.desktop" ];
            "application/tsx" = [ "${h.editor}.desktop" ];
            "application/x-tsx" = [ "${h.editor}.desktop" ];
            "application/graphql" = [ "${h.editor}.desktop" ];
            "application/wasm" = [ "${h.editor}.desktop" ];

            # Documentation & Markup
            "text/markdown" = [ "${h.markdown}.desktop" ];
            "text/x-markdown" = [ "${h.markdown}.desktop" ];
            "text/x-rst" = [ "${h.editor}.desktop" ];
            "text/x-tex" = [ "${h.editor}.desktop" ];
            "text/x-latex" = [ "${h.editor}.desktop" ];
            "application/x-tex" = [ "${h.editor}.desktop" ];
            "application/x-latex" = [ "${h.editor}.desktop" ];
            "text/asciidoc" = [ "${h.editor}.desktop" ];
            "text/x-org" = [ "${h.editor}.desktop" ];
            "text/x-textile" = [ "${h.editor}.desktop" ];
            "application/x-rmarkdown" = [ "${h.editor}.desktop" ];
            "application/x-jupyter-notebook+json" = [ "${h.editor}.desktop" ];

            # Database & Data
            "application/sql" = [ "${h.editor}.desktop" ];
            "text/x-sql" = [ "${h.editor}.desktop" ];
            "text/csv" = [ "${h.editor}.desktop" ];
            "text/tab-separated-values" = [ "${h.editor}.desktop" ];
            "application/vnd.sqlite3" = [ "${h.editor}.desktop" ];
            "application/x-sqlite3" = [ "${h.editor}.desktop" ];

            # Shell/System
            "application/x-sh" = [ "${h.editor}.desktop" ];
            "application/x-shellscript" = [ "${h.editor}.desktop" ];
            "application/x-desktop" = [ "${h.editor}.desktop" ];
            "application/x-executable" = [ "${h.editor}.desktop" ];
            "text/x-makefile" = [ "${h.editor}.desktop" ];
            "text/x-meson" = [ "${h.editor}.desktop" ];
            "text/x-cmake-project" = [ "${h.editor}.desktop" ];
            "application/x-perl" = [ "${h.editor}.desktop" ];
            "application/x-ruby" = [ "${h.editor}.desktop" ];
            "application/x-python" = [ "${h.editor}.desktop" ];
            "application/x-bash" = [ "${h.editor}.desktop" ];
            "application/x-zsh" = [ "${h.editor}.desktop" ];
            "application/x-systemd-unit" = [ "${h.editor}.desktop" ];

            # Version Control
            "text/x-patch" = [ "${h.editor}.desktop" ];
            "text/x-git-config" = [ "${h.editor}.desktop" ];
            "text/x-hg-config" = [ "${h.editor}.desktop" ];
            "text/x-svn-config" = [ "${h.editor}.desktop" ];

            # DevOps & Infrastructure
            "application/x-docker" = [ "${h.editor}.desktop" ];
            "text/x-dockerfile" = [ "${h.editor}.desktop" ];
            "application/x-terraform" = [ "${h.editor}.desktop" ];
            "application/x-ansible" = [ "${h.editor}.desktop" ];
            "application/x-vagrant-vagrantfile" = [ "${h.editor}.desktop" ];
            "application/x-jenkins" = [ "${h.editor}.desktop" ];
            "application/vnd.kubernetes.helm.chart" = [ "${h.editor}.desktop" ];
            "text/x-nginx-conf" = [ "${h.editor}.desktop" ];
            "text/x-apache-conf" = [ "${h.editor}.desktop" ];

            # Mobile Development
            "application/x-kotlin" = [ "${h.editor}.desktop" ];
            "text/x-kotlin" = [ "${h.editor}.desktop" ];
            "application/x-swift" = [ "${h.editor}.desktop" ];
            "text/x-swift" = [ "${h.editor}.desktop" ];
            "application/x-objective-c" = [ "${h.editor}.desktop" ];
            "text/x-objective-c" = [ "${h.editor}.desktop" ];

            # Game Development
            "application/x-godot-resource" = [ "${h.editor}.desktop" ];
            "application/x-unity3d-scene" = [ "${h.editor}.desktop" ];
            "application/x-unreal-blueprint" = [ "${h.editor}.desktop" ];

            # Special formats
            "application/x-ipynb+json" = [ "${h.editor}.desktop" ];
            "application/vnd.groove-tool-template" = [ "${h.editor}.desktop" ];
            "application/x-kicad-pcb" = [ "${h.editor}.desktop" ];
            "application/x-kicad-schematic" = [ "${h.editor}.desktop" ];

            # Nix-specific
            "text/x-nix" = [ "${h.editor}.desktop" ];
            "application/x-nix-package" = [ "${h.editor}.desktop" ];

            # Logs and debugging
            "text/x-log" = [ "${h.editor}.desktop" ];
            "application/x-coredump" = [ "${h.editor}.desktop" ];

            # Any other text-based format
            "text/x-generic" = [ "${h.editor}.desktop" ];
            # application/octet-stream is intentionally unset. It is a generic binary and opening it in an editor is rarely wanted.
            # x-scheme-handler/terminal and editor scheme handlers are intentionally unset too. Terminal URIs must not open in an editor.
          };
        };
      }
    ];
  };
}
