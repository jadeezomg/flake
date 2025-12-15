{...}: {
  programs.zed-editor = {
    userSettings = {
      languages = {
        Python = {
          language_servers = [
            "ty"
            "!basedpyright"
          ];
        };

        Ruby = {
          language_servers = [
            "ruby-lsp"
            "rubocop"
            "!solargraph"
          ];
        };

        Lua = {
          tab_size = 2;
          formatter = "language_server";
          format_on_save = "on";
        };

        Nix = {
          language_servers = ["nil"];
          formatter.external = {
            command = "nixpkgs-fmt";
            arguments = [];
          };
          format_on_save = "on";
        };
      };

      context_servers = {
        gem = {
          enabled = true;
          settings = {};
        };
        "mcp-server-github" = {
          enabled = true;
          settings = {};
        };
      };

      lsp = {
        nil = {
          binary.path = "nil";
          binary.arguments = [];
        };

        rubocop = {
          initialization_options = {
            safeAutocorrect = false;
          };
        };

        ruby-lsp = {
          initialization_options = {
            enabledFeatures = {
              diagnostics = false;
            };
          };
        };
      };
    };
  };
}
