# Installs the flake's agent skills (data/agents/skills/<category>/<skill>)
# into each agent's skills dir (~/.claude/skills, ~/.agents/skills).
{
  dotfilesLib,
  lib,
  ...
}:
let
  agentSkillsDir = dotfilesLib.agentSkillsDir;
  agentSkillInstallPrefixes = [
    ".claude/skills"
    ".agents/skills"
  ];
  agentSkillCategories = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir agentSkillsDir)
  );
  agentSkillEntries = lib.concatLists (
    map (
      category:
      lib.optionals (category != "deprecated") (
        map
          (skillName: {
            name = skillName;
            path = "${agentSkillsDir}/${category}/${skillName}";
          })
          (
            lib.attrNames (
              lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${agentSkillsDir}/${category}")
            )
          )
      )
    ) agentSkillCategories
  );

  agentSkillFiles = lib.listToAttrs (
    lib.concatMap (
      skill:
      map (prefix: {
        name = "${prefix}/${skill.name}";
        value = {
          source = skill.path;
          recursive = true;
        };
      }) agentSkillInstallPrefixes
    ) agentSkillEntries
  );
in
{
  home.file = agentSkillFiles;
}
