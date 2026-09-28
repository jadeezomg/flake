{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.notes;
in
{
  # Scratchpad for throwaway notes — the counterpart to Obsidian's durable
  # vault. Not in nixpkgs; installed from Flathub rather than upstream's own
  # flake because the Nix derivation there omits the Pillow + pytesseract
  # runtime deps, which silently disables the image text-extraction feature.
  #
  # Removal: dropping this module leaves the flatpak installed (see the
  # `uninstallUnmanaged` note in ../../integrations.nix) — finish with
  # `flatpak uninstall --system io.github.tanaybhomia.Whisp`.
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.flatpak.enable;
        message = "apps.notes installs Whisp from Flathub; enable dotfiles.profiles.integrations (it turns on Flatpak).";
      }
    ];

    services.flatpak.packages = [ "io.github.tanaybhomia.Whisp" ];
  };
}
