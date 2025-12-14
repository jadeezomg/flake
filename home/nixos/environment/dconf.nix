{ ... }:
{
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/mutter".experimental-features = [
      "scale-monitor-framebuffer"
    ];
  };
}
