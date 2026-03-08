{config, ...}: {
  # Flatpak support
  services.flatpak.enable = true;

  # Add Flathub remote at activation
  system.activationScripts.flatpakSetup = ''
    export PATH="${config.system.path}/bin:''${PATH}"
    if ! flatpak remote-list 2>/dev/null | grep -q "flathub"; then
      echo "Adding Flathub remote..."
      flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    fi
  '';

  # Install Cine (and other Flatpak apps) via a oneshot after network is up;
  # activation script runs too early and may not have network.
  systemd.services.flatpakInstallCine = {
    description = "Install Cine Flatpak from Flathub";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      export PATH="${config.system.path}/bin:$PATH"
      if ! flatpak list --system --app --columns=application 2>/dev/null | grep -q "io.github.diegopvlk.Cine"; then
        echo "Installing Cine from Flathub..."
        flatpak install --system --noninteractive --assumeyes flathub io.github.diegopvlk.Cine
      fi
    '';
  };
}
