{...}: {
  # ghostty.nix is imported unconditionally in P9e — it self-gates on the
  # apps.terminals profile and branches on isDarwin for package/systemd.
  imports = [
    ./ghostty.nix
    ./kitty.nix
  ];
}
