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
        pkgs.herdr-core
        pkgs.git
        pkgs.jq
        pkgs.coreutils
      ];
      text = builtins.readFile ./agent-review.bash;
    })
  ];

  # herdr-core template for `hc run reviewer "<task>"`. herdr-core starts the
  # command, waits until omp is ready, then sends this body and the task as the
  # first message. agent-review uses it in Herdr.app, and `hc templates` shows
  # it to other agents as a reviewer role.
  xdg.configFile."herdr-core/templates/reviewer.md".text = ''
    ---
    name: reviewer
    description: An omp agent that reviews a change and changes no files. agent-review starts it for review-<id> sessions.
    command: omp --skills=peer-review,ponytail-review,terminal-browser
    ---
    You are a code reviewer. Change no files.
    If the task names an agent-review session (review-<id>), follow the peer-review skill.
    Else review what the task names with the ponytail-review skill, and report as the task says.
  '';
}
