{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.60.0.2-custom";

  # rohan-patra's fork of zed-industries/claude-agent-acp: adds full diff
  # preview support via a patched @anthropic-ai/claude-agent-sdk (pinned as a
  # git dependency in the upstream lockfile; that repo ships prebuilt dist).
  src = pkgs.fetchFromGitHub {
    owner = "rohan-patra";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-ABA8buketX7+ccVM11EuVc+7ZvxXBXEd985jnxei2Dc=";
  };

  npmDepsHash = "sha256-V2IqNKV5E1f3HVmSis/7E0Q42D77/+M6PDuzlVF209w=";

  # npm re-packs the git dependency at install time, which needs a writable
  # cache dir.
  makeCacheWritable = true;

  meta = with lib; {
    description = "ACP adapter exposing the Claude Agent SDK to ACP clients (Zed) with diff preview";
    homepage = "https://github.com/rohan-patra/claude-agent-acp";
    license = licenses.asl20;
    mainProgram = "claude-agent-acp";
  };
}
