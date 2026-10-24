# Notes feature folder. Apps with their own settings (Obsidian, Typora) live in
# sibling modules. Apps that only need an install live here.
{
  config,
  isDarwin ? false,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.notes;
in
{
  imports = [
    ./obsidian.nix
    ./typora
  ];

  # Typesetter is a GTK app and Whisp ships as a Flathub app, so both are
  # Linux-only. optionalAttrs (not mkIf) because services.flatpak is not
  # declared on darwin.
  config = lib.mkIf cfg.enable (
    lib.optionalAttrs (!isDarwin) {
      # Local-first Typst editor, for notes that need typeset output.
      environment.systemPackages = [ pkgs.typesetter ];

      # Whisp: scratchpad for throwaway notes — the counterpart to Obsidian's
      # durable vault. Not in nixpkgs; installed from Flathub rather than
      # upstream's own flake because the Nix derivation there omits the Pillow +
      # pytesseract runtime deps, which silently disables the image
      # text-extraction feature.
      #
      # Removal: dropping Whisp leaves the flatpak installed (see the
      # `uninstallUnmanaged` note in ../../integrations.nix) — finish with
      # `flatpak uninstall --system io.github.tanaybhomia.Whisp`.
      assertions = [
        {
          assertion = config.services.flatpak.enable;
          message = "apps.notes installs Whisp from Flathub; enable dotfiles.profiles.integrations (it turns on Flatpak).";
        }
      ];

      services.flatpak.packages = [ "io.github.tanaybhomia.Whisp" ];
    }
  );
}
