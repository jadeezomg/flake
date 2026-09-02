# Atuin shell history. Every host syncs to mini's own server
# (hosts/mini/services/atuin.nix), never to the public api.atuin.sh.
#
# The address resolves over the tailnet, and on the LAN when local DNS points at
# mini. Off both networks, sync fails quietly and history stays local until the
# next connection.
#
# Sync needs a one-time `atuin login` per host — see the onboarding steps in
# hosts/mini/services/atuin.nix.
{
  config,
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.atuin;
  expiry = dotfilesLib.expiry { inherit lib; } "modules/profiles/minimal/shells/core/atuin.nix";

  # `atuin init nu` (up to 18.20.0) names both its keybindings `atuin`. Nushell
  # 0.115 merges keybindings by name, so it drops the Ctrl-R binding and warns
  # "Multiple keybindings share a name" on every shell start. Upstream renamed
  # the up-arrow binding to `atuin_up_arrow` in 18.20.1
  # (https://github.com/atuinsh/atuin/pull/3975). Until nixpkgs ships that, we
  # generate the nushell snippet ourselves and apply the same rename.
  renameUpArrowBinding = expiry.expireWhen {
    fixed = lib.versionAtLeast cfg.package.version "18.20.1";
    reason = "nixpkgs now ships atuin >= 18.20.1, which names the nushell keybindings uniquely; re-enable programs.atuin.enableNushellIntegration and drop the custom snippet.";
    fallback = false;
  } true;

  # Same as the Home Manager snippet, with the second `name: atuin` renamed.
  nushellConfig =
    pkgs.runCommand "atuin-nushell-config.nu" { nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ]; }
      ''
        ${lib.getExe cfg.package} init nu ${lib.escapeShellArgs cfg.flags} \
          | awk '/^ *name: atuin$/ { n++; if (n == 2) sub(/atuin$/, "atuin_up_arrow") } { print }' \
          > "$out"
        grep -q "name: atuin_up_arrow" "$out"
      '';
in
{
  programs.atuin = {
    enable = true;
    enableNushellIntegration = !renameUpArrowBinding;
    settings = {
      sync_address = "https://atuin.jadee.fyi";
      auto_sync = true;
      sync_frequency = "5m";
    };
  };

  # Same order as Home Manager: load after fzf so Atuin keeps Ctrl-R.
  programs.nushell.extraConfig = lib.mkIf renameUpArrowBinding (
    lib.mkOrder 2000 ''
      source ${nushellConfig}
    ''
  );
}
