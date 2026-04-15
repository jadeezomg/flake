{
  pkgs,
  user,
  ...
}: {
  # Add user to greeter group for DMS config access
  users.users.${user}.extraGroups = ["greeter"];

  # ACL: grant greeter group read access to user's home for DMS config sync.
  # Equivalent of `dms greeter sync` which is unavailable on NixOS.
  systemd.services.dms-greeter-acl = {
    description = "Set ACL permissions for DMS greeter config sync";
    before = ["greetd.service"];
    wantedBy = ["graphical.target"];
    serviceConfig.Type = "oneshot";
    path = [pkgs.acl];
    script = ''
      setfacl -m g:greeter:rx /home/${user}
      setfacl -m g:greeter:rx /home/${user}/.config
      setfacl -R -m g:greeter:rX /home/${user}/.config/DankMaterialShell
    '';
  };
}
