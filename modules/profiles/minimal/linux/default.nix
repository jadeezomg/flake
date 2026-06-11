# Linux-only user baseline (HM) — pushed by ../default.nix when !isDarwin.
_: {
  imports = [
    ./environment.nix
    ./guest-password-reminder.nix
  ];
}
