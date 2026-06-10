{
  config,
  pkgs,
  host ? {},
  lib,
  ...
}: let
  buildCores = host.buildCores or 6;
  isDarwin = lib.hasSuffix "-darwin" (host.system or "");
  nixExperimentalFeatures = import ../../lib/nix-experimental-features.nix {
    inherit lib;
    inherit isDarwin;
  };
in {
  # Cross-platform nix.settings + cargo env vars + `/etc/current-system-packages`.
  # Automatic GC lives in `modules/nixos/gc.nix`
  # since Darwin (Determinate Nix) manages its own GC and uses a different
  # option shape (`nix.gc.interval`).

  nix.settings = {
    auto-optimise-store = true;
    download-buffer-size = 524288000; # 500 MiB
    max-jobs = 1;
    cores = buildCores;

    # if build failes because of public keys
    # cd /home/jadee/.dotfiles/flake && sudo NIX_CONFIG='substituters = https://cache.nixos.org/ trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' nix build '.#nixosConfigurations.desktop.config.system.build.toplevel'
    # sudo nixos-rebuild switch --flake /home/jadee/.dotfiles/flake#desktop

    extra-substituters = [
      "https://zed.cachix.org"
      "https://hyprland.cachix.org"
      "https://nix-community.cachix.org"
      "https://yazi.cachix.org"
      "https://niri.cachix.org"
      # CachyOS kernel (nix-cachyos-kernel)
      "https://attic.xuyh0120.win/lantian"
      # mini host nightly cache-warming output
      # "https://jadee-flake.cachix.org"
    ];
    extra-trusted-public-keys = [
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      # TODO: replace with the real public key after running `cachix create jadee-flake`
      # "jadee-flake.cachix.org-1:REPLACE_ME="
    ];
    # CA / dynamic derivations (Linux only — mini vllm-xpu, etc.). Not enabled on
    # Darwin (Determinate / unused). NixOS applies these after `switch`; the
    # *evaluating* client also needs them — see `lib/nix-experimental-features.nix`
    # and Home Manager `nix.settings` on Linux.
    experimental-features = nixExperimentalFeatures;

    trusted-users = [
      "jadee"
    ];
  };

  environment.variables = {
    CARGO_BUILD_JOBS = toString (buildCores / 2);
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
  };

  # Generate a list of installed system packages for easy inspection
  # (cat /etc/current-system-packages).
  environment.etc."current-system-packages".text = let
    packages = builtins.map (p: "${p.name}") config.environment.systemPackages;
    sortedUnique = builtins.sort builtins.lessThan (pkgs.lib.lists.unique packages);
  in
    builtins.concatStringsSep "\n" sortedUnique;
}
