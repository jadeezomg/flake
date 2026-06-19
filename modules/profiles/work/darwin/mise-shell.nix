# mise shell integration. Loaded only with the work profile on Darwin (via
# home-manager.sharedModules in ./default.nix), alongside the brew that installs
# mise — so it tracks mise's own scoping. mise lives outside the nix closure
# (Homebrew), so it's resolved at runtime/activation rather than from pkgs; the
# `command -v` guards also cover the window before the brew is first installed.
{
  config,
  lib,
  ...
}: let
  # nushell's config is a read-only store symlink and `source` resolves at parse
  # time, so we can't pipe `mise activate` inline like zsh/fish. Instead we
  # generate the activation snippet into a writable cache path on switch and
  # source that constant path (empty file when mise is absent → sources nothing).
  miseInit = "${config.xdg.cacheHome}/mise/init.nu";
in {
  # zsh + fish activate at interactive startup when mise is on PATH.
  programs.zsh.initContent = lib.mkAfter ''
    if command -v mise >/dev/null 2>&1; then
      eval "$(mise activate zsh)"
    fi
  '';

  programs.fish.interactiveShellInit = lib.mkAfter ''
    if command -q mise
      mise activate fish | source
    end
  '';

  programs.nushell.extraConfig = lib.mkAfter ''
    source ${miseInit}
  '';

  # Regenerate the nushell activation snippet on each switch so it tracks the
  # installed mise version. Homebrew isn't on the activation PATH, so fall back
  # to its known Apple-Silicon prefix.
  home.activation.miseNushellInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
    miseInit=${lib.escapeShellArg miseInit}
    mkdir -p "$(dirname "$miseInit")"
    mise_bin="$(command -v mise || true)"
    if [ -z "$mise_bin" ] && [ -x /opt/homebrew/bin/mise ]; then
      mise_bin=/opt/homebrew/bin/mise
    fi
    if [ -n "$mise_bin" ]; then
      "$mise_bin" activate nu > "$miseInit"
    else
      : > "$miseInit"
    fi
  '';
}
