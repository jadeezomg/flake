{ pkgs, ... }: {
  force = true;
  default = "Kagi";
  privateDefault = "Kagi";
  engines =
    let
      nixSnowflakeIcon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    in
    {
      # https://help.kagi.com/kagi/getting-started/setting-default.html — extension handles default + private
      # login; we still declare the engine + suggestions here. Optional manual “private session” URL:
      # template https://kagi.com/search with params token + q (token from Kagi account).
      # For suggestions in private windows, enable the checkbox under Search Suggestions in about:preferences#search.
      "Kagi" = {
        urls = [
          {
            template = "https://kagi.com/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
          {
            type = "application/x-suggestions+json";
            template = "https://kagisuggest.com/api/autosuggest";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "kagi"
          "kg"
        ];
      };
      "Nix Packages" = {
        urls = [
          {
            template = "https://search.nixos.org/packages";
            params = [
              {
                name = "type";
                value = "packages";
              }
              {
                name = "channel";
                value = "unstable";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = nixSnowflakeIcon;
        definedAliases = [
          "pkgs"
          "nix"
        ];
      };
      "Nix Options" = {
        urls = [
          {
            template = "https://search.nixos.org/options";
            params = [
              {
                name = "channel";
                value = "unstable";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = nixSnowflakeIcon;
        definedAliases = [ "nop" ];
      };
      "Home Manager Options" = {
        urls = [
          {
            template = "https://home-manager-options.extranix.com/";
            params = [
              {
                name = "query";
                value = "{searchTerms}";
              }
              {
                name = "release";
                value = "master";
              }
            ];
          }
        ];
        icon = nixSnowflakeIcon;
        definedAliases = [
          "hmop"
          "hm"
        ];
      };

      "Nixpkgs PRs" = {
        urls = [
          {
            template = "https://github.com/NixOS/nixpkgs/pulls";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = nixSnowflakeIcon;
        definedAliases = [
          "nixpr"
          "pr"
        ];
      };

      "Nixpkgs PR Tracker" = {
        urls = [
          {
            template = "https://nixpk.gs/pr-tracker.html";
            params = [
              {
                name = "pr";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = nixSnowflakeIcon;
        definedAliases = [
          "prt"
          "track"
        ];
      };

      # https://hydra.nixos.org/jobset/nixpkgs/unstable#tabs-jobs
      "Nixpkgs Hydra Jobs" = {
        urls = [
          {
            template = "https://hydra.nixos.org/jobset/nixpkgs/unstable/jobs-tab";
            params = [
              {
                name = "filter";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = nixSnowflakeIcon;
        definedAliases = [
          "hydra"
          "hy"
        ];
      };

      "Google Maps" = {
        urls = [
          {
            template = "http://maps.google.com";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "maps"
          "gmaps"
          "map"
        ];
      };

      "google" = {
        urls = [
          {
            template = "https://www.google.com/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "g"
          "google"
        ];
      };

      "Google Images" = {
        urls = [
          {
            template = "https://www.google.com/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
              {
                name = "tbm";
                value = "isch";
              }
            ];
          }
        ];
        definedAliases = [
          "gi"
          "images"
        ];
      };

      "Duck Duck Go" = {
        urls = [
          {
            template = "https://duckduckgo.com";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "ddg"
          "d"
        ];
      };

      "reddit" = {
        urls = [
          {
            template = "https://kagi.com/search";
            params = [
              {
                name = "q";
                value = "site:reddit.com {searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "r"
          "reddit"
        ];
      };

      "youtube" = {
        urls = [
          {
            template = "https://www.youtube.com/results";
            params = [
              {
                name = "search_query";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "y"
          "yt"
        ];
      };
    };
}
