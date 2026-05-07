# HOSTS

Per-machine configuration. Each host has three files:
- `host.nix` — facts (hostname, hardware, monitor info)
- `profiles.nix` — profile toggles (`dotfiles.profiles.*`)
- `default.nix` — imports and host-specific system overrides

## Host Record Fields (`host.nix`)

Linux hosts use `sharedNixOSHost // { ... }` from `lib.nix`. Darwin defines fields directly.

Non-obvious fields:
```nix
{
  hostname = "desktop";      # system hostname (== hostKey; sets networking.hostName)
  mainMonitor = {
    monitorID = "DP-2";      # used in niri/display config
    monitorScalingFactor = "1.0";
  };
  extraUsers = [ ... ];      # optional guest users — HM configs auto-created for these
}
```

## Where to Put Things

| What | Where |
|------|-------|
| Host facts (hostname, monitors, `buildCores`, DMS/niri names, …) | `hosts/<name>/host.nix` |
| Profile toggles (`dotfiles.profiles`) | `hosts/<name>/profiles.nix` |
| Host-specific system packages / overrides | `hosts/<name>/default.nix` |

## Gotchas

- **`.flake-host`** — created by `just init`; stores the active host key; never commit it; all `nh`-based recipes read it
- **`stateVersion` is per-host** — bumping it gates default-value changes in NixOS/HM modules. Audit the release notes' "State Version Changes" section before raising it on an existing host; never lower it
- **Guest users** — `homeManagerConfig` in `parts/hosts.nix` also creates HM configs for `extraUsers`
