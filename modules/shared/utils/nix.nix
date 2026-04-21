{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cachix # Cachix for Nix
    nixos-icons # NixOS icons
    nh # Nix Helper
    comma # run software without installing it
    nix-index # index of nix packages
    nurl # nix url
    nix-init # initialize a new nix project
    nix-direnv # direnv for nix
  ];
}
