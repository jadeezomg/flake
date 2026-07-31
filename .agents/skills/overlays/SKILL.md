---
name: overlays
description: Apply this flake's nixpkgs overlay rules, including the self-expiring workaround pattern. Use when adding, editing, or retiring anything under parts/overlays — package patches, overrideAttrs/overridePythonAttrs workarounds, doCheck or test skips, version pins, upstream-bug mirrors — or when an evaluation warning says an overlay is obsolete.
---

# Overlays

## Scope

Use this for everything under `parts/overlays/`. For where overlays sit in the wider flake, use `flake-structure`; for local package derivations, `packages/AGENTS.md`.

## Layout

- One overlay per file: `parts/overlays/<name>.nix`.
- `parts/overlays/default.nix` is the only registry — every overlay is imported and named there.
- `parts/overlays/expiry.nix` holds the obsolescence guards; workaround overlays receive it as `expiry`.
- `parts/overlays/local-packages.nix` auto-registers `packages/<name>`; never add a second registry.
- Restrict by platform inside the overlay with `builtins.match ".*-darwin" system != null` and return `{ }` when it does not apply.

## Every workaround expires

A workaround exists because of some upstream state — an old version, a missing patch, a `broken` flag, a stale test. That state will change, and nothing tells us when. Overlays therefore rot: they stay in the tree years after nixpkgs fixed the thing, and one day the patch they apply actively breaks the build.

So an overlay must encode its own justification as an eval-time condition and warn when the condition flips. Bind the guard in `default.nix` (the name is what the warning points at):

```nix
(import ./foo-fix.nix {
  inherit lib system;
  expiry = expiryFor "foo-fix";
})
```

### `expireWhen` — the condition *is* the justification

Use when the condition is exactly why the workaround exists. Once it holds, the override is provably redundant, so the guard hands back untouched upstream and warns.

```nix
foo = expiry.expireWhen {
  fixed = lib.versionAtLeast prev.foo.version "1.2";
  reason = "nixpkgs now ships foo >= 1.2.";
  fallback = prev.foo;
} (prev.foo.overrideAttrs (…));
```

`fallback` is nearly always the bare `prev` package. Prefer conditions that observe the *fix* rather than proxy for it:

| Workaround | Condition |
| --- | --- |
| Need a newer version | `lib.versionAtLeast prev.foo.version "X"` |
| Mirror an upstream patch | that patch's marker is in `prev.foo.postPatch` |
| Relax a dep bound | `lib.elem "dep" (prev.foo.pythonRelaxDeps or [ ])` |
| Fix wrong metadata | `prev.foo.pname == "expected"` |
| Pin a dep version | the right version is already in `prev.foo.buildInputs` |
| `markUnbroken` | `!prev.foo.meta.broken` |

If one override fixes two things, the condition must cover both (`&&`) — otherwise a half-fix retires a workaround that is still load-bearing.

### `recheckWhen` — the condition is only a hint

Use when the justification cannot be observed at eval time: sandbox hangs, flaky-under-Nix tests, `--skip=` lists that silently stop matching. Dropping the workaround on a guess would break the build, so this keeps applying it and only nags.

```nix
foo = expiry.recheckWhen {
  stale = lib.versionAtLeast prev.foo.version "1.5";
  reason = "foo reached 1.5 (skip verified needed at 1.3.2); retest the sandbox failure.";
} (prev.foo.overrideAttrs (…));
```

- Record the version the workaround was last verified against, in the `reason` and the file header.
- Set the threshold a few releases out, not the next patch bump — this fires on every eval until someone acts, so per-release nagging is just noise.

### No guard at all

Deliberate pins are not workarounds. `skhd-pinned-darwin.nix` pins for store-path stability (TCC grant churn); no upstream state retires it, only a decision to stop caring. Say so in the header instead of inventing a condition. Same for registries like `local-packages.nix`.

## Hazard: guard values, never the returned attrset

Nixpkgs must know an overlay's attribute *names* before it can evaluate the package set. A guard wrapped around the attrset an overlay returns forces its condition during that step, and any condition reading `prev.<drv>` loops back through `final` — **infinite recursion**, surfacing as a `flake fmt`/eval failure far from the cause.

```nix
# WRONG — condition forced while attribute names are being resolved
expiry.expireWhen { … } { foo = prev.foo.overrideAttrs (…); }

# RIGHT — condition forced only when someone asks for foo
{ foo = expiry.expireWhen { … } (prev.foo.overrideAttrs (…)); }
```

When one condition covers several packages, evaluate it per package (a small `guard = name: pkg: …` helper) rather than hoisting it above the attrset. Platform gates (`if !isDarwin then { } else …`) are safe: they force only `system`, a plain string.

## Acting on a warning

`evaluation warning: parts/overlays/<name>.nix is obsolete: …` means it can go now:

1. Delete the override; delete the file once nothing in it is still live.
2. Remove its entry from `parts/overlays/default.nix`.
3. Drop any flake input it existed for (a pinned nixpkgs, say).
4. Ask the user to rebuild — an obsolete override was suppressing upstream, so its removal changes what gets built.

`needs re-checking` means verify by hand, then either delete the file or move the threshold forward in both the `reason` and the header.

## Checks

1. `git add parts/overlays` before any eval — flakes only see tracked files.
2. `flake fmt` after editing `.nix` files.
3. Eval the overlaid set for each affected system and confirm the guards fire (or stay quiet) as intended:

```bash
nix eval --impure --raw --expr '
let
  f = builtins.getFlake (toString ./.);
  inputs = f.inputs;
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = import ./parts/overlays/default.nix { inherit inputs system; };
    config.allowUnfree = true;
  };
in pkgs.foo.version'
```

4. Check both a Linux and a Darwin system when the overlay is platform-gated; the recursion hazard shows up per-system.
5. Ask the user to run builds/switches — never run them yourself.
