# Materialize a curated subset of sops secrets into 1Password (Darwin) at
# home-manager activation. Mirrors home/shared/shells/sops-keyring.nix on
# Linux — same source of truth (sops), different runtime store.
#
# Darwin-only. Linux uses libsecret via sops-keyring.nix.
#
# Each entry maps a 1Password item title (referenced in profile
# custom_credentials.*.credential_key as `op://<vault>/<item>/credential`)
# to the sops secret attribute that holds the value.
#
# Vault is hardcoded to "Personal" — change the `opVault` let-binding to
# point elsewhere. Item naming follows the snake_case convention shared
# with the Linux libsecret accounts so profile credential_key resolution
# is platform-symmetric.
#
# Best-effort: if `op` is not signed in (Touch ID locked, no recent auth),
# activation logs a warning and continues. Run `op signin` then re-run
# `home-manager switch` to populate.
{
  config,
  lib,
  pkgs,
  ...
}: let
  opVault = "Employee";

  # 1Password item title  →  sops secret attribute
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

  emit = item: sopsName: let
    path = resolvePath sopsName;
  in ''
    if [ -r ${esc path} ]; then
      _val="$(tr -d '[:space:]' <${esc path})"
      if [ -n "$_val" ]; then
        if op item get ${esc item} --vault ${esc opVault} >/dev/null 2>&1; then
          if _err="$(op item edit ${esc item} --vault ${esc opVault} \
              "credential=$_val" 2>&1 >/dev/null)"; then
            echo "sops-1password: updated ${item}"
          else
            echo "sops-1password: edit failed for ${item}: $_err" >&2
          fi
        else
          if _err="$(op item create --category "API Credential" \
              --vault ${esc opVault} --title ${esc item} \
              "credential=$_val" 2>&1 >/dev/null)"; then
            echo "sops-1password: created ${item}"
          else
            echo "sops-1password: create failed for ${item}: $_err" >&2
          fi
        fi
      fi
      unset _val _err
    fi
  '';

  presentMap = lib.filterAttrs (_: sopsName: lib.hasAttr sopsName secrets) agentKeyMap;
  script = lib.concatStrings (lib.mapAttrsToList emit presentMap);
in
  lib.mkIf (pkgs.stdenv.isDarwin && presentMap != {}) {
    home.activation.sops1Password = lib.hm.dag.entryAfter ["sops-nix"] ''
      # Prefer the Homebrew `op` (the binary path the 1Password desktop app's
      # CLI integration was authorized against). The nixpkgs `_1password-cli`
      # lives at a different store path and would need its own CLI-integration
      # approval, so it only serves as a fallback.
      export PATH=/opt/homebrew/bin:${lib.makeBinPath [pkgs.coreutils pkgs._1password-cli]}:$PATH
      if ! op whoami >/dev/null 2>&1; then
        echo "sops-1password: op not signed in, skipping. Open 1Password, unlock, enable Settings → Developer → 'Integrate with 1Password CLI', then re-run home-manager switch." >&2
      else
        echo "sops-1password: syncing ${toString (builtins.length (lib.attrNames presentMap))} item(s) to vault ${opVault}"
        ${script}
      fi
    '';
  }
