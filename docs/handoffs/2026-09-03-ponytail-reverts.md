# Ponytail reverts after the 2026-09-03 flake cleanup

A ponytail review of the cleanup found six additions that are longer than
what they replaced. This plan lists the ones we agreed to revert. Everything
else from the review stays as is: `mkProfile`, the `llm.serve` split, the
`todo` combinator, and the sub-flag removal.

Do the steps in order. After each step run `flake fmt`, `git add`, and check
that all four hosts still evaluate:

```bash
for h in desktop framework mini; do
  nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath"
done
nix eval --raw .#darwinConfigurations.caya.config.system.build.toplevel.drvPath
```

Steps 1 and 2 are pure refactors. Compare the named attribute before and
after; it must be byte-identical.

## 1. Drop `hosts/mini/services/lib.nix` (`mkTsnetProxy`)

Why: 29 lines for a two-line Caddy string. `extra` has no caller.
`media/proxy.nix` grew from 45 to 52 lines.

- In `hosts/mini/services/media/proxy.nix`, replace the list plus
  `lib.mergeAttrsList` with one attrset of domain to upstream and a
  `lib.mapAttrs` that renders `import tsnet` and `reverse_proxy`.
- In `atuin.nix`, `beszel.nix`, `immich.nix`, `matrix.nix`, and
  `llm/open-webui.nix`, restore the inline three-line `extraConfig` string.
  Drop the `inherit (import ./lib.nix …) mkTsnetProxy` line and the `lib`
  argument where it was only added for the helper.
- Trash `hosts/mini/services/lib.nix`. Remove the pointer comment in
  `caddy.nix`.
- Check: `nix eval --json .#nixosConfigurations.mini.config.services.caddy.virtualHosts`
  is unchanged.

## 2. Drop the `mimeHandlers` option

Why: nine options and nine `mkDefault` baselines, but only `markdown` is
ever set or read. Keep the move of the table into
`modules/profiles/desktop/mime.nix` gated on `desktop.enable`. That part is
the real fix.

- In `mime.nix`, delete the `options.dotfiles.desktop.mimeHandlers` block
  and the `mkDefault` baselines. Put the handler names back in a `let`.
  Set `markdown` to `"typora"` when
  `config.dotfiles.profiles.apps.notes.enable` is true, otherwise to the
  editor.
- In `modules/profiles/apps/notes/typora/default.nix`, delete the
  `mimeHandlers.markdown = lib.mkOverride 900 …` line and its comment.
- In `modules/profiles/essentials/utils/yazi/default.nix`, delete the
  `markdownOpeners` map and the id-to-name derivation. Restore the old
  `lib.optionalAttrs (notes.enable) { opener.typora = …; }` block.
- Shrink `.agents/skills/xdg-default-apps/SKILL.md`: remove the option and
  priority paragraphs, keep the file location and the Yazi coupling note.
- Check: `xdg.mimeApps.defaultApplications` and `programs.yazi.settings`
  for `desktop` and `framework` are unchanged; `mini` still returns `{}`.

## 3. Drop `modules/profiles/devenv/languages/names.nix`

Why: a `readDir` to replace an eight-name list.

- Keep one list in `modules/profiles/devenv/languages/default.nix`.
- Move the `genAttrs langs (_: { enable = lib.mkDefault true; })` from
  `devenv/default.nix` into `languages/default.nix` under
  `lib.mkIf cfg.enable`.
- Trash `names.nix`. Update the note in
  `.agents/skills/module-structure/SKILL.md`.

## 4. Drop `hosts/mini/secrets.nix`

Why: `sops.secrets.hf_token = { };` merges when both consumers declare it.
The template has one consumer. Thirteen of the file's 31 lines are comment.

- Declare `hf_token` and the `mini-llm-hf.env` template in
  `hosts/mini/services/llm/default.nix`, and `hf_token` again in
  `hosts/mini/services/hermes.nix`.
- Move `hermes_dashboard_basic_auth_hash` back into `caddy.nix`.
- Remove the import from `hosts/mini/default.nix`, trash `secrets.nix`.
- Update `.agents/skills/secrets-structure/SKILL.md` line 46.
- Check: `nix eval .#nixosConfigurations.mini.config.sops.secrets --apply builtins.attrNames`
  is unchanged.

## 5. Remove dead exports and duplicate comments

- `lib/pkgs.nix`: delete `getPkgs`, `getPkgsStable`, `getPkgsSmall`. Keep
  `getPkgsWithConfig` and `pkgsFor`. Cut the header to three lines.
- `parts/hosts.nix`: six comments say that the package sets are shared. Keep
  one, at `hostPkgs`.
- `lib/profile.nix`: cut the header to the usage example and the sentence
  about applying to `args` instead of `imports`.
- `modules/profiles/devenv/agents/apm.nix`: cut the `fixLocalCopyPerms`
  comment to three lines. Replace the loop with one `chmod -R u+rwX` over
  both paths with `2>/dev/null || true`.
- Grep the skills for the deleted names: `getPkgs`, `mkTsnetProxy`,
  `mimeHandlers`, `names.nix`, `secrets.nix`.

## Expected result

About 300 lines fewer. Derivation paths for all four hosts unchanged after
steps 1 to 3, and unchanged after steps 4 and 5 apart from comment-only
edits.
