{
  config,
  dotfilesLib,
  lib,
  ...
}:
let
  me = lib.findFirst (u: u.username == config.home.username) null (lib.attrValues dotfilesLib.users);
  authorEmail = if me == null then null else (me.gitEmail or me.email or null);
  authorName = if me == null then null else (me.fullName or null);
in
{
  programs.git = {
    enable = true;
    settings.user = {
      name = lib.mkIf (authorName != null) authorName;
      email = lib.mkIf (authorEmail != null) authorEmail;
      useConfigOnly = true;
    };
  };
}
