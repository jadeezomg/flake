# Build Home Manager `home.file` entries for agent skills.
#
# Upstream skills come from pinned Matt Pocock, Ponytail, and SimpleEnglish flake inputs.
# Local overrides live in `data/agents/skills/local/` and win on name clashes.
# Opt-outs are listed in `data/agents/skills/.upstream-ignore`.
{
  lib,
  inputs,
  dotfilesLib,
}:
let
  inherit (dotfilesLib) agentSkillsDir;
  mattpocockRoot = "${inputs.skills-mattpocock.outPath}/skills";
  ponytailRoot = "${inputs.skills-ponytail.outPath}/skills";
  simpleEnglishRoot = "${inputs.skills-simple-english.outPath}/skills";
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

  # One entry per pinned upstream input; names must stay unique across all of them.
  upstreamSources = [
    {
      source = "skills-mattpocock";
      skills = filterIgnored (skillDirsFromCategoryTree mattpocockRoot);
    }
    {
      source = "skills-ponytail";
      skills = filterIgnored (skillDirsFromFlatRoot ponytailRoot);
    }
    {
      source = "skills-simple-english";
      skills = filterIgnored (skillDirsFromFlatRoot simpleEnglishRoot);
    }
  ];

  upstreamCollisions = lib.pipe upstreamSources [
    (map (entry: lib.attrNames entry.skills))
    lib.concatLists
    (names: lib.filter (name: lib.count (n: n == name) names > 1) (lib.unique names))
  ];

  upstreamSkills =
    assert lib.assertMsg (upstreamCollisions == [ ])
      "Agent skill name collision between upstream skill inputs: ${lib.concatStringsSep ", " upstreamCollisions}";
    lib.foldl' (acc: entry: acc // entry.skills) { } upstreamSources;

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
    simpleEnglishRoot
    localRoot
    ignored
    upstreamCollisions
    mergedSkills
    canonicalPrefix
    ;
  inherit homeFiles;
}
