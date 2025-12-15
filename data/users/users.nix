{
  users = {
    jadee = {
      username = "jadee";
      fullName = "Jadee";
      email = "me@jadee.fyi";
      description = "jadee";
      extraGroups = [
        "input"
        "networkmanager"
        "uinput"
        "video"
        "wheel"
      ];
      packages = [];
    };

    # Dedicated macOS user (override for Darwin hosts like caya)
    caya = {
      username = "jadee";
      homeDirectory = "/Users/jadee";
      stateVersion = "25.11";
      user = {};
    };
  };
}
