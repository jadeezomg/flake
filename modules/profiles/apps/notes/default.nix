# Notes feature folder. App-specific packages and Home Manager settings live in
# sibling modules so Obsidian and Typora config stay grouped with their apps.
{
  imports = [
    ./obsidian.nix
    ./typora
  ];
}
