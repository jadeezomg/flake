# HOSTS

## Purpose

Per-machine configuration: host facts, profile toggles, and host-specific system overrides.

## Use skills

- `flake-structure` — host folder ownership and top-level flake wiring.
- `module-structure` — profile toggles and profile/module interactions.
- `secrets-structure` — host runtime age keys and host-specific secrets.

## Local hazards

- Each host folder uses `host.nix` for facts, `profiles.nix` for `dotfiles.profiles.*`, and `default.nix` for host-specific system overrides.
- Edit host configs only in the local flake checkout on the machine you are running on. Never patch `/home/.../flake` over SSH on another host; deploy after local review.
- `.flake-host` selects the active host and must not be committed.
- `stateVersion` is per-host; never bump it without auditing release notes, and never lower it.
- `extraUsers` also receive Home Manager configs through `parts/hosts.nix`.
- mini's service modules and `mini/**` secrets are not in `hosts/mini/`. They live in the private mini-nix repo (`~/git/mini-nix`), which `hosts/mini/default.nix` imports as the `mini-nix` input. `flake.lock` pins its commit, so a push to mini-nix changes nothing until `mini bump`.

## Add a host

`<name>` is the key of the new host in `hosts/hosts.nix`. Use `hosts/framework` (workstation) or `hosts/mini` (server) as a model.

1. Add `<name> = import ./<name>/host.nix;` to `rawHosts` in `hosts/hosts.nix`. For a server, also set `hostClass = "server"` there.
2. Write `hosts/<name>/host.nix` as `sharedNixOSHost // { hostname = "<name>"; user = sharedNixOSUser; }`. `sharedNixOSHost` (`hosts/lib.nix`) gives `system`, `username` and `stateVersion`. If one of these four fields is missing, the registry stops the evaluation.
3. Keep `hostname` equal to `<name>`. The system output takes its name from `hostname`, and `just switch` builds the name in `.flake-host`.
4. Set `secureBoot = false` in `host.nix` until `sudo sbctl create-keys` ran on the machine. `modules/nixos/boot.nix` turns on lanzaboote by default.
5. Add `default.nix`, `hardware-configuration.nix` and `profiles.nix`. `default.nix` imports `../../modules/shared`, `../../modules/nixos`, `../../modules/profiles` and the two other files. If disko partitions the disk, also import `inputs.disko.nixosModules.disko` and `./disko.nix`, as mini does.
6. For a workstation, set `niriOutputsFile` and `dmsSettingsFile` in `host.nix`. Add those files to `modules/profiles/desktop/niri/` and `modules/profiles/desktop/dms/config/`. If `modules/profiles/desktop/umbriel/outputs-<name>.toml` exists, Umbriel loads it.
7. On the new machine, run `just bootstrap-sops-host-key`. Add the public key that it prints as `&<name>` to `keys` and to `creation_rules` in `.sops.yaml`. Then run `sops updatekeys secrets/secrets.yaml` (`docs/secrets/sops-age-keys.md`).
8. Add the hash `users/jadee/password_<name>` (`mkpasswd -m sha-512`) to `secrets/secrets.yaml` and a row for it to `secrets/SCHEMA.md`. `modules/nixos/user.nix` reads it. sops cannot decrypt it before the host key exists, so the first install needs a bootstrap step (`docs/hosts/mini.md`, "Rebuilding from scratch").
9. If `just init` must find the host from its hostname, add the host to `detect_host_from_hostname` in `scripts/shell/common.sh`. Otherwise, run `just _init <name>` on the machine.
10. To push agent sessions to mini, switch the new host once. Put the public key of `~/.ssh/agent_push_ed25519` into `host.nix` as `agentPushKey`. Then deploy mini and switch the host again.

For a Darwin host, use `hosts/caya` as the model. Its `host.nix` sets `system`, `username` and `stateVersion` itself. Its age key comes from `just setup-age-darwin`, and steps 4, 6, 8 and 10 do not apply.
