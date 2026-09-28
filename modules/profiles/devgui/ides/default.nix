# IDEs feature folder — system packages (NixOS-wide install so root/gdm can
# resolve them) plus the rich HM configs in ./vscode and ./zed.
{ dotfilesLib, ... }@args:
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
    ];
} args
