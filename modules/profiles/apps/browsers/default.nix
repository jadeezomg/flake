# Browsers feature folder — zen is the daily driver (HM half in ./zen).
# firefox/chrome live in the work profile (homebrew casks on darwin).
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "apps" ];
  hm = [ ./zen ];
} args
