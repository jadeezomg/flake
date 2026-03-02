{config, ...}: {
  # Flatpak support
  services.flatpak.enable = true;

  # Add Flathub remote and install Cine
  system.activationScripts.flatpakSetup = ''
    export PATH="${config.system.path}/bin:''${PATH}"
    # Add Flathub remote if it doesn't exist
    if ! flatpak remote-list | grep -q "flathub"; then
      echo "Adding Flathub remote..."
      flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    fi

    # Install Cine from Flathub if not already installed
    if ! flatpak list --system --app --columns=application 2>/dev/null | grep -q "io.github.diegopvlk.Cine"; then
      echo "Installing Cine from Flathub..."
      flatpak install --system --noninteractive --assumeyes flathub io.github.diegopvlk.Cine || true
    fi
  '';
}
