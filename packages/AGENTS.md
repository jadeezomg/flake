# PACKAGES

## Purpose

Custom flake packages auto-registered into overlays and flake package outputs.

## Use skills

- `flake-structure` — package layout, update metadata, overlays, and package exposure.

## Local hazards

- `packages/*/default.nix` files are auto-registered as `pkgs.<name>`; do not add explicit duplicate imports.
- Updatable packages need `update.json`; `.update-check.json` is generated state with a cooldown.
- To keep a package off a bad upstream release, add a `hold` to `update.json` (see `flake-structure`). Do not use `--version=skip` in `extra_args` for this, because it never expires.
- Use standard `callPackage` signatures; only accept final `pkgs` when the derivation genuinely needs it.
- Verify packages/dependencies with live nixpkgs tooling and cache availability before adding them.
- Packages not managed by nixpkgs must ship a removal solution for any mutable side effects (MCP entries, plugins, npm globals, config dirs, etc.) when they are dropped from the flake. Do not leave orphaned state for a later cleanup pass.

## Fields in `update.json`

`update-packages` (`scripts/src/flake_scripts/update_packages.py`) reads the fields below. If a required field is missing, or a field names an attribute that `default.nix` does not have, `validate_update_metadata` stops the run. Every type writes the new `version` into `default.nix`.

| Field | Types | Meaning |
|---|---|---|
| `type` | all | Required. The handler: `nix-update`, `npm`, `fetchzip` or `binary_channel`. |
| `hold` | all | Optional. Keeps the package off bad releases. It has `reason`, `bad_versions` (a list) and an optional GitHub `issue` URL. |
| `attr` | `nix-update` | Optional. The flake attribute for `nix-update --flake`. The default is the folder name. |
| `extra_args` | `nix-update` | Optional. A list of strings that goes to `nix-update` before the attribute. |
| `package` | `npm` | Required. The npm package name. The script reads `registry.npmjs.org/<package>/latest`. |
| `hash_field` | `npm`, `fetchzip` | The `default.nix` attribute for the source hash. Required for `npm`. For `fetchzip`, the default is `sha256`. |
| `npm_deps_hash_field` | `npm` | Required. The `default.nix` attribute for the hash of the npm dependencies. |
| `lock_file` | `npm` | Required. The path in the package folder where the script writes the new `package-lock.json`. |
| `version_url` | `fetchzip`, `binary_channel` | Required. The URL that gives the latest version, as JSON or as plain text. |
| `version_jsonpath` | `fetchzip`, `binary_channel` | Optional. A dotted path into the JSON from `version_url`, for example `tag_name`. Without it, the script uses the response text. |
| `version_strip_prefix` | `fetchzip`, `binary_channel` | Optional. A prefix that the script removes from the version, for example `v`. |
| `url_template` | `fetchzip`, `binary_channel` | Required. The download URL. It must contain `{version}`. For `binary_channel`, it must also contain `{platform}`. |
| `platforms.<system>.upstream_platform` | `binary_channel` | The upstream name for `{platform}`, for example `x86_64-unknown-linux-gnu`. The script also reads `platform`. `default.nix` must contain `<system>` and this name. |
| `platforms.<system>.hash_field` | `binary_channel` | The `default.nix` attribute for the hash of that platform. |
| `hash_fields` | `binary_channel` | The old form of `platforms`: a map from upstream platform to hash attribute. Use `platforms` or `hash_fields`, not both. |

The `npm` type also writes the tarball URL into `url` in `default.nix`.

Each time the script looks for a new version, it writes the time to `.update-check.json` in the package folder. For one hour after that time, a run skips the package. To ignore this cooldown, run `just update-packages --force`, or set `UPDATE_FORCE=1` for `just update`.
