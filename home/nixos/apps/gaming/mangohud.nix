# MangoHud (gaming overlay). Enable here so Stylix can apply its theme to it;
# the package can stay in NixOS environment.systemPackages for system-wide use.
{...}: {
  programs.mangohud.enable = true;
}
