{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./nix.nix
  ];

  # Generate a list of installed system packages for easy inspection
  environment.etc."current-system-packages".text = let
    packages = builtins.map (p: "${p.name}") config.environment.systemPackages;
    sortedUnique = builtins.sort builtins.lessThan (pkgs.lib.lists.unique packages);
    formatted = builtins.concatStringsSep "\n" sortedUnique;
  in
    formatted;
}
