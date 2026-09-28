{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "apps" ];
  # HM halves — plain Home Manager modules, pushed to every user when the
  # profile is on (./ghostty.nix branches on isDarwin internally).
  hm = [
    ./ghostty.nix
    ./kitty.nix
  ];

  # Linux-only (ghostty is broken on darwin in nixpkgs; terminal apps on
  # macOS come from homebrew / HM configs instead).
  linuxPackages =
    pkgs: with pkgs; [
      ghostty
      kitty
    ];
} args
