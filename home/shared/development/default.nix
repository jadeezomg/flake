{...}: {
  # Languages migrated to modules/shared/profiles/devenv/languages/ in P3b.
  # What remains here is the small HM-widget layer (currently just
  # programs.opencode); everything package-ish lives in system profiles.
  imports = [
    ./tooling
  ];
}
