{
  # Sandbox-safe env. Always loaded. Anything that should appear inside an
  # agent-sandbox.nix mkSandbox extraEnv block belongs here too — keep this
  # list small and free of paths that point at this repo.
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
    ZED_ALLOW_ROOT = "true";
  };
}
