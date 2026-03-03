# Reads chrome/userChrome.css and chrome/userContent.css to append to Stylix theme.
# Edit the .css files in the chrome/ subfolder to change the rules.
{
  userChrome = builtins.readFile ./chrome/userChrome.css;
  userContent = builtins.readFile ./chrome/userContent.css;
}
