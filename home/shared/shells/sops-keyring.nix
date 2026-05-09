# Materialize a curated subset of sops secrets into libsecret (gnome-keyring)
# at home-manager activation. Used by the nono sandbox broker to inject
# credentials on outbound HTTPS — see lib/nono-profiles.nix and
# docs/adr/0001-nono-as-single-sandboxing-system.md.
#
# Linux-only. macOS uses the Keychain via apple-password:// URIs in nono
# profiles directly; no equivalent activation is needed.
#
# Each entry maps a nono keystore account name (referenced in profile
# custom_credentials.*.credential_key) to the sops secret attribute that
# holds the value.
#
# Activation runs after sops-nix so the decrypted secret files exist on disk
# at the path declared by sops.secrets.<name>.path. Idempotent — re-running
# overwrites the existing keystore entry. The user's gnome-keyring-daemon
# must be running and unlocked for storage to succeed; activation is best-
# effort and won't fail the switch if the daemon is absent.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # account name in libsecret  →  sops secret attribute
  agentKeyMap = {
    "openrouter_api_key" = "openrouter-api-key";
    "context7_api_key" = "context7-api-key";
    # Agents use the dedicated `agent-pat`, NOT the user's `github-token`.
    "github_token" = "agent-pat";
  };

  secrets = config.sops.secrets or {};

  resolvePath = name: let
    raw = secrets.${name}.path;
  in
    if lib.hasPrefix "/" raw
    then raw
    else "${config.home.homeDirectory}/${raw}";

  esc = lib.escapeShellArg;

  emit = account: sopsName: let
    path = resolvePath sopsName;
  in ''
    if [ -r ${esc path} ]; then
      _val="$(tr -d '[:space:]' <${esc path})"
      if [ -n "$_val" ]; then
        printf '%s' "$_val" | secret-tool store \
          --label=${esc "nono: ${account}"} \
          service nono account ${esc account} \
          2>/dev/null || true
      fi
      unset _val
    fi
  '';

  presentMap = lib.filterAttrs (_: sopsName: lib.hasAttr sopsName secrets) agentKeyMap;
  script = lib.concatStrings (lib.mapAttrsToList emit presentMap);
in
  lib.mkIf (pkgs.stdenv.isLinux && presentMap != {}) {
    home.activation.sopsKeyring = lib.hm.dag.entryAfter ["sops-nix"] ''
      export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.libsecret]}:$PATH
      ${script}
    '';
  }
