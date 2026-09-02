# server: the headless-host profile. `server.enable` is a steering flag, not
# a package set. modules/nixos/{boot,networking}.nix read it inline.
#
# A `hostClass = "server"` host gets the GUI-facing default-on profiles turned
# off here, so hosts/<name>/profiles.nix does not repeat the same four lines.
# The assertions in ./default.nix use the same hostClass test, so a host that
# flips one of these back on fails eval with a clear message.
{
  host ? { },
  lib,
  ...
}:
let
  isServer = (host.hostClass or "workstation") == "server";
in
{
  config = lib.mkIf isServer {
    dotfiles.profiles = {
      desktop.enable = lib.mkDefault false;
      integrations.enable = lib.mkDefault false;
      fonts.full.enable = lib.mkDefault false;
      theme.gui.enable = lib.mkDefault false;
    };
  };
}
