{
  # Sandbox-safe env. Always loaded. Anything that should appear inside an
  # agent's nono sandbox env belongs here too — keep this list small and
  # free of paths that point at this repo.
  base = {
    EDITOR = "hx";
    VISUAL = "hx";
    PAGER = "bat";
    LC_ALL = "en_US.UTF-8";
    LANG = "en_US.UTF-8";
  };

  # System overlay. Gated on dotfiles.profiles.essentials.enable. Hosts get
  # this; sandboxes never do. Anything referencing the flake path, secrets
  # editor, or workstation-only tools lives here.
  system = {
    EDITOR = "zeditor";
    VISUAL = "zeditor";
    SOPS_EDITOR = "hx";
    BROWSER = "zen";
    PI_ACP_ENABLE_EMBEDDED_CONTEXT = "true";
    PROTON_PASS_LINUX_KEYRING = "dbus";
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    ZED_ALLOW_ROOT = "true";
  };
}
