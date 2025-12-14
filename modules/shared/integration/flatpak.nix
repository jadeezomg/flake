{ ... }:

{
  # Flatpak support
  services.flatpak = {
    enable = true;
    remotes = {
      flathub = {
        url = "https://flathub.org/repo/flathub.flatpakrepo";
      };
    };
  };
}
