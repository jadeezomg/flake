# Plan: network stack migration

**Status:** proposed — NetBird recommended, Pangolin rejected
**Related:** [research/netbird.md](../research/netbird.md), [research/pangolin.md](../research/pangolin.md), `services/caddy.nix` in the private mini-nix repo, [modules/nixos/networking.nix](../../modules/nixos/networking.nix), [scripts/shell/dns-sync.bash](../../scripts/shell/dns-sync.bash)

**Implementation (status on 2026-11-02):** open. No phase started. The flake has no NetBird configuration, and Tailscale still runs on every host (`modules/nixos/networking.nix`, `modules/darwin/default.nix`). Blocker B1 is closed: the locked nixpkgs has `netbird` 0.81.5. B2 is still open, but it is now cheap.

**Re-checked on 2026-11-02** against NetBird v0.82.0 and Pangolin 1.25.3. The decision still holds. The research notes keep their August state. The facts below that changed are marked with their source.

---

## Current state

| Layer | What runs today |
|---|---|
| Mesh | Tailscale (hosted control plane) on `desktop`, `framework`, `caya`, `mini`; `--ssh` on |
| Trust anchor | `networking.firewall.trustedInterfaces = [ "tailscale0" ]` on every NixOS host |
| Ingress | Caddy on a dedicated tailnet node `mini-proxy`, with `caddy-tailscale` and `caddy-dns/cloudflare` |
| TLS | Let's Encrypt, Cloudflare DNS-01, real certificates on private names |
| DNS | Cloudflare A records point at the private `100.x` Tailscale address. LAN clients get a split-horizon override to `miniLanAddress` |
| Public exposure | None. No inbound port open. Matrix federation off |
| Services | 16 `*.jadee.fyi` vhosts on mini. Media payloads come from Unraid over NFS |
| Secrets | sops-nix (`cloudflare_dns_api_token`, `tailscale_authkey`, basic-auth hash) |

## Goals

1. Same or more function than today.
2. Configuration as declarative as possible.
3. Simplicity. Fewer services, or a few simple services that work together.
4. Public access. Nice to have, with zero trust and 2FA.
5. Speed for media streaming.

## Non-goals

- Matrix federation. It stays off.
- High availability of the control plane.

---

## Options considered

| Target | Current | Pangolin | NetBird |
|---|---|---|---|
| 1. Same or more function | baseline | Loses mesh and client-to-client | Matches, adds self-hosting and ingress |
| 2. Declarative | Everything is Nix | Resources live in a database | Good client module. Policy needs Terraform |
| 3. Simplicity | 2 services | 6 components and a VPS, Caddy still stays | 1 service on cloud, 3 containers if self-hosted |
| 4. Public access + zero trust | None | Strongest of the three | Works, but beta and Traefik-only |
| 5. Streaming speed | Direct peer, LAN bind on Caddy | Public traffic always transits the VPS | Best. Kernel WireGuard, ICE host candidates |

### Why Pangolin is rejected

Pangolin fails three of the five targets. It is hub-and-spoke, so it removes the mesh and
client-to-client access. Clients connect only to sites. Pangolin 1.24.0 added exit nodes,
which need Newt 1.18.0 or later. It also added a subnet router that runs only on Linux. Its
own docs still say to use a VPN for broad network access. Its resources live in a database and are created
through the dashboard, so ingress stops being Nix. It adds Pangolin, Gerbil, Traefik, Badger,
Newt, Olm clients, and a VPS host, while Caddy still has to stay for LAN access. Public
resources have no direct path, so every byte of a public media stream transits the VPS.

It wins only on public ingress, which is target 4 and a nice to have.

The full analysis stays in [research/pangolin.md](../research/pangolin.md). Appendix A keeps
the ingress-only variant, because NetBird's own ingress is still in beta.

### Why NetBird is the candidate

It replaces Tailscale and keeps Caddy. The service count stays at two, the same as today.

| Gain | Detail |
|---|---|
| Speed on Linux | Kernel WireGuard on `desktop`, `framework`, `mini`. `caya` stays userspace |
| LAN stays on the LAN | ICE host candidates are priority 1, so two LAN peers connect direct |
| No SaaS dependency | The control plane is self-hostable |
| Free SSH and MFA | Identity-based SSH and TOTP, with no external IdP since v0.62 |
| Policy as code | Official Terraform provider, 24 resources: policies, groups, routes, DNS, setup keys |
| A path to target 4 | NetBird Reverse Proxy, when it leaves beta |

Honest limits:

- There is no single reviewable ACL file. Tailscale has one HuJSON document. NetBird has 24
  Terraform resources and no whole-config export. This is wider coverage but worse
  reviewability.
- The Terraform provider cannot create peers. A setup key does that.
- `caya` gets no speed gain. macOS is always userspace `wireguard-go`.

---

## Blockers

Do not start Phase 1 until both are closed.

### B1 — The packaged version is vulnerable (closed)

GHSA-qcpp-8vwj-hhwr: the client daemon IPC socket was world-writable at mode 0666 with no
authentication, from 0.5.0 to 0.75.1. A local unprivileged user could enable SSH root login.
The fix is 0.76.0. GHSA-28q5-j9qm-gx35 (published 2026-09-01) let a local user read any
root-owned file through the same daemon socket. Its fix is 0.76.1, so 0.76.1 is now the
minimum safe version. Four other advisories from August and September are fixed at 0.75.0
or earlier.

| Channel | Version | State |
|---|---|---|
| nixpkgs stable 26.05 | 0.71.4 | Vulnerable |
| nixpkgs unstable (this flake's lock) | 0.81.5 | Safe |

The flake follows unstable, so no overlay is needed. If you pin `netbird` to stable, the
version is vulnerable again. mini runs services under several users, so this is a real
exposure there.

### B2 — Address range collision

NetBird and Tailscale both default to `100.64.0.0/10`. Stale `ts-input` iptables rules also
drop NetBird traffic without a message.

Set the NetBird network range to a range outside `100.64.0.0/10`, for example
`10.100.0.0/16`, before the first peer joins. NetBird now accepts any IPv4 range, and a range
change re-addresses every peer live, so no peer has to enroll again
(`https://docs.netbird.io/manage/settings/networks`). A range outside `100.64.0.0/10` also avoids the
stale `ts-input` drop rule. The release that added this is not known.

---

## Phases

Tailscale stays until Phase 6. Nothing before then is a point of no return. NetBird and
Tailscale run side by side, on separate interfaces and separate address ranges.

### Phase 0 — Prerequisites

1. Close B1 and B2.
2. Create a NetBird Cloud account on the free tier: 5 users, 100 machines. Self-hosting comes
   in Phase 7, after the migration is proven. Do not change two things at once.
3. Create a setup key. Add it to sops as `netbird_setup_key`.

### Phase 1 — One peer, side by side

Add the client to `framework` only. It is a laptop, so a failure costs nothing.

```nix
services.netbird.clients.nb = {
  openFirewall = true;   # UDP 49152-65535 — required for direct LAN peering
  hardened = true;
  login = {
    enable = true;
    setupKeyFile = config.sops.secrets.netbird_setup_key.path;
  };
};
```

`services.netbird.clients.<name>.login.setupKeyFile` composes directly with sops-nix.
`login.systemdDependencies` orders the unit after the secret is available.

Confirm that the peer appears and that Tailscale still works.

### Phase 2 — All peers

Add the same client to `desktop` and `mini`. On `caya`, nix-darwin exposes only
`services.netbird.enable` and `services.netbird.package` — there is no setup-key option, so
that host needs one manual login.

CAUTION: on a flat LAN with no NAT, a host firewall silently forces `Relayed` instead of a
direct connection. Media then crosses the relay. Run `netbird status -d` on each peer and
confirm the candidate type is `host/host` for LAN pairs. Do not assume it.

### Phase 3 — Routes and DNS

- Add a subnet router on `mini` for the LAN, so Unraid and other LAN-only devices stay
  reachable. `useRoutingFeatures` controls this in the module.
- Set up the private DNS zone. Self-hosting allows a custom zone; the cloud uses
  `*.netbird.cloud`.
- Do not touch `dns-sync.bash` yet.

### Phase 4 — Policy as code

Bring the Terraform provider in and define groups, policies, routes, DNS, and setup keys as
code. Store the state next to the flake, not in the flake.

This is the phase that decides whether target 2 is met. If the Terraform round trip is
painful, stop and reconsider before Phase 6 — that is the last cheap exit.

### Phase 5 — Caddy and SSH cutover

**Caddy gets simpler.** `caddy-tailscale` exists so Caddy owns `:443` on its own tailnet node
`mini-proxy`, without colliding with mini's own node. NetBird has no equivalent plugin and no
equivalent collision, so Caddy binds mini's NetBird address and the LAN address directly.

That removes the plugin, the Go pseudo-version pin, and the `hash` that has to be refreshed on
every bump. `pkgs.caddy.withPlugins` keeps only `caddy-dns/cloudflare`.

Then:

- Change `scripts/shell/dns-sync.bash` to write NetBird addresses instead of Tailscale
  addresses.
- Keep the split-horizon LAN override. It is what keeps a TV streaming direct from mini.
- Move SSH to NetBird SSH, or to plain key authentication. `data/users/users.nix` already
  declares three authorized keys and `modules/nixos/user.nix` wires them into
  `openssh.authorizedKeys.keys`, so key authentication already works.
- Change `networking.firewall.trustedInterfaces` from `tailscale0` to the NetBird interface.

Run both meshes in parallel for a week after the DNS flip. Rollback is one DNS change.

### Phase 6 — Remove Tailscale

Remove `services.tailscale` from `modules/nixos/networking.nix` and
`modules/darwin/default.nix`. Remove `tailscale_authkey` from sops. Flush stale `ts-input`
iptables rules on every host.

### Phase 7 — Self-host the control plane (optional)

Only after Phase 6 is stable.

Three containers: server, dashboard, Traefik. One volume, one DNS record, ports 80/443 TCP and
3478 UDP. SQLite by default. No external IdP is needed since v0.62 — Dex is embedded, with
local users and free TOTP.

CAUTION: `services.netbird.server.*` in nixpkgs tracks the pre-0.62 architecture. It requires
`oidcConfigEndpoint`, it uses Coturn instead of the new relay, and there is no module for the
combined server or the proxy. Either wait for the module to catch up, or write your own.

Since this plan was written, nixpkgs gained the `netbird-combined` package (0.82.0) and a
`services.netbird.relay` module (merged 2026-09-16). They do not remove the caution above:
the server module still requires an OIDC endpoint and Coturn.

This step also needs a public FQDN and a public VM, which the hosted control plane does not.
That is a cost against target 3.

### Phase 8 — Public ingress (optional)

NetBird Reverse Proxy covers target 4: public exposure, TLS termination, automatic
certificates, HTTP/TCP/UDP and TLS passthrough, with SSO, password, PIN, header auth, IP CIDR,
country, and CrowdSec in front. There is a `netbird expose` CLI.

It is **in beta**. Self-hosted it requires Traefik and a separate `netbird-proxy` container,
with no NixOS module. That conflicts with keeping Caddy.

Do not plan this. Revisit when it leaves beta. If public ingress becomes urgent first, read
Appendix A.

---

## Risk register

| Risk | Detail |
|---|---|
| Maturity | Still 0.x. 470 open issues against 2,419 closed (2026-11-02). v0.80.0 (#7647) moved bug reports to Discussions, so the drop shows triage, not quality. About six people hold most commits |
| Support policy | Latest release only. No backports |
| Security history | The 3.5-year IPC socket bug (B1), then GHSA-28q5-j9qm-gx35 on the same socket and four more advisories in August and September 2026, all fixed by 0.76.1. Also a default-admin-password CVE at CVSS 9.3, fixed in 0.57.0 |
| Known issues | #2454 (macOS sleep recovery) closed on 2026-10-06. The vendor says v0.60.4 and v0.70.2 fixed it. #4990 (LAN subnets relayed because of route metrics) is still open. Check it in Phase 3 |
| Deprecations | v0.82.0 deprecates Rosenpass, the post-quantum feature. This plan does not use it |
| Audit | No public audit. Pentest reports sit behind a request form |
| Breaking changes | The SSH model changed twice. The client was rewritten from Fyne to Wails. Management-first upgrade ordering is required, with at least one silent version-skew failure |
| License drift | Relicensed once in 2025, BSD to a BSD/AGPL split. There is a CLA and Series A funding |
| Exit cost | Low. Nothing is BSL. One Go repo, so a fork is realistic |

Paid gates on self-hosted are HA, SCIM, EDR/MDM, and traffic-flow logging, at a €2,000/yr
minimum with a hard cliff. Everything this plan uses is free: SSO, MFA, unlimited users,
policies, networks, exit nodes, posture checks, audit logging, SSH, reverse proxy.

---

## Appendix A — Pangolin as ingress only

Keep this only as a fallback, if public ingress becomes urgent while NetBird Reverse Proxy is
still in beta. It is additive: NetBird or Tailscale keeps the mesh, Pangolin does public
ingress alone.

- A VPS is mandatory. Pangolin's public node needs a routable public IPv4 address. Check for
  CGNAT first: run `dig +short myip.opendns.com @resolver1.opendns.com` and compare it to the
  router's WAN address. If they differ, or the WAN address is in `100.64.0.0/10`, this option
  is out.
- Do not run it on mini. That opens 80/443 TCP and 51820 UDP at home, points public DNS at the
  home address, and puts an authentication bypass on the host with Immich, Matrix, and the NFS
  mounts into Unraid. CVE-2025-56332 was a CVSS 9.1 bypass from an insecure default. Two more
  bypasses on public resources followed: CVE-2026-72001 before 1.22.0 (CVSS 4.0 score 8.6,
  NVD) and CVE-2026-72564 up to 1.20.0 (no NVD score yet). Pangolin publishes no GitHub
  security advisories.
- nixpkgs has `services.pangolin`, `fosrl-pangolin` 1.24.0 on unstable and on stable 26.05,
  and `fosrl-newt`. Upstream is at 1.25.3. 1.25.0 can export resources to a blueprint (a YAML
  resource file), which helps a little with declarative configuration.
- The module still pins Badger to `v1.2.0`, which Pangolin 1.19+ rejects, and it still has
  its TODOs. Set Badger to `v1.7.0`: upstream says to stay there, because v1.8.0 fails
  Traefik's integrity check. Traefik also downloads Badger from GitHub at every start, so the
  VPS needs egress to GitHub.
- Expose only the services that need public access. Keep everything else on Caddy.
- Media served this way always transits the VPS. Keep split-horizon DNS so LAN clients never
  leave the LAN.
