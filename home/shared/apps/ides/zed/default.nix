{
  isDarwin,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}: let
  editorsEnabled = osConfig.dotfiles.profiles.apps.editors.enable or false;
  claude-agent-acp-fork = pkgs.buildNpmPackage {
    pname = "claude-agent-acp-fork";
    version = "latest";
    src = pkgs.fetchFromGitHub {
      owner = "rohan-patra";
      repo = "claude-agent-acp";
      rev = "master";
    };
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

  home.packages = lib.mkIf editorsEnabled [claude-agent-acp-fork];

  programs.zed-editor = lib.mkIf editorsEnabled {
    enable = true;
    package =
      if isDarwin && inputs ? nixpkgs-zed
      then inputs.nixpkgs-zed.legacyPackages.${pkgs.system}.zed-editor
      else pkgs.zed-editor;
  };
}
