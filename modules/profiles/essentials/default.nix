{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "essentials" ];
  # HM widgets: host-status service/timer, fastfetch config, CLI utils
  # (television cable, navi cheats, yazi), prompt/shell theming, and the
  # workstation env exports (FLAKE, PATH, flake helpers).
  hm = [
    ./host-status.nix
    ./fastfetch.nix
    ./utils
    ./shell-theme
    ./shell-system-env.nix
  ];

  packages =
    pkgs: with pkgs; [
      # --- Text / docs polish ---
      ripgrep-all # ripgrep for archives, pdfs, etc.
      exiftool
      qpdf
      pdftk

      # --- Networking polish ---
      ipfetch
      resterm

      # --- Security / crypto ---
      openssl

      # --- Nix workstation tooling ---
      cachix
      comma
      nurl
    ];
} args
