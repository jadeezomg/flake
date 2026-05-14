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
        # TODO: paste actual public keys before first nixos-install on mini
        # "ssh-ed25519 AAAA... jadee@desktop"
        # "ssh-ed25519 AAAA... jadee@framework"
        # "ssh-ed25519 AAAA... jadee@caya"
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
