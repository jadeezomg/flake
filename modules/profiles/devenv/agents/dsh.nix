# dsh (DeepSeek Harness) web profile: adds the `openai-codex` provider route so
# dsh can use the ChatGPT/Codex subscription. The route comes from the bundled
# @deepseek-ai/dsh-llm-pi-ai plugin (pi-ai ships the Codex OAuth login). Sign in
# once in the dsh web settings; dsh stores the token at llm-pi-ai/openai-codex.
#
# dsh writes its own settings into cordis.patch.yml, so the file stays mutable.
# The `yq` merge only makes sure that the llm-pi-ai entry and its openai-codex
# route exist. It keeps all other entries and any fields set on the route.
#
# See: dsh-llm-pi-ai/README.md in the dsh package.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  patchPath = "${config.home.homeDirectory}/.dsh/profiles/web/cordis.patch.yml";

  esc = lib.escapeShellArg;
in
{
  home.activation.dshCodexProvider = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.yq-go
        pkgs.coreutils
      ]
    }:$PATH
    mkdir -p "$(dirname ${esc patchPath})"
    [ -s ${esc patchPath} ] || printf '[]\n' >${esc patchPath}
    if ! yq -e 'any_c(.id == "llm-pi-ai")' ${esc patchPath} >/dev/null 2>&1; then
      yq -i '. += [{"id": "llm-pi-ai", "name": "@deepseek-ai/dsh-llm-pi-ai"}]' ${esc patchPath}
    fi
    yq -i '(.[] | select(.id == "llm-pi-ai") | .config.providers["openai-codex"]) |= (. // {})' ${esc patchPath}
  '';
}
