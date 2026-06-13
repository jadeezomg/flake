{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.notes;
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      {
        programs.obsidian = {
          enable = true;
          package = pkgs.obsidian;

          defaultSettings = {
            app = {
              alwaysUpdateLinks = true;
              newLinkFormat = "relative";
              useMarkdownLinks = true;
              attachmentFolderPath = "assets";
              newFileLocation = "folder";
              newFileFolderPath = "inbox";
              defaultViewMode = "source";
              livePreview = true;
              promptDelete = true;
              trashOption = "local";
              showLineNumber = true;
              readableLineLength = true;
              spellcheck = true;
              spellcheckLanguages = [
                "en-US"
                "de-DE"
              ];
            };

            corePlugins = [
              "file-explorer"
              "global-search"
              "switcher"
              "graph"
              "backlink"
              "canvas"
              "outgoing-link"
              "tag-pane"
              "properties"
              "page-preview"
              {
                name = "daily-notes";
                settings = {
                  folder = "journal";
                  format = "YYYY-MM-DD";
                  template = "templates/daily.md";
                  autorun = false;
                };
              }
              {
                name = "templates";
                settings.folder = "templates";
              }
              "note-composer"
              "command-palette"
              "editor-status"
              "bookmarks"
              "outline"
              "word-count"
              "file-recovery"
              "sync"
              "bases"
            ];
          };

          vaults.vault = {
            enable = true;
            target = "Git/vault";
          };
        };
      }
    ];
  };
}
