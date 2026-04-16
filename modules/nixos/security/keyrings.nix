{...}: {
  security.pam.services = {
    login.enableGnomeKeyring = true; # Enable GNOME keyring on tty login.
    # DMS greeter is the active authentication service when using greetd+dms.
    dms-greeter = {
      enableGnomeKeyring = true;
      startSession = true;
    };
  };
}
