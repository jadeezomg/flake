{
  users = {
    jadee = {
      username = "jadee";
      fullName = "Jadee";
      email = "me@jadee.fyi";
      description = "jadee";
      extraGroups = [
        "gamemode"
        "input"
        "networkmanager"
        "podman"
        "uinput"
        "video"
        "wheel"
      ];
      packages = [];
    };

    caya-jonas = {
      username = "caya-jonas";
      fullName = "Caya Jonas";
      email = "jonas.hippauf@getcaya.com";
      description = "Caya Jonas Darwin User";
      homeDirectory = "/Users/caya-jonas";
      stateVersion = "25.11";
      extraGroups = [];
      packages = [];
    };

    # NixOS guest: no wheel/sudo; video/audio/network for desktop login (GDM + Niri/GNOME)
    angelie = {
      username = "angelie";
      fullName = "Angelie";
      description = "Guest account (limited)";
      extraGroups = [
        "audio"
        "networkmanager"
        "video"
      ];
      packages = [];
    };
  };
}
