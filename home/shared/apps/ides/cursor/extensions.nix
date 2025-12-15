{ pkgs, ... }:

{
  programs.vscode.profiles.default.extensions =
    with pkgs.vscode-extensions;
    [
      dbaeumer.vscode-eslint # JavaScript/TypeScript linting
      charliermarsh.ruff # Python linting/formatting
      tamasfe.even-better-toml # TOML support
      jnoortheen.nix-ide # Nix language support
      redhat.vscode-yaml # YAML support
      thenuprojectcontributors.vscode-nushell-lang # Nushell support
      rebornix.ruby # Ruby support
      aaron-bond.better-comments # Better comments highlighting
      kamadorueda.alejandra # Nix formatter
    ]
    ++ (if false then [ ] else [ ])
    ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "birds-of-paradise"; # Cozy brown Theme
        publisher = "Programming-Engineer";
        version = "0.1.2";
        sha256 = "05b8ahbwkjgmw2cq46dddd64lwg5mhffzff4b1knbl4yrw9jlbp2";
      }
      {
        name = "schemastore"; # JSON Schema support
        publisher = "remcohaszing";
        version = "1.0.264";
        sha256 = "0n0yxvi6abqlh0x498z3xzinf2qs01crgv62hgg7xk3akskav1ri";
      }
      # Extensions from VSCode marketplace - uncomment and fill in correct versions/hashes:
      /*
        {
          name = "ty";
          publisher = "astral-sh";
          version = "0.0.0"; # TODO: Get correct version from marketplace
          sha256 = "sha256-0000000000000000000000000000000000000000000000000000"; # TODO: Get correct hash
        }

        {
          name = "better-comments-next";
          publisher = "EdwinHuiSH";
          version = "0.0.0"; # TODO: Get correct version from marketplace
          sha256 = "sha256-0000000000000000000000000000000000000000000000000000"; # TODO: Get correct hash
        }
      */
    ];
}
