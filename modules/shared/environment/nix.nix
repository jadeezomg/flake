{...}: {
  nix.settings = {
    download-buffer-size = 524288000; # 500 MiB
    # Nix experimental features
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
  };
}
