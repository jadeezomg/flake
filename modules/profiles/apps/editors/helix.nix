{
  isDarwin,
  osConfig,
  pkgs,
  ...
}:
let
  # Value-read (not a profile gate): is this a DMS desktop host?
  hasDesktopSession = osConfig.dotfiles.profiles.desktop.enable or false;
  desktopShell = osConfig.dotfiles.profiles.desktop.shell or "dms";
in
{
  imports = [
    ./helix
  ];

  programs.helix = {
    enable = true;
    package = pkgs.helix;

    # Explicit clipboard provider, by platform/session:
    # - darwin: absolute pbcopy/pbpaste paths — helix spawns the provider via
    #   the editor's PATH, which can lack /usr/bin ("os error 2" on yank).
    # - Noctalia desktops: built-in Wayland clipboard (wl-clipboard).
    # - DMS desktops: the DMS clipboard manager owns the Wayland clipboard
    #   (https://danklinux.com/docs/dankmaterialshell/cli-clipboard) — use
    #   `dms cl` instead of shipping wl-clipboard.
    # - headless / SSH: OSC 52 ("termcode") — the terminal forwards yanks to
    #   the *local* clipboard; pasting from outside uses terminal paste.
    settings.editor.clipboard-provider =
      if isDarwin then
        {
          custom = {
            yank = {
              command = "/usr/bin/pbcopy";
            };
            paste = {
              command = "/usr/bin/pbpaste";
            };
          };
        }
      else if hasDesktopSession && desktopShell == "noctalia" then
        "wayland"
      else if hasDesktopSession then
        {
          custom = {
            yank = {
              command = "dms";
              args = [
                "cl"
                "copy"
              ];
            };
            paste = {
              command = "dms";
              args = [
                "cl"
                "paste"
              ];
            };
          };
        }
      else
        "termcode";

    # y, p, and d use the system clipboard (register +), like vim's
    # clipboard=unnamedplus; plain `y` otherwise only fills Helix's own
    # register. Alt-d deletes without touching the clipboard. Headless hosts
    # keep the default: termcode (OSC 52) can send to the clipboard but not
    # read it, so `p` would paste nothing there.
    settings.editor.default-yank-register = if isDarwin || hasDesktopSession then "+" else "\"";
  };
}
