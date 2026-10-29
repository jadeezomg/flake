# Darwin-only leaf of devgui.agents: Zed's Delta as a Homebrew cask. Linux gets
# it from the delta-nix input (devgui/ides).
{ dotfilesLib, lib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  extra.homebrew = {
    # mkDefault so the work profile keeps ownership of `enable` on caya, and
    # devgui alone still turns homebrew on for a darwin host without work.
    enable = lib.mkDefault true;

    casks = [ "zed-delta" ];
  };
} args
