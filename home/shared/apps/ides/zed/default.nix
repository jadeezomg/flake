{pkgs, ...}: let
  claude-agent-acp-fork = pkgs.buildNpmPackage {
    pname = "claude-agent-acp-fork";
    version = "0.25.1";
    src = pkgs.fetchFromGitHub {
      owner = "rohan-patra";
      repo = "claude-agent-acp";
      rev = "07dc92cb5afa479848dd7d003e3be3effd9f2057";
      hash = "sha256-yBY0Sektb7vtz0FuVhRr1dqPW8lw5ubpkR4d+LO2kLo=";
    };
    npmDepsHash = "sha256-KDYRPlPgi9K9HjOIopkUcGnauq034otdIHm0gQ2PjsU=";
    buildPhase = "npm run build";
  };
in {
  imports = [
    ./extensions.nix
    ./keybinds.nix
    ./languages.nix
    ./settings.nix
    ./theme.nix
  ];

  _module.args.claude-agent-acp-fork = claude-agent-acp-fork;

  home.packages = [claude-agent-acp-fork];

  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
  };
}
