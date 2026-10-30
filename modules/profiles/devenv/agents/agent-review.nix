# agent-review: an omp agent in a new herdr pane reviews the change of the
# agent in the current pane, asks it questions, and sends it the findings.
# ./agent-review.bash has the commands. The skills request-review (author) and
# peer-review (reviewer) in data/agents/skills/local/ hold the protocol.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-review";
      runtimeInputs = [
        pkgs.llm-agents.herdr
        pkgs.git
        pkgs.jq
        pkgs.coreutils
      ];
      text = builtins.readFile ./agent-review.bash;
    })
  ];
}
