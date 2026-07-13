# Build Home Manager `home.file` entries for agent skills.
#
# Upstream skills come from the pinned `skills-mattpocock` flake input.
# Local overrides live in `data/agents/skills/local/` and win on name clashes.
# Opt-outs are listed in `data/agents/skills/.upstream-ignore`.
{
  lib,
  inputs,
  dotfilesLib,
}:
let
  agentSkillsDir = dotfilesLib.agentSkillsDir;
  upstreamRoot = "${inputs.skills-mattpocock.outPath}/skills";
  localRoot = "${agentSkillsDir}/local";
  ignoreFile = "${agentSkillsDir}/.upstream-ignore";

  stripLine =
    line:
    lib.pipe line [
      (s: lib.elemAt (lib.splitString "#" s) 0)
      (s: builtins.replaceStrings [ " " "\t" "\r" ] [ "" "" "" ] s)
    ];

  readIgnoreFile =
    path:
    if builtins.pathExists path then
      lib.pipe (builtins.readFile path) [
        (lib.splitString "\n")
        (map stripLine)
        (lib.filter (line: line != ""))
      ]
    else
      [ ];

  ignored = lib.genAttrs (readIgnoreFile ignoreFile) (_: true);

  dirOnly = path: lib.filterAttrs (_name: type: type == "directory") (builtins.readDir path);

  skillDirsFromCategoryTree =
    root:
    lib.foldl' (
      acc: category:
      let
        categoryPath = "${root}/${category}";
      in
      acc
      // lib.mapAttrs' (skillName: _type: {
        name = skillName;
        value = "${categoryPath}/${skillName}";
      }) (dirOnly categoryPath)
    ) { } (lib.filter (c: c != "deprecated") (lib.attrNames (dirOnly root)));

  upstreamSkills = lib.filterAttrs (name: _path: !(ignored ? ${name})) (
    skillDirsFromCategoryTree upstreamRoot
  );

  localSkills = lib.mapAttrs' (skillName: _type: {
    name = skillName;
    value = "${localRoot}/${skillName}";
  }) (dirOnly localRoot);

  mergedSkills = upstreamSkills // localSkills;

  canonicalPrefix = ".agents/skills";

  homeFiles = lib.listToAttrs (
    map (
      skillName:
      let
        skillPath = mergedSkills.${skillName};
      in
      {
        name = "${canonicalPrefix}/${skillName}";
        value = {
          source = skillPath;
          recursive = true;
        };
      }
    ) (lib.attrNames mergedSkills)
  );
in
{
  inherit
    upstreamRoot
    localRoot
    ignored
    mergedSkills
    canonicalPrefix
    ;
  homeFiles = homeFiles;
}
