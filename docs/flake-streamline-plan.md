# Flake streamline plan

## Context

This plan comes from comparing this flake with `~/.dotfiles/examples/dotfiles`. Both are flake-parts mono-flakes for NixOS, nix-darwin, and Home Manager, but they put complexity in different places.

This flake is stronger at host automation and operator workflow: `hosts/hosts.nix` validates host metadata, `parts/hosts.nix` generates system outputs, `dotfiles.profiles.*` gives one per-host feature surface, `packages/` auto-registers local derivations, and the Justfile/scripts layer is the primary day-to-day interface.

The example flake is stronger at structural isolation and testability: the root `flake.nix` only delegates to flake-parts partitions, platform-specific inputs live in partition sub-flakes, hosts are layered into `system/`, `session/`, `home-manager/`, and `secrets/`, wrapped CLI programs share one `my.*` contract, and nixosTests cover both program wrappers and host stacks.

Goal: keep this flake's registry/profile/Justfile strengths while borrowing the example's input isolation, wrapped-program contract, and host-test boundaries.

## Principles

- Keep `hosts/hosts.nix` as the source of host metadata. Do not replace it with hand-listed host outputs.
- Keep `dotfiles.profiles.*` as the host-facing feature API.
- Keep rich GUI and desktop Home Manager config under `home/`; do not force Zed, Zen, niri, or DMS into a generic wrapper framework.
- Use a wrapper framework only for CLIs where baked config, system/user scope, Stylix, and tests matter.
- Thin the flake root before adding new abstraction.
- Add tests at boundaries that actually break: host module composition, wrapper plumbing, profile interactions.

## Phase 1 — Thin `flake.nix` and remove package duplication

Problem: `flake.nix` owns all inputs and also manually exposes several packages that are already candidates for `packages/` + overlay auto-registration.

Plan:

1. Move the current `perSystem.packages`, `checks`, and `formatter` block out of `flake.nix` into flake-parts modules under `parts/`.
2. Prefer a single package exposure mechanism:
   - `packages/<name>/default.nix` is registered by `parts/overlays/local-packages.nix`.
   - `perSystem.packages` should expose from `pkgs.<name>` or a small generated list, not duplicate import boilerplate.
3. Keep `lib/pkgs.nix` as the central `getPkgs`, `getPkgsStable`, and `getPkgsWithConfig` implementation.
4. Target shape:

```nix
outputs = inputs @ {flake-parts, ...}:
  flake-parts.lib.mkFlake {inherit inputs;} {
    imports = [
      ./parts/hosts.nix
      ./parts/shells.nix
      ./parts/packages.nix
      ./parts/checks.nix
    ];

    systems = ["x86_64-linux" "aarch64-darwin"];
  };
```

Acceptance:

- Root `flake.nix` contains inputs and flake-parts wiring only.
- Local package definitions are not manually imported in two places.
- Existing package attrs remain available to users and profiles.

## Phase 2 — Layer one host for testability

Problem: host directories are mostly flat. Tests cannot easily import only the system stack without also pulling unrelated user/session concerns.

Plan:

1. Pilot on `hosts/framework` because it is a primary Linux workstation and already has host-specific hardware, power, GPU, input, and profile modules.
2. Restructure toward:

```text
hosts/framework/
├── host.nix
├── default.nix
├── system/
│   ├── default.nix
│   ├── hardware.nix
│   ├── gpu.nix
│   ├── input.nix
│   ├── power.nix
│   └── profiles.nix
├── home-manager/
└── tests/
    └── base.nix
```

3. Keep `default.nix` as the public import path used by `parts/hosts.nix`.
4. Move only when it improves boundaries; do not create empty directories just to match the example.

Acceptance:

- `parts/hosts.nix` still imports `hosts/framework` unchanged.
- A framework test can import `hosts/framework/system` without importing host-specific HM/session extras.
- The pattern is documented before repeating it across other hosts.

## Phase 3 — Add host and profile checks

Problem: current flake checks only cover MCP server config. Structural profile regressions are caught late, during switch.

Plan:

1. Add one smoke `nixosTest` for the pilot Linux host stack.
2. Add tests for profile interactions that are easy to break:
   - minimal + essentials enabled by default;
   - desktop profile gates Linux-only desktop modules;
   - server-class hosts do not accidentally import desktop/session modules.
3. Wire checks through `parts/checks.nix`, not root `flake.nix`.
4. Keep tests behavioral. Do not assert that a config option equals its current default unless the behavior depends on it.

Acceptance:

- `nix flake check` evaluates at least one Linux host smoke test.
- Tests import stable module boundaries, not implementation snippets.
- Existing `tests/mcp-servers.nix` remains covered.

## Phase 4 — Add a selective `my.*`-style CLI wrapper layer

Problem: CLI config is split between system profiles, Home Manager modules, and package overlays. Tools that need baked config, wrapping, Stylix, or system/user scope lack one common contract.

Plan:

1. Add a small wrapper framework inspired by the example's `modules/my/`, but scoped to CLIs only.
2. Initial candidates:
   - `git`
   - `jujutsu`
   - `gh`
   - `starship`
   - `direnv`
   - later: `rg`, `fd`, `fish`, `ghostty` if the contract proves useful
3. Contract shape:

```nix
{lib, pkgs}: {
  name = "git";
  defaultPackage = "git";
  options = { ... };
  themeable = false;
  build = {cfg, pkgs, lib, theme ? null, specialArgs ? {}, ...}:
    pkgs.mkWrapped { ... };
}
```

4. Expose:
   - `dotfiles.tools.<name>.enable` or `my.<name>.enable` at system scope;
   - optional per-user overrides only where needed;
   - read-only `finalPackage` for tests.
5. Keep `dotfiles.profiles.*` as the UX. Profiles may enable wrapper tools internally.

Acceptance:

- At least two CLIs are moved onto the new contract.
- Their old parallel config path is disabled or removed in the same change.
- Wrapper tests prove settings flow into the wrapped binary.

## Phase 5 — Introduce flake-parts partitions for input isolation

Problem: every host currently sees one large input graph. Linux desktop, macOS Homebrew, AI/server, and hardware-specific inputs churn together.

Plan:

1. Add `inputs.flake-parts.flakeModules.partitions` to the root flake.
2. Split platform-specific inputs into partition sub-flakes:

| Partition | Inputs |
| --- | --- |
| `nixos` | `disko`, `lanzaboote`, `dms`, `quickshell`, `nix-cachyos-kernel`, `framework-control`, `vllm-xpu-nix`, `nixos-hardware` |
| `darwin` | `nix-darwin`, `nix-homebrew`, `homebrew-*` |
| `dev` | formatter/check/devShell-specific dependencies |
| shared root | `flake-parts`, primary nixpkgs channels, `home-manager`, `sops-nix`, `stylix` if still common |

3. Preserve `hosts/hosts.nix` registry generation. Partitions should feed the existing host factory, not replace it with hand-written host lists.
4. Move only inputs with clear platform ownership first. Leave cross-cutting inputs in root until proven otherwise.

Acceptance:

- Darwin eval does not require Linux-only desktop/hardware/server inputs.
- Linux eval does not require Homebrew pins.
- Host output names stay stable.

## Keep as-is

These parts are already structurally better than the example and should remain:

- `hosts/hosts.nix` registry and validation.
- `parts/hosts.nix` host-output generation.
- `dotfiles.profiles.*` as the host-facing feature switchboard.
- `lib/pkgs.nix` as the pkgs import policy.
- `packages/` with overlay auto-registration.
- Justfile and `scripts/` as the operator interface.
- `data/agents/` and project-specific agent assets.

## Non-goals

- No full rewrite to match the example repository.
- No generic abstraction for rich GUI apps.
- No removal of Justfile workflow.
- No hand-written host output list unless the registry becomes a proven problem.
- No test that merely locks current defaults instead of behavior.
