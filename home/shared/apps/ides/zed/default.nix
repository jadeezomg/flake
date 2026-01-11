{inputs, ...}: let
  # Use zed-editor from the official zed flake which has binary caches
  # This avoids building from source - see https://github.com/zed-industries/zed/blob/main/flake.nix
  zedPkg = inputs.zed.packages.${inputs.zed.packages.x86_64-linux.default.system or "x86_64-linux"}.default;
in {
  imports = [
    ./extensions.nix
    ./keybinds.nix
    ./languages.nix
    ./settings.nix
    ./theme.nix
  ];

  programs.zed-editor = {
    enable = true;
    package = zedPkg;
  };
}
