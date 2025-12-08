{
  apps = {
    # Core
    shell = "nushell";
    shelAlt = "bash";
    terminal = "wezterm";
    terminalAlt = "kitty";
    browser = "zen";
    browserAlt = "chrome";
    wm = "hyprland";

    # Files
    editor = "zeditor";
    editorAlt = "cursor";
    ide = "zeditor";
    ideAlt = "cursor";
    filesTerminal = "yazi";
    filesGraphic = "thunar";

    # Media
    imageViewer = "imv";
    videoPlayer = "mpv";
    audioPlayer = "mpv";

    # Productivity
    pdfViewer = "org.pwmt.zathura";
    pager = "most";
  };

  profiles = {
    firefox = {
      personal = "Personal";
      media = "Media";
      solenoidlabs = "SolenoidLabsPablo";
      uk = "UnitedKingdom";
      academic = "Academic";
      bsogood = "Bsogood";
      phantom = "TheHumanPalace";
      genai = "GenAI";
      ultra = "Ultra";
      segmentaim = "Segmentaim";
      littlejohn = "Little-John";
      private = "Private";
    };

    zen = {
      personal = "Personal";
      work = "Work-Zen";
      media = "Entertainment";
      dev = "Dev-Profile";
    };

    chromium = {
      personal = "Default";
      work = "Work";
      media = "Media";
    };

    brave = {
      personal = "Person 1";
      work = "Work";
      media = "Media";
    };
  };
}
