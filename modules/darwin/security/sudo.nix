{
  config,
  pkgs,
  ...
}: {
  # Enable Touch ID for sudo authentication
  # This allows using fingerprint instead of password for sudo commands
  security.pam.services.sudo_local.touchIdAuth = true;

  # Additional sudo configuration
  security.sudo = {
    # Keep environment variables when using sudo
    extraConfig = ''
      # Keep SSH_AUTH_SOCK for SSH agent forwarding
      Defaults env_keep += "SSH_AUTH_SOCK"

      # Keep TERMINFO for proper terminal handling
      Defaults env_keep += "TERMINFO TERMINFO_DIRS"

      # Keep locale settings
      Defaults env_keep += "LANG LANGUAGE LC_*"

      # Increase timestamp timeout to 15 minutes (default is 5)
      Defaults timestamp_timeout=15
    '';
  };
}
