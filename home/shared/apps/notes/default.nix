{
  lib,
  osConfig,
  pkgs,
  ...
}: {
  programs.obsidian = lib.mkIf (osConfig.dotfiles.profiles.apps.notes.enable or false) {
    enable = true;
    package = pkgs.obsidian;

    defaultSettings = {
      app = {
        alwaysUpdateLinks = true;
        newLinkFormat = "relative";
        useMarkdownLinks = true;
        attachmentFolderPath = "assets";
        defaultViewMode = "source";
        livePreview = true;
        promptDelete = true;
        trashOption = "local";
        showLineNumber = true;
        readableLineLength = true;
        spellcheck = true;
        spellcheckLanguages = ["en-US" "de-DE"];
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
        "daily-notes"
        "templates"
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
