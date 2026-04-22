{...}: {
  # `./docs` was folded away in P4: obsidian moved to
  # modules/shared/profiles/apps/notes.nix and zathura moved to ./files.
  imports = [
    ./browsers
    ./editors
    ./files
    ./ides
    ./terminals
  ];
}
