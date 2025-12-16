{...}: let
  # Default application identifiers (desktop entry names without extension)
  userEditor = "cursor"; # Cursor editor (available on macOS)
  userBrowser = "zen"; # Zen browser
  # Note: Many Linux-specific apps (mpv, imv, zathura) not available on macOS
in {
  # Darwin/macOS MIME configuration
  # Note: macOS uses LaunchServices rather than XDG MIME for most associations
  # This provides basic configuration that works with home-manager on Darwin

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Basic text and code files - these work cross-platform
      "text/plain" = ["${userEditor}.desktop"];
      "text/markdown" = ["${userEditor}.desktop"];

      # Programming languages
      "text/javascript" = ["${userEditor}.desktop"];
      "text/typescript" = ["${userEditor}.desktop"];
      "application/json" = ["${userEditor}.desktop"];
      "application/xml" = ["${userEditor}.desktop"];

      # Shell scripts
      "application/x-sh" = ["${userEditor}.desktop"];
      "application/x-shellscript" = ["${userEditor}.desktop"];

      # Web files
      "text/html" = ["${userBrowser}.desktop"];
      "text/css" = ["${userEditor}.desktop"];

      # Config files
      "application/toml" = ["${userEditor}.desktop"];
      "application/x-yaml" = ["${userEditor}.desktop"];
      "text/yaml" = ["${userEditor}.desktop"];
    };
  };
}
