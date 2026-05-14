{
  host,
  lib,
  ...
}: {
  imports =
    [
      ./environment.nix
      ./files.nix
      ./guest-password-reminder.nix
    ]
    # Desktop / niri / DMS HM config only makes sense on hosts that have a
    # main monitor. Headless hosts (mini) omit `mainMonitor` in `host.nix`.
    ++ lib.optionals (host ? mainMonitor) [
      ./desktop
    ];
}
