# fnox — per-project secrets from 1Password, put into the environment by a
# prompt hook, in the same way as direnv and mise. A repo declares its secrets
# in `fnox.toml`, and the hook exports them when you enter that directory.
#
# fnox comes from nixpkgs, not from the per-repo mise pin. `fnox activate`
# prints shell code with an absolute path to the binary baked in, and a
# mise-managed fnox cannot supply that code:
#
#   - The hook must be installed while the shell rc runs. mise puts fnox on
#     PATH only after the rc ran, on the first directory change into the repo.
#   - The mise install path carries the version, so a baked path breaks on
#     every fnox release.
#
# The `fnox` shell function that the hook defines shadows PATH, so this fnox
# also runs inside a repo whose mise.toml pins a newer one.
{ pkgs, ... }:
let
  fnox = "${pkgs.fnox}/bin/fnox";

  # nushell has no `eval`, so its activation code is generated at build time
  # and sourced. `activate` only prints code. It reaches no secret provider.
  nushellInit = pkgs.runCommand "fnox-nushell-config.nu" { } ''
    ${fnox} activate nu > $out
  '';
in
{
  home.packages = [ pkgs.fnox ];

  programs = {
    zsh.initContent = ''
      eval "$(${fnox} activate zsh)"
    '';

    bash.initExtra = ''
      eval "$(${fnox} activate bash)"
    '';

    fish.interactiveShellInit = ''
      ${fnox} activate fish | source
    '';

    nushell.extraConfig = ''
      source ${nushellInit}
    '';
  };
}
