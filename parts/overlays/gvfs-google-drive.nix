# Re-enable Google Drive in gvfs (Nautilus). Required libsoup is marked insecure in nixpkgs.
# See: https://github.com/NixOS/nixpkgs/issues/438121
final: prev: {
  gnome = prev.gnome.overrideScope (gfinal: gprev: {
    gvfs = gprev.gvfs.override {
      googleSupport = true;
      gnomeSupport = true;
    };
  });
}
