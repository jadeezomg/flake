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

        # --- Biome (per-language; avoid global so unsupported languages aren't affected) ---
        Astro = {
          formatter = {language_server = {name = "biome";};};
        };
        CSS = {
          formatter = {language_server = {name = "biome";};};
        };
        GraphQL = {
          formatter = {language_server = {name = "biome";};};
        };
        HTML = {
          formatter = {language_server = {name = "biome";};};
        };
        JSON = {
          formatter = {language_server = {name = "biome";};};
        };
        JSONC = {
          formatter = {language_server = {name = "biome";};};
        };
        JSX = {
          formatter = {language_server = {name = "biome";};};
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
        JavaScript = {
          formatter = {language_server = {name = "biome";};};
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
        Svelte = {
          formatter = {language_server = {name = "biome";};};
        };
        TSX = {
          formatter = {language_server = {name = "biome";};};
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
        TypeScript = {
          formatter = {language_server = {name = "biome";};};
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
        "Vue.js" = {
          formatter = {language_server = {name = "biome";};};
        };
      };

      context_servers = {
        gem = {
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

        # Only enable Biome when project has biome.json (avoids affecting non-Biome projects)
        biome = {
          settings = {
            require_config_file = true;
          };
        };
      };
    };
  };
}
