{ config, lib, ... }:

{
  programs.nushell = {
    settings = {
      # General settings
      show_banner = false;

      # History settings
      history = {
        max_size = 100000;
        sync_on_enter = true;
        file_format = "sqlite";
        isolation = false;
      };

      # Completions
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
  };
}

