# Research: Pangolin as homelab network infrastructure

**Status:** research notes (2026-08-08)
**Scope:** primary sources only — `fosrl/*` repository source and READMEs, `docs.pangolin.net` (source: `fosrl/docs-v2`), `LICENSE` files, nixpkgs source, NVD.
**Verdict:** Pangolin is authenticated ingress **plus** a client-based zero-trust VPN. It is not a peer mesh VPN. NixOS support exists and is better than expected.

---

## 0. Naming correction

The project renamed its hosts. `digpangolin.com` is gone. The current official hosts are:

| Purpose | URL |
|---|---|
| Website and pricing | `https://pangolin.net/` |
| Documentation | `https://docs.pangolin.net/` |
| Docs source | `https://github.com/fosrl/docs-v2` |
| Old docs repo | `fosrl/docs` — archived, README says "Please use fosrl/docs-v2" |

Source: [pangolin README](https://github.com/fosrl/pangolin/blob/main/README.md) links Website, Documentation, and Contact at those hosts.

---

## 1. What Pangolin is

Pangolin gives remote access to services on private networks without a public IP address, without open inbound ports, and without a flat network. A connector on the private network dials **out** to a public node. The node terminates TLS, authenticates the user, and forwards the request into the tunnel. The same control plane also hands out client tunnels for private, client-only access. The README states it directly: "Pangolin is an open-source, identity-based remote access platform built on WireGuard® that enables secure connectivity to infrastructure anywhere. It combines reverse-proxy and VPN capabilities into one platform" ([README](https://github.com/fosrl/pangolin/blob/main/README.md)).

**Publisher.** Fossorial, Inc. The `LICENSE` file carries "Copyright (c) 2025 Fossorial, Inc." Security reports go to `security@pangolin.net` ([SECURITY.md](https://github.com/fosrl/pangolin/blob/main/SECURITY.md)).

**Commercial model.** Three delivery paths, from the README "Deployment Options" section:

1. **Pangolin Cloud** — managed SaaS at `app.pangolin.net`.
2. **Self-Host Community Edition (CE)** — "Free, open source, and licensed under AGPL-3."
3. **Self-Host Enterprise Edition (EE)** — "Licensed under Fossorial Commercial License. Free for personal and hobbyist use, and for businesses making less than $100K USD gross annual revenue."

---

## 2. Architecture

### 2.1 Component roles

The docs give a table of roles and engineering codenames ([system-architecture](https://docs.pangolin.net/development/system-architecture)):

| Component | Repo | Role |
|---|---|---|
| **Pangolin** | `fosrl/pangolin` | Control plane. Node.js + Next.js dashboard, REST API, database, policy, identity. Pushes config over WebSocket. |
| **Gerbil** | `fosrl/gerbil` | Node tunnel manager. Creates the WireGuard interface, manages peers over an HTTP API, relays client UDP, runs an SNI proxy. |
| **Newt** | `fosrl/newt` | Site connector on the private network. Userspace WireGuard tunnel plus TCP/UDP proxy. |
| **Traefik** | upstream | Ingress. Terminates TLS, routes HTTP(S) and protocol-aware resources. |
| **Badger** | `fosrl/badger` | Traefik forward-auth plugin. Enforces Pangolin sessions on public resources. |
| **Olm** | `fosrl/olm` | Shared client networking core. Tunnel logic, hole punching, relay negotiation, DNS overrides. |

The docs split this into a **control plane** (config, identity, orchestration) and a **data plane** (tunnels, ingress, relay). Both sites and clients dial **outbound** only.

### 2.2 Traffic flow

The docs give both paths verbatim ([system-architecture § Traffic Paths](https://docs.pangolin.net/development/system-architecture)):

**Inbound, public resources:**

```
Internet → Node ingress (Traefik) → Auth (Badger) → Tunnel (Gerbil) → Site connector (Newt) → Backend target
```

**Outbound, private resources via client:**

```
Client ↔ (direct peer or relay via Gerbil) ↔ Site connector (Newt) → Destination on remote network
```

### 2.3 What runs where

| Location | Processes |
|---|---|
| **Public VPS (node)** | Pangolin control plane, Gerbil, Traefik + Badger, database |
| **Home network (site)** | Newt only |
| **User devices** | Pangolin client (embeds or invokes Olm) |

Newt "opens a WebSocket to the control plane for configuration" and "a WireGuard tunnel to the node's tunnel manager (Gerbil)". Newt makes HTTP requests to Pangolin with a Newt ID and secret to get a session token, then holds the WebSocket ([newt README](https://github.com/fosrl/newt/blob/main/README.md)).

### 2.4 Client mode, site-to-site, relay vs direct

- **Client mode exists.** Clients are a first-class concept, separate from sites. Two classes share the Olm stack: user devices (GUI apps on macOS, Windows, Linux, iOS, Android) and machines (CLI, authenticate with ID and secret).
- **Peer-to-peer is real.** "By default, the control plane coordinates **NAT hole punching** so a client and site connector can form a direct WireGuard peer connection. Traffic then flows client ↔ site without passing through the node's relay layer."
- **Relay is the fallback.** "When hole punching fails (restrictive NAT, symmetric NAT, or blocked UDP), the client and site fall back to **relaying** through the node's tunnel manager (Gerbil)." Gerbil listens on UDP 21820. "The connection stays encrypted end to end; only the network path changes." Relay "can be disabled per client if you require direct paths only."
- **Site-to-site is not a peer mesh.** The peer-to-peer path is **client-to-site**. No doc page describes direct site-to-site peering. Traffic between two sites transits the node. Multi-site behavior is *routing*, not meshing: when several connectors can reach the same destination, Pangolin picks "the healthiest path based on latency and availability" ([pangolin-vs-reverse-proxy-vs-vpn](https://docs.pangolin.net/about/pangolin-vs-reverse-proxy-vs-vpn)).
- **No exit-node / egress feature.** No docs page describes routing all internet traffic through a site. The internal term "exit node" means a Pangolin relay node, not a Tailscale-style internet exit. It appears only in `remote-node/backhaul.mdx` and config-file pages.

---

## 3. Self-hosting requirements

### 3.1 VPS specs

From [choosing-a-vps](https://docs.pangolin.net/self-host/choosing-a-vps):

| Case | Specs |
|---|---|
| Minimum | 1 vCPU, 2 GB RAM, 8 GB SSD |
| Recommended | 2 vCPU, 2 GB RAM, 20 GB SSD |
| More users or sites | 4 vCPU, 4 GB RAM, 40 GB SSD |
| Large | 8 vCPU, 8 GB RAM, 80 GB SSD |

With 1 GB RAM the docs advise swap space. Load scales with site count and throughput.

### 3.2 Ports

From [dns-and-networking](https://docs.pangolin.net/self-host/dns-and-networking):

| Port | Purpose |
|---|---|
| TCP 80 | Let's Encrypt HTTP-01 validation, non-SSL resources. "Can be disabled with wildcard certs" |
| TCP 443 | Dashboard and all HTTPS resources |
| UDP 51820 | Site (Newt) tunnels to Gerbil |
| UDP 21820 | Client relay through Gerbil. "This port is only required for clients" |

The same page carries a warning that matters for a homelab threat model: "By tunneling out to the VPS, you are effectively including the VPS in your security boundary, so you must secure it as part of your overall network strategy."

### 3.3 DNS and certificates

- A wildcard A record `*` → VPS IP. This lets any subdomain resolve to the VPS.
- An optional apex `@` record, only to use the root domain as a resource.
- Certificates come from Let's Encrypt. HTTP-01 by default. Wildcard certs need DNS-01, and DNS-01 needs a DNS provider credential.

### 3.4 Internal subnets

Defaults are in CGNAT space to avoid RFC1918 collisions: `subnet_group: 100.89.137.0/20`, `block_size: 24`, `site_block_size: 30` (a /30, four IPs, per site). Organization defaults use `100.90.128.0/20` and `100.96.128.0/20`. **Change the subnet before you register the first Gerbil.** The docs mark this: "If this subnet conflicts with your network, change it in your config **before** registering your first Gerbil."

### 3.5 Database

Both are first-class ([database-options](https://docs.pangolin.net/self-host/advanced/database-options)):

- **SQLite** — default, no config, image `fosrl/pangolin:<version>`.
- **PostgreSQL** — separate image `fosrl/pangolin:postgresql-<version>`, set `postgres.connection_string` in `config.yml`.

### 3.6 Is Docker the only option?

**No, but Docker is the only path the vendor documents.** The vendor supports the `curl | bash` installer, Docker Compose, Podman Quadlets, Kubernetes (Helm, Kustomize, ArgoCD, Flux), and Unraid. All are container based. `how-to-update` states the model plainly: "Updating Pangolin is straightforward since it's a collection of Docker images."

**Raw binaries and systemd work, and nixpkgs proves it.** Pangolin builds to plain Node.js bundles: `npm run build` produces `dist/server.mjs` and `dist/migrations.mjs` via esbuild, plus a Next.js standalone output. Gerbil and Newt are static Go binaries. The nixpkgs `services.pangolin` module runs all of it as systemd units with no container. See § 4.

**Pangolin can also run with no tunneling at all.** [without-tunneling](https://docs.pangolin.net/self-host/advanced/without-tunneling) says you can omit Gerbil. Pangolin then acts as "a normal reverse proxy and authentication manager" with "Local" sites only. This makes a LAN-only deployment possible with no VPS.

### 3.7 Where state lives

Docker layout ([manual-install](https://docs.pangolin.net/self-host/manual/manual-install)):

```
config/config.yml            # main config, hand-written
config/db/db.sqlite          # database, created on first start
config/key                   # WireGuard private key, generated by Gerbil
config/traefik/traefik_config.yml
config/letsencrypt/          # ACME storage
```

On NixOS the module puts all of this under `services.pangolin.dataDir` (default `/var/lib/pangolin`), with `config/letsencrypt` owned by `traefik`.

---

## 4. NixOS packaging status

**Pangolin is packaged in nixpkgs, and a NixOS module exists.** This is the opposite of what a search for "pangolin nixos" a year ago would have shown.

### 4.1 Packages

| Attribute | nixpkgs unstable | nixpkgs 25.11 (stable) | Upstream latest |
|---|---|---|---|
| `fosrl-pangolin` | 1.16.2 (index) / 1.21.0 (master) | **1.10.3** | 1.21.1 |
| `fosrl-gerbil` | 1.3.1 | — | 1.4.3 |
| `fosrl-newt` | 1.10.4 | — | 1.15.0 |
| `fosrl-olm` | 1.4.4 | — | 1.8.2 |
| `pangolin-cli` | 0.3.3 | — | — |
| `badger` | not packaged | not packaged | v1.5.0 |

Badger is absent by design. It is a Traefik Yaegi plugin, loaded from source at Traefik startup, not a binary.

Version numbers come from `mcp-nixos` against the live search index and from the package source. The unstable index reported 1.16.2 while `pkgs/by-name/fo/fosrl-pangolin/package.nix` on master declares `version = "1.21.0"`. Treat the index number as stale, not the source.

### 4.2 NixOS module

`nixos/modules/services/networking/pangolin.nix` — 583 lines, maintainers `jackr` and `water-sucks`. There is also a VM test at `nixos/tests/pangolin.nix`, wired in through `passthru.tests`.

Options:

- `services.pangolin.{enable,package,settings,dataDir,baseDomain,dashboardDomain,letsEncryptEmail,dnsProvider,openFirewall,environmentFile}`
- `services.gerbil.environmentFile`
- `services.newt.{enable,package,settings,blueprint,environmentFile}`

What the module does for you:

- Creates `pangolin` and `gerbil` system users in a shared `fossorial` group, with `traefik` as a member.
- Orders the units `pangolin.service` → `gerbil.service` → `traefik.service`, with `upholds`/`partOf` so a Gerbil restart restarts Traefik.
- Enables `services.traefik` and generates the whole static and dynamic config: the HTTP provider that polls `/api/v1/traefik-config`, the ACME resolver (HTTP-01, or DNS-01 when `prefer_wildcard_cert` is set), entry points, and the Next.js / API / WebSocket / integration-API routers.
- Registers the Badger plugin under `experimental.plugins`.
- Sets `systemd.tmpfiles` ownership for `dataDir`, `dataDir/config`, and `dataDir/config/letsencrypt`.
- Asserts that `dnsProvider` and a Traefik environment file are present when you ask for wildcard certs.
- `services.newt.blueprint` accepts declarative site config as YAML.

The package supports overrides for `databaseType` (`sqlite` or `pg`) and `edition` (`oss`, `enterprise`, `saas`). For `oss` it runs `postUnpack: rm -rf server/private`, and `meta.license` becomes `[agpl3Only] ++ optional (edition != "oss") unfree`.

### 4.3 Known rough edges in the Nix path

These are recorded in the module source itself. Read them before you commit.

1. **The Badger version is pinned to `v1.2.0`** in `services.traefik.staticConfigOptions.experimental.plugins.badger`. Upstream is `v1.5.0`, and Pangolin 1.19 release notes state that browser SSH "requires the Badger Traefik plugin to be on the latest version `v1.4.1`". A stale pin will break protocol-aware resources.
2. **Traefik fetches the plugin at runtime.** `experimental.plugins` makes Traefik pull Badger from GitHub on startup. That is impure and needs egress. The module carries `# TODO to change this once #437073 is merged.`
3. **A `wg0` workaround script exists.** `gerbil-wg0-fix-script` loops `ip l d wg0` until it succeeds, then restarts Gerbil. The comment links [newt#37](https://github.com/fosrl/newt/issues/37) and adds "will not work if the interface is renamed".
4. **`server.internal_hostname` must be `localhost`,** "otherwise this fails silently" (same issue).
5. **Tunnels are not declarative.** The module carries `### TODO: make tunnels declarative by calling API`.
6. **Stable 25.11 ships 1.10.3.** That version is inside the range affected by CVE-2026-3209 (see § 9). Use unstable or an overlay.

### 4.4 If you package it yourself

Newt already ships its own `flake.nix` with `packages.pangolin-newt`. It uses `buildGoModule`, a pinned `vendorHash`, `CGO_ENABLED = 0`, `doCheck = false` (upstream tests need network), and `versionCheckHook` instead. `lib.maintainers.water-sucks` is listed in that flake and in nixpkgs, so the upstream flake and the nixpkgs package share a maintainer.

Effort per component, if you had to start over:

- **Gerbil, Newt, Olm** — plain `buildGoModule`. Single `go.mod`, no cgo, no embedded assets. Low effort. Newt needs `NET_ADMIN` at runtime, or userspace mode.
- **Pangolin** — `buildNpmPackage`. Harder: a Next.js build, `esbuild` bundling, a Drizzle `db:generate` step, and three build variants selected by shell scripts that rewrite `server/build.ts` and copy a `tsconfig`. The nixpkgs package also patches `server/lib/consts.ts` because "upstream inconsistently updates this", and wraps the binary with a runtime shim that symlinks `node_modules`, copies `.next`, seeds a default `config.yml`, and runs migrations.
- **Badger** — cannot be a normal package. It is Yaegi-interpreted Traefik plugin source.

### 4.5 Community flakes

Newt's own repo flake is the one first-party flake. No NUR entry was found. nixpkgs is the better path now.

---

## 5. Auth and identity

### 5.1 Model

Server → organizations → users, roles, machines → resources. Deny by default. "By default, no resources are made available on sites. Admins must define resources with backend targets, and assign specific access policies before any users can gain access" ([understanding-resources](https://docs.pangolin.net/manage/resources/understanding-resources)).

Access is granted to **roles**, **users**, or **machines**. Machines cannot be put into roles ([private/authentication](https://docs.pangolin.net/manage/resources/private/authentication)).

### 5.2 Resource-level auth on public HTTP resources

From [public/authentication](https://docs.pangolin.net/manage/resources/public/authentication). All public resources get Pangolin SSO by default. Extra methods:

| Method | Detail |
|---|---|
| Pangolin (Platform) SSO | Built-in accounts |
| External IdP | Google, Azure, Okta, any OIDC |
| Users and roles | Per-resource grants |
| PIN and passcode | Numeric PIN or passcode prompt |
| Header auth | HTTP Basic. `Authorization: Basic …` or `user:pass@host`. "Extended Compatibility" forces a 401 so the browser prompts |
| Shareable links / access tokens | Self-destructing links with expiry; tokens by query param or header |
| Email OTP | Whitelist emails or wildcards such as `*@.example.com`, then one-time code by email |
| Rules | Ranked allow/deny by IP, geolocation, URL path |

Resource policies let you share one rule set across many resources.

### 5.3 Does the middleware protect arbitrary HTTP resources?

Yes. Badger is a Traefik forward-auth plugin. Any HTTP resource routed through Traefik can carry it. Badger's README states it "acts as an authentication bouncer, ensuring only authenticated and authorized requests are allowed through the proxy" and that it "is **required** to be installed alongside Pangolin". It also has a standalone mode: set `disableForwardAuth: true` to get only client-IP handling with no Pangolin auth.

### 5.4 Can raw TCP/UDP be authenticated?

**No.** This is explicit. Public TCP and UDP resources "do not receive a FQDN. Instead, they bind to a port on the Pangolin server host and act as simple protocol-agnostic pipes to the downstream resource. Because they are not protocol-aware, they do not enforce Pangolin authentication or access rules" ([understanding-resources](https://docs.pangolin.net/manage/resources/understanding-resources)).

The documented workaround is to use a client instead: "For raw TCP/UDP traffic that does not need a public proxy, prefer a private host or CIDR resource over public TCP/UDP resources." Private resources always require an authenticated client.

### 5.5 SSO tier gating

This is the sharpest CE/EE line. From [add-an-idp](https://docs.pangolin.net/manage/identity-providers/add-an-idp):

| Feature | Tier |
|---|---|
| **Generic OAuth2 / OIDC** (Authentik, Keycloak, Okta, Pocket ID, Zitadel) | Works in CE, as a **global** IdP |
| **Global IdPs** | "Global identity providers are the only supported method in Pangolin Community" |
| **Organization-scoped IdPs** | Cloud or EE only. EE also needs `app.identity_provider_mode: "org"` in `privateConfig.yml` |
| **Google IdP** (native) | Cloud or EE only |
| **Azure Entra ID** (native) | Cloud or EE only |
| **More than one role per user** | Cloud or EE only |

For a single-person homelab, generic OIDC on CE is enough. Pocket ID and Authentik both work through the OIDC path.

---

## 6. Comparison

### 6.1 Matrix

| | **Pangolin** | **Tailscale** | **Headscale** | **Cloudflare Tunnel** | **Caddy/nginx + WireGuard** |
|---|---|---|---|---|---|
| Who terminates TLS | Your VPS (Traefik) | No TLS layer; app-level | Same as Tailscale | **Cloudflare** | Your box |
| Who sees plaintext | **You** (your VPS) | Only endpoints | Only endpoints | **Cloudflare** | You |
| Public VPS required | **Yes**, for public ingress. No, for LAN-only mode | No | Yes, for the control server | No | Yes, for ingress |
| Public visitor ingress | **Yes** — core feature | No | No | Yes | Yes |
| Private mesh access | Client-to-site only, no peer mesh | **Yes**, full mesh | **Yes**, full mesh | Limited (WARP) | Manual |
| Exit node / egress | **No** | **Yes** | **Yes** | WARP only | Manual `AllowedIPs` |
| NAT traversal | Hole punch, relay via Gerbil | DERP + hole punch | DERP + hole punch | Outbound only | **None** — you port-forward |
| Cost | VPS + free EE license | Free ≤3 users, then per-user | VPS only | Free tier | VPS only |
| Ops burden | **High** — 4 processes, DB, certs, DNS | Very low | Medium | Very low | Medium |
| Lock-in | AGPL core; EE needs a vendor-issued key | Full vendor | None | **Full vendor** | None |

### 6.2 Is the "ingress, not a mesh VPN" claim true?

**Partly true, and the claim needs updating.** The vendor now markets both halves, and the code backs it up.

*Refuted:* Pangolin does have real VPN capability. Private resources "function like a zero-trust virtual private network (VPN)". Clients install routes for host, CIDR, FQDN, and alias destinations. Client-to-site hole punching gives direct WireGuard peering. Private HTTPS terminates TLS at the site edge, so the app never touches the public internet.

*Confirmed:* it is **not a mesh**. Tailscale gives you an n-to-n peer graph where any node reaches any node. Pangolin gives a hub-and-spoke graph: clients reach *resources* on *sites*, and only what an admin granted. The docs are explicit that this is deliberate: "Grant users access to specific resources, not entire networks. Unlike traditional VPNs that expose full network access…" (README). There is no site-to-site peering and no exit node.

**Practical reading.** Pangolin replaces Cloudflare Tunnel and a hand-rolled Traefik + authentication stack. It does not replace Tailscale for:

- device-to-device access between two of your own machines with no site connector,
- using home as an internet exit node on untrusted Wi-Fi,
- flat "everything reaches everything" admin access.

Pangolin's own guidance agrees. Use a traditional VPN "if you need broad network access" ([pangolin-vs-reverse-proxy-vs-vpn](https://docs.pangolin.net/about/pangolin-vs-reverse-proxy-vs-vpn)).

### 6.3 The one advantage that matters most here

Cloudflare Tunnel terminates TLS at Cloudflare. Cloudflare sees plaintext for every proxied request. Pangolin moves that trust to a VPS you rent. That is the strongest reason to pick Pangolin over Cloudflare Tunnel. The cost is that you now own the VPS, and the docs warn the VPS joins your security boundary.

---

## 7. Licensing

### 7.1 Per-repo license

| Repo | License | Evidence |
|---|---|---|
| `fosrl/pangolin` | **Dual: AGPL-3.0 + Fossorial Commercial License**, per file | `LICENSE` |
| `fosrl/gerbil` | AGPL-3.0 (`LICENSE` is plain AGPL-3); README says "dual licensed under the AGPLv3 and the Fossorial Commercial license" | `LICENSE`, README |
| `fosrl/newt` | Same as Gerbil | `LICENSE`, README |
| `fosrl/olm` | Same as Gerbil | `LICENSE`, README |
| `fosrl/badger` | **MIT** | `LICENSE` |
| `fosrl/docs-v2` | MIT | GitHub API |
| `fosrl/helm-charts`, `fosrl/blueprints` | MIT | GitHub API |
| `fosrl/cli`, `apple`, `windows`, `android` | `NOASSERTION` — GitHub cannot classify them | GitHub API |

### 7.2 The Pangolin LICENSE is per-file, not per-repo

The `LICENSE` file sets three rules:

1. Files with a "Fossorial Commercial License" header are commercial. "Unauthorized use, copying, modification, or distribution is strictly prohibited."
2. Files with an AGPL-3 header are AGPL-3, and are also available commercially under a written agreement.
3. "All files without a license header are, by default, licensed under the GNU Affero General Public License, Version 3 (AGPL-3)."

**Nothing is BSL.** There is no Business Source License and no time-delayed conversion. The model is dual-license AGPL plus a commercial license, in the style of GitLab EE.

### 7.3 Where the proprietary code lives

A GitHub code search for `"Fossorial Commercial License"` in `fosrl/pangolin` returns **223 files**. Nearly all sit under `server/private/`. That directory holds `license/`, `lib/stripe.ts`, `lib/billing/`, `lib/logStreaming/`, `lib/exitNodes/`, `routers/orgIdp/`, `routers/auditLogs/`, `routers/alertRule/`, `routers/loginPage/`, `routers/ssh/`, and more.

Both build paths delete it for the open build:

- `Dockerfile`: `RUN if [ "$BUILD" = "oss" ]; then rm -rf server/private; fi`
- nixpkgs: `postUnpack = lib.optionalString (edition == "oss") "rm -rf server/private"`

So the AGPL CE tree is genuinely free of the proprietary code. The tradeoff is that CE is a **subset build**, not the full product with flags off.

### 7.4 What the paid license gates

Enterprise Edition is a separate image, `fosrl/pangolin:ee-latest`, plus a key activated at `/admin/license` ([enterprise-edition](https://docs.pangolin.net/self-host/enterprise-edition)).

Cost rule: **free** for personal use and organizations under **$100,000 USD** gross annual revenue, but "You still need to apply for a valid license key". At $100,000+ a paid license is required. Keys are one per server, where "A server is considered to be a single database instance."

Paid tiers, from [pangolin.net/pricing](https://pangolin.net/pricing):

| Tier | Price | Adds |
|---|---|---|
| Basic | Free | Web proxy resources, private resources and clients, peer-to-peer, 2FA |
| Team | $4/user/mo | External IdPs, multiple roles per user (RBAC), audit logging, device posture, security policy enforcement |
| Business | $9/user/mo | Multiple organizations, IdP auto-provisioning, SSH management, device approvals, custom branding |
| Enterprise | Custom | Custom limits, SIEM log streaming, SCIM, premium relay nodes, SLA |

Log retention also scales by tier: 3 / 30 / 90 days / custom.

### 7.5 What happens when free-tier limits are hit

**This is the most decision-relevant finding, and it contradicts the pricing page.**

The pricing page shows a limits table: 5 users, 5 sites, 5 domains, 1 organization, 15 public resources, 15 private resources, 5 machine clients on the free tier. `server/lib/billing/limitSet.ts` matches those numbers exactly in `freeLimitSet`, and adds a `tier1LimitSet` labeled "Home limit" (7 users, 10 sites, 30 resources) with display name "Home Lab".

But the enforcement middleware short-circuits. `server/middlewares/verifyLimits.ts`:

```ts
export async function verifyLimits(req, res, next) {
    if (build != "saas") {
        return next();
    }
    ...
}
```

`build` is set at compile time to `oss`, `enterprise`, or `saas` (`package.json` scripts `set:oss`, `set:enterprise`, `set:saas`). **A self-hosted CE or EE build is never `saas`. Those limits therefore never apply to a self-hosted instance.** The pricing table describes Pangolin Cloud.

Consequences for a self-hosted install:

- Site count, user count, resource count, and machine-client count are **not capped**.
- SSO is not capped by count, but is capped by *kind*: generic OIDC works on CE; org-scoped IdPs, native Google, native Azure, and multiple roles per user need EE.
- License expiry does not brick anything. "If your license expires or becomes invalid: Enterprise features will be disabled. You can renew your license to restore Enterprise features."
- CE ↔ EE is a container swap. "Community and Enterprise Edition share the same database schema, so there should be no data migration issues."
- CE can hide the locked EE UI with `flags.disable_enterprise_features: true`.

Verify this yourself before you rely on it. It is read from source, not from a vendor statement, and upstream can change it in any release.

---

## 8. Migration considerations

### 8.1 Order of operations

Conditions come first in each step.

1. Provision the VPS. Apply 2 vCPU / 2 GB / 20 GB.
2. **Choose the internal subnet before the first start.** If `100.89.137.0/20` collides with your LAN, change `gerbil.subnet_group` now. Changing it after Gerbil registers is not supported.
3. Add the wildcard DNS record `*` → VPS IP. Keep TTL at 300 during the cutover.
4. Open TCP 80, TCP 443, UDP 51820, and UDP 21820. Close everything else.
5. Install Pangolin. Set a strong `server.secret` of at least 32 characters.
6. Read the setup token from the Pangolin logs. Create the admin account at `/auth/initial-setup`.
7. Deploy Newt on the home network. Give it the Newt ID and secret.
8. Define resources one at a time. Test each on a spare hostname before you move the real one.
9. Cut real hostnames over last, one at a time.

### 8.2 Certificates

Let's Encrypt, driven by Traefik. HTTP-01 needs TCP 80 reachable. Wildcard certs need DNS-01 plus a DNS provider credential. On NixOS the module asserts both `dnsProvider` and a Traefik environment file when `prefer_wildcard_cert` is set. Expect a delay on first issue: "It might take a few minutes for the first cert to validate, so don't worry if the browser throws an insecure warning."

### 8.3 Rollback

Rollback is DNS plus a config restore. Keep the old reverse proxy running until every hostname is verified. Then point DNS back if you need to retreat.

Downgrade is the weak point. Every release note repeats: "Always back up your config app-data before updating… **You will not be able to easily downgrade otherwise.**" Migrations run forward automatically and are not reversible. Snapshot `config/` (or `dataDir` on NixOS) before every upgrade.

### 8.4 What breaks first

Ranked by observed issue traffic and doc warnings:

1. **Subnet collision** with `100.89.137.0/20`, unfixable after first registration.
2. **Certificate issuance**, if TCP 80 is blocked or wildcard DNS is wrong.
3. **Badger version skew.** Protocol-aware resources need a matching plugin version. See § 4.3.
4. **Path-based routing and cookies.** Open issues [#2294](https://github.com/fosrl/pangolin/issues/2294) "Path-Based-Routing is broken" and [#2238](https://github.com/fosrl/pangolin/issues/2238) "Redirect loop on resource root path / + cookie explosion".
5. **OIDC edge cases.** [#737](https://github.com/fosrl/pangolin/issues/737), [#762](https://github.com/fosrl/pangolin/issues/762), [#2301](https://github.com/fosrl/pangolin/issues/2301) (Safari drops `p_oidc_state`), and [#668](https://github.com/fosrl/pangolin/issues/668) — an IdP reachable only *through* Pangolin creates a bootstrap loop. That last one matters if you plan to host Authentik or Pocket ID behind Pangolin.
6. **No BYO certificates.** [#3243](https://github.com/fosrl/pangolin/issues/3243) asks for a file provider so you can supply your own certs instead of ACME. Still open.

### 8.5 Upgrade story

- Release cadence is fast. 1.21.1 shipped 2026-07-30. Roughly one minor per month through 2026, with patch releases in between.
- No `CHANGELOG` file. Release notes on GitHub Releases are the record.
- Still on `1.x`. No major-version break has happened, so there is no 1→2 migration precedent.
- Breaking changes arrive inside minors. 1.19.x is the clearest case: private SSH resources changed shape ("you will now need to switch these to SSH resources"), Badger had to reach `v1.4.1`, and Newt had to reach `1.13.0`.
- **Upgrades are multi-component.** Pangolin, Gerbil, Traefik, Badger, Newt, and every client can each need a version bump. Newt and clients live outside the VPS, so an upgrade is not atomic. 1.21's same-network detection "requires updated clients and sites".
- Docs advise stepping through minors: "update from 1.0.0 → 1.1.0 → 1.2.0 instead of jumping directly".
- On NixOS a channel bump moves Pangolin, Gerbil, and Newt at once, but **not** the Badger plugin version pinned in the module, and not clients on other machines.

### 8.6 Ongoing burden

Monthly: read release notes for cross-component version requirements, back up `dataDir`, upgrade, verify certs renewed, verify sites reconnected. Plus normal VPS patching. This is materially more work than Cloudflare Tunnel or Tailscale, which self-update.

---

## 9. Risks and red flags

### 9.1 Maturity and momentum

Positive signals:

- 22,080 stars on `fosrl/pangolin`, 1,086 closed issues against 73 open.
- Commits within the last day across `pangolin`, `gerbil`, `newt`, `olm`, `cli`, and `pangolin-node`.
- The company is hiring. `docs-v2` contains `careers/software-engineer-full-stack.mdx` and `careers/software-engineer-go.mdx`.
- Outside contributors appear in most releases.

### 9.2 Single-vendor risk — the main strategic concern

- One company owns every repo. No foundation, no independent governance.
- The revenue model depends on Cloud plus EE licenses. `server/private/lib/stripe.ts` and `lib/billing/` are in-tree.
- **Features have moved across the CE/EE line.** 1.20.0 notes "Release EE feature gate on labels feature" — that one moved toward CE. Movement in either direction is possible, and the vendor controls which files carry which header.
- The product scope keeps widening: browser RDP/VNC/SSH, device posture, SCIM, PAM, clustering, Kubernetes controllers, five client platforms. Broad scope on a young codebase raises the defect surface.
- Rebranding happened once already (`digpangolin.com` → `pangolin.net`, `fosrl/docs` → `docs-v2`). Expect churn in links and names.

### 9.3 Security posture

**No public audit.** No third-party security audit was found in any repo or docs page.

**A thin disclosure policy.** `SECURITY.md` gives an email and "We aim to address the issue as soon as possible." No stated response time, no supported-version policy, no PGP key.

**No published GitHub Security Advisories.** `repos/fosrl/pangolin/security-advisories` returns empty. Fixes ship inside normal release notes as "Security updates". This means you cannot subscribe to advisories to learn about a vulnerability. You must read every release note.

**Two CVEs exist.** Both confirmed against NVD:

| CVE | Published | Severity | Detail |
|---|---|---|---|
| [CVE-2025-56332](https://nvd.nist.gov/vuln/detail/CVE-2025-56332) | 2025-12-30 | **CVSS 3.1 = 9.1 CRITICAL** | "Authentication Bypass in fosrl/pangolin v1.6.2 and before allows attackers to access Pangolin resource via Insecure Default Configuration" |
| [CVE-2026-3209](https://nvd.nist.gov/vuln/detail/CVE-2026-3209) | 2026-02-25 | CVSS 2.0 = 6.5 | Improper access control in `verifyRoleAccess` / `verifyApiKeyRoleAccess`. Affects up to 1.15.4-s.3, fixed in 1.15.4-s.4. "The exploit has been disclosed to the public and may be used." |

A **critical authentication bypass caused by an insecure default** is the worst possible class of bug for this product. Authentication is the entire value proposition. Both CVEs are fixed in current versions, but they set the base rate.

**Direct NixOS consequence:** nixpkgs **25.11 ships 1.10.3**, which is inside the range affected by CVE-2026-3209. Do not deploy Pangolin from stable nixpkgs. Use unstable, or pin the package through an overlay.

### 9.4 Operational red flags in the code and issues

- **CE and EE images behave differently.** [#2967](https://github.com/fosrl/pangolin/issues/2967) (66 comments, open since 2026-05-02): "ee-latest (v1.18.1) causes CPU spike after ~60s — CE latest (v1.18.1) works fine". The most-discussed open issue is an EE-only regression.
- **Data-plane silent failure.** [#3096](https://github.com/fosrl/pangolin/issues/3096): "Newt site stays online but WireGuard data plane stops carrying traffic". A tunnel that reports healthy while dropping traffic is hard to alert on.
- **Silent misconfiguration.** The nixpkgs module comment records that a wrong `internal_hostname` makes Pangolin "fail silently".
- **Telemetry defaults on.** `app.telemetry.anonymous_usage` defaults to `true`. Set it to `false` if you object.
- **`curl | bash` install.** The documented quick install is `curl -fsSL https://static.pangolin.net/get-installer.sh | bash`. Irrelevant on NixOS, but it signals the vendor's security posture.
- **Third-party binary dependencies.** `package.json` pulls `@devolutions/iron-remote-desktop` from `https://static.pangolin.net/packages/…tgz`, not from a registry. Vendor-hosted tarballs are harder to audit and to pin.

### 9.5 If Fossorial stops or changes the license

- **The AGPL grant is irrevocable for released versions.** The CE tree, Gerbil, Newt, and Olm can be forked. Badger is MIT and can be forked freely.
- **Forking is viable but not cheap.** The stack is Node.js + Next.js + Drizzle + three Go services + a Traefik plugin + five client apps. A community fork would need real staffing.
- **A license change would only affect future versions.** The realistic bad outcome is that new features land only in `server/private`, and CE slowly becomes a demo of the paid product. The `oss` build already deletes 223 files.
- **You cannot fork EE.** If you build a workflow on org-scoped IdPs, SIEM streaming, or audit logs, you are on the commercial license, and only a written agreement with Fossorial keeps it.
- **Data is portable.** SQLite or Postgres, with a documented schema through Drizzle migrations. Resources are also expressible as Blueprints (declarative YAML). Exit is a real option.

---

## 10. Summary judgment

**Choose Pangolin if** you want authenticated public ingress for services at home, you refuse to let Cloudflare see plaintext, and you accept renting and hardening a VPS.

**Do not choose Pangolin if** you want a peer mesh between your own machines, an exit node for untrusted Wi-Fi, or low operational burden. Tailscale or Headscale fit those cases, and the vendor's own comparison page agrees.

**They are complementary, not exclusive.** Pangolin handles public ingress. A mesh VPN handles device-to-device and egress. Running both is a defensible design.

**If you proceed on NixOS:**

1. Use `services.pangolin` from **nixpkgs unstable**, never stable 25.11 (CVE-2026-3209).
2. Override the Badger plugin version away from the module default `v1.2.0`.
3. Change `gerbil.subnet_group` before the first start if `100.89.137.0/20` collides.
4. Set `app.telemetry.anonymous_usage = false`.
5. Snapshot `dataDir` before every upgrade. Downgrade is not supported.
6. Read every release note for Newt, Badger, and client version requirements.
7. Apply for the free EE license only if you need org-scoped IdPs or audit logs. Generic OIDC works on CE.

---

## Sources

All facts above trace to these primary sources, read on 2026-08-08.

**Repositories** (`https://github.com/fosrl/<repo>`): `pangolin` (README, LICENSE, SECURITY.md, Dockerfile, package.json, `server/lib/billing/limitSet.ts`, `server/lib/billing/features.ts`, `server/middlewares/verifyLimits.ts`, `server/private/`, GitHub Releases), `gerbil` (README, LICENSE), `newt` (README, LICENSE, go.mod, flake.nix), `olm` (README, LICENSE), `badger` (README, LICENSE), `docs-v2` (LICENSE, page sources).

**Documentation** (`https://docs.pangolin.net`): `about/how-pangolin-works`, `about/pangolin-vs-reverse-proxy-vs-vpn`, `development/system-architecture`, `self-host/quick-install`, `self-host/choosing-a-vps`, `self-host/dns-and-networking`, `self-host/enterprise-edition`, `self-host/how-to-update`, `self-host/manual/manual-install`, `self-host/advanced/config-file`, `self-host/advanced/database-options`, `self-host/advanced/without-tunneling`, `manage/sites/understanding-sites`, `manage/resources/understanding-resources`, `manage/resources/public/authentication`, `manage/resources/private/authentication`, `manage/identity-providers/add-an-idp`.

**Pricing:** `https://pangolin.net/pricing`, `https://pangolin.net/fcl`.

**nixpkgs:** `nixos/modules/services/networking/pangolin.nix`, `nixos/tests/pangolin.nix`, `pkgs/by-name/fo/fosrl-pangolin/package.nix`, `pkgs/by-name/pa/pangolin-cli/package.nix`. Version data from the live search.nixos.org index via `mcp-nixos`.

**Vulnerabilities:** NVD `CVE-2025-56332`, `CVE-2026-3209`.

**Upstream:** `https://www.wireguard.com/`, `https://doc.traefik.io/traefik/https/acme/`.
