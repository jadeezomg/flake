# Vicinae launcher (HM half) — only pushed when the desktop profile is enabled.
{...}: {
  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 1;
      };
    };
  };
}
