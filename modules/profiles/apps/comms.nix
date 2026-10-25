{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "apps" ];
  # `proton`: CLI for Proton Mail, Drive, Calendar, Pass and Contacts. It has
  # no keyring backend; the session lives in a 0600 file under
  # ~/.config/proton-cli (macOS: ~/Library/Application Support/proton-cli).
  # Revoke it with `proton account logout --revoke`.
  packages = pkgs: [ pkgs.proton-cli ];
  # Linux-only; darwin comms (slack, …) come via the work profile's homebrew.
  linuxPackages = pkgs: [ pkgs.protonmail-desktop ];
} args
