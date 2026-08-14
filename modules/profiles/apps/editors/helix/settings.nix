{ lib, ... }: {
  programs.helix.settings = {
    theme = lib.mkDefault "chiaroscuro";

    editor = {
      auto-completion = true;
      auto-format = true;
      auto-info = true;
      bufferline = "always";
      completion-trigger-len = 1;
      cursorcolumn = false;
      cursorline = true;
      default-yank-register = "+";
      idle-timeout = 250;
      indent-heuristic = "hybrid";
      insert-final-newline = true;
      middle-click-paste = true;
      mouse = true;
      path-completion = true;
      popup-border = "all";
      scroll-lines = 1;
      scrolloff = 8;
      true-color = true;
      undercurl = true;
      smart-tab = {
        enable = true;
      };
      cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "underline";
      };
      file-picker = {
        hidden = true;
        git-ignore = true;
      };
      indent-guides = {
        render = true;
        character = "│";
      };
      statusline = {
        separator = " │ ";
        mode = {
          normal = "NORMAL";
          insert = "INSERT";
          select = "SELECT";
        };
        left = [
          "mode"
          "spinner"
          "file-absolute-path"
          "read-only-indicator"
          "file-modification-indicator"
        ];
        center = [
          "version-control"
        ];
        right = [
          "diagnostics"
          "workspace-diagnostics"
          "spacer"
          "selections"
          "spacer"
          "position"
          "position-percentage"
          "total-line-numbers"
          "spacer"
          "file-encoding"
          "file-line-ending"
          "file-type"
        ];
      };
      gutters = [
        "diagnostics"
        "spacer"
        "line-numbers"
        "spacer"
        "diff"
      ];

      lsp = {
        enable = true;
        auto-signature-help = true;
        display-inlay-hints = true;
      };
    };
  };
}
