# Archived Language Stubs

Disabled `home/shared/development/languages/<lang>.nix` files preserved here for
future re-enable. To revive a language:

1. Move the file to `modules/shared/profiles/devenv/languages/<lang>.nix`.
2. Rewrite it as a system module gated on
   `config.dotfiles.profiles.devenv.languages.<lang>.enable`, matching the
   template used by the active languages.
3. Register `<lang>` in the `langs` list in
   `modules/shared/profiles/devenv/languages/default.nix`.
4. Add `<lang>.enable = lib.mkDefault true;` in
   `modules/shared/profiles/devenv/default.nix` under the `devenv.enable` block
   if you want it on by default for hosts that enable `devenv`.
