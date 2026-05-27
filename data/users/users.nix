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
      # Authorized SSH public keys for this user across all hosts.
      # Wired into `users.users.${user}.openssh.authorizedKeys.keys` by
      # `modules/nixos/user.nix`. Populate with keys from each host that should
      # be able to SSH-in without password.
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+aciat7EcEICxtjz/xNiJ1sLsOT9w2GxKUPSL3bG1t"
      ];
      packages = [];
    };

    caya-jonas = {
      username = "caya-jonas";
      fullName = "Caya Jonas";
      email = "jonas.hippauf@getcaya.com";
      description = "Caya Jonas Darwin User";
      homeDirectory = "/Users/caya-jonas";
      stateVersion = "26.05";
      extraGroups = [];
      packages = [];
    };

    # NixOS guest: no wheel/sudo; video/audio/network for desktop login (GDM + Niri/GNOME)
    angelie = {
      username = "angelie";
      fullName = "Angelie";
      description = "Guest account (limited)";
      initialPassword = "gremlin";
      promptPasswordChange = true;
      extraGroups = [
        "audio"
        "networkmanager"
        "video"
      ];
      packages = [];
    };
  };
}
