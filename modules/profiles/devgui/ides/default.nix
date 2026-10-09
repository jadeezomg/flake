# IDEs feature folder — system packages (NixOS-wide install so root/gdm can
# resolve them) plus the rich HM configs in ./vscode and ./zed.
{ dotfilesLib, inputs, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  hm = [
    ./vscode
    ./zed
  ];
  linuxPackages =
    pkgs: with pkgs; [
      vscode
      zed-editor
      inputs.delta.packages.${pkgs.stdenv.hostPlatform.system}.delta
    ];
} args
