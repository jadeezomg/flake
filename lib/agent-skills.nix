# Build Home Manager `home.file` entries for agent skills.
#
# Upstream skills come from pinned Matt Pocock and Ponytail flake inputs.
# Local overrides live in `data/agents/skills/local/` and win on name clashes.
# Opt-outs are listed in `data/agents/skills/.upstream-ignore`.
{
  lib,
  inputs,
  dotfilesLib,
}:
let
  agentSkillsDir = dotfilesLib.agentSkillsDir;
  mattpocockRoot = "${inputs.skills-mattpocock.outPath}/skills";
  ponytailRoot = "${inputs.skills-ponytail.outPath}/skills";
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

  skillDirsFromFlatRoot =
    root: lib.mapAttrs (skillName: _type: "${root}/${skillName}") (dirOnly root);

  filterIgnored = lib.filterAttrs (name: _path: !(ignored ? ${name}));

  mattpocockSkills = filterIgnored (skillDirsFromCategoryTree mattpocockRoot);
  ponytailSkills = filterIgnored (skillDirsFromFlatRoot ponytailRoot);

  upstreamCollisions = lib.intersectLists (lib.attrNames mattpocockSkills) (
    lib.attrNames ponytailSkills
  );

  upstreamSkills =
    assert lib.assertMsg (upstreamCollisions == [ ])
      "Agent skill name collision between Matt Pocock and Ponytail inputs: ${lib.concatStringsSep ", " upstreamCollisions}";
    mattpocockSkills // ponytailSkills;

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
    mattpocockRoot
    ponytailRoot
    localRoot
    ignored
    upstreamCollisions
    mergedSkills
    canonicalPrefix
    ;
  homeFiles = homeFiles;
}
