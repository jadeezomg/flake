# Homepage look: the Birds of Paradise palette and the desktop wallpapers.
#
# Returns the values that ./default.nix puts into the Homepage settings and
# the Caddy vhost:
#
#   css         the palette as Homepage color variables, and the fade layer
#   js          a random wallpaper on load, then a new one on the desktop
#               interval, with a fade
#   background  Homepage settings.background. The image is empty, so the page
#               fades in from the background color, like Noctalia with
#               transition_on_startup.
#   caddyRoute  serves the wallpapers at /wallpapers/ on the Homepage vhost
#
# The wallpapers are the ones Noctalia rotates on the desktop
# (modules/profiles/theme/wallpapers), and the interval is Noctalia's
# wallpaper.automation.interval_seconds. The build scales each image to at
# most 2560x1600 and compresses it, so the page does not load the 93 MB of
# originals.
{
  lib,
  pkgs,
  palette,
}:
let
  source = ../../../../modules/profiles/theme/wallpapers;
  noctalia = lib.importTOML ../../../../modules/profiles/desktop/noctalia/config/settings.toml;
  interval = noctalia.wallpaper.automation.interval_seconds or 1800;

  images = lib.filter (
    name:
    lib.any (lib.flip lib.hasSuffix (lib.toLower name)) [
      ".jpg"
      ".jpeg"
      ".png"
      ".webp"
    ]
  ) (lib.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir source)));
  # A hash of the file name: safe in a URL, and a new set of images never
  # shows a file that the browser cached under the same name.
  served = name: "${builtins.substring 0 16 (builtins.hashString "sha256" name)}.jpg";

  wallpapers = pkgs.runCommand "homepage-wallpapers" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir $out
    ${lib.concatMapStrings (name: ''
      magick ${lib.escapeShellArg "${source}/${name}"} -auto-orient -resize '2560x1600>' \
        -strip -quality 80 -interlace Plane "$out/${served name}"
    '') images}
  '';

  # Homepage puts a layer of the page color over the image. The alpha is
  # 1 - opacity/100, so 60 keeps the image clear and the text readable.
  opacity = 60;
  overlay = "rgb(var(--bg-color) / ${toString ((100 - opacity) / 100.0)})";

  # Homepage color steps -> palette keys. The dark theme uses 50-400 for text
  # and 600-900 for surfaces. 800 is the page background.
  steps = {
    "50" = "text-secondary";
    "100" = "text-primary";
    "200" = "text-primary";
    "300" = "text-tertiary";
    "400" = "ansi-bright-black";
    "500" = "ansi-bright-black";
    "600" = "ansi-black";
    "700" = "bg-tertiary";
    "800" = "bg-primary";
    "900" = "bg-secondary";
  };
  rgb =
    hex:
    let
      digits = lib.removePrefix "#" hex;
      byte = i: toString (lib.fromHexString (builtins.substring i 2 digits));
    in
    "${byte 0} ${byte 2} ${byte 4}";
in
{
  background = {
    image = "data:,";
    inherit opacity;
  };

  # html[class] is more specific than Homepage's .theme-<color> rule.
  css = ''
    html[class] {
    ${
      lib.concatStrings (
        lib.mapAttrsToList (step: key: "  --color-${step}: ${rgb palette.${key}};\n") steps
      )
    }}

    .wallpaper-next {
      position: fixed;
      inset: 0;
      z-index: 0;
      background-size: cover;
      background-position: center;
      background-repeat: no-repeat;
      pointer-events: none;
      opacity: 0;
      transition: opacity 2s ease-in-out;
    }
  '';

  js = ''
    (() => {
      const wallpapers = ${builtins.toJSON (map (name: "/wallpapers/${served name}") images)};
      const overlay = "${overlay}";
      let current = null;

      const pick = () => {
        const others = wallpapers.filter((url) => url !== current);
        return others[Math.floor(Math.random() * others.length)];
      };

      // Load the image first, then fade a new layer in over #background.
      const show = (url) => {
        const base = document.getElementById("background");
        if (!base) return;
        const style = "linear-gradient(" + overlay + ", " + overlay + "), url('" + url + "')";
        const image = new Image();
        image.onload = () => {
          current = url;
          const layer = document.createElement("div");
          layer.className = "wallpaper-next";
          layer.style.backgroundImage = style;
          base.after(layer);
          requestAnimationFrame(() => requestAnimationFrame(() => (layer.style.opacity = "1")));
          layer.addEventListener(
            "transitionend",
            () => {
              base.style.backgroundImage = style;
              layer.remove();
            },
            { once: true },
          );
        };
        image.src = url;
      };

      const start = () => {
        show(pick());
        setInterval(() => show(pick()), ${toString interval} * 1000);
      };
      if (document.readyState === "complete") start();
      else window.addEventListener("load", start, { once: true });
    })();
  '';

  caddyRoute = ''
    handle_path /wallpapers/* {
      root * ${wallpapers}
      header Cache-Control "public, max-age=604800"
      file_server
    }
  '';
}
