{
  lib,
  inputs,
}:
let
  skills = import ../lib/agent-skills.nix {
    inherit lib inputs;
    dotfilesLib.agentSkillsDir = ../data/agents/skills;
  };

  ponytailSkillNames = [
    "ponytail"
    "ponytail-audit"
    "ponytail-debt"
    "ponytail-gain"
    "ponytail-help"
    "ponytail-review"
  ];
in
assert skills.upstreamCollisions == [ ];
assert lib.all (name: skills.mergedSkills ? ${name}) ponytailSkillNames;
assert lib.all (
  name: lib.hasPrefix "${inputs.skills-ponytail.outPath}/skills/" skills.mergedSkills.${name}
) ponytailSkillNames;
true
