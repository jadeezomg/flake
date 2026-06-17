# mini — Matrix + Hermes + Caddy: execution TODO

Everything below is **runtime / one-time** work. The Nix config is written and
evaluates; these are the steps you run on the `mini` host to bring it live.

Relevant files:
- `hosts/mini/services/caddy.nix` — Caddy reverse proxy (own tailnet node `mini-proxy`)
- `hosts/mini/services/matrix.nix` — continuwuity homeserver
- `hosts/mini/services/hermes.nix` — Hermes agent + Matrix bot
- `hosts/mini/services/llm/open-webui.nix`, `services/beszel.nix` — moved onto Caddy

Subdomains (all on the `jadee.fyi` Cloudflare zone, all → the `mini-proxy` node):
`matrix.jadee.fyi`, `chat.jadee.fyi` (open-webui), `beszel.jadee.fyi`.

---

## 0. Secrets — DONE ✅

Already present in `secrets/secrets.yaml`:
- `cloudflare_dns_api_token` (top-level)
- `tailscale_authkey` (top-level)
- `matrix/registration_token`
- `matrix/hermes_password`

> The Tailscale auth key must be **reusable + non-ephemeral** so the `mini-proxy`
> node survives restarts. If it was a one-shot/ephemeral key, regenerate and
> re-run `sops secrets/secrets.yaml`.

---

## 1. Deploy

```
git add -A          # flakes only see tracked files
# on mini:
flake switch
```

First switch builds two **uncached** packages locally (a few minutes):
- the plugin Caddy (`caddy-tailscale` + `caddy-dns/cloudflare`)
- the Matrix-augmented Hermes (`mautrix[encryption]`)

After it completes, sanity-check the units:
```
systemctl status caddy continuwuity hermes-agent
journalctl -u caddy -b --no-pager | tail -40
```

---

## 2. Cloudflare DNS records

The `mini-proxy` Caddy node registers on first boot and gets a tailnet IP. Find it:
```
tailscale status | grep mini-proxy        # note the 100.x.y.z address
```

In the Cloudflare dashboard (`jadee.fyi` zone), create **three A records**, all
pointing at that one IP, **Proxy status = DNS only (grey cloud)**:

| Type | Name   | Content        | Proxy |
|------|--------|----------------|-------|
| A    | matrix | `100.x.y.z`    | OFF   |
| A    | chat   | `100.x.y.z`    | OFF   |
| A    | beszel | `100.x.y.z`    | OFF   |

> Proxy MUST be off — Cloudflare can't reach a private tailnet IP. The public
> record only resolves the name; routing stays tailnet-only.

Caddy gets each cert via the **DNS-01** challenge (independent of these A records,
so cert issuance can happen before/while you add them). Watch it obtain certs:
```
journalctl -u caddy -f | grep -i certificate
```

---

## 3. Retire the old tailscale-serve config

The removed `tailscale serve` units left mappings in `tailscaled` state that still
answer on `mini.quokka-qilin.ts.net`. Clear them once:
```
# on mini:
sudo tailscale serve reset
tailscale serve status      # should be empty
```

---

## 4. Verify the proxied services

From any tailnet client:
- `https://chat.jadee.fyi`   → open-webui
- `https://beszel.jadee.fyi` → beszel hub (re-do beszel onboarding if the URL/cookie changed)
- `https://matrix.jadee.fyi/_matrix/client/versions` → JSON from continuwuity

---

## 5. Matrix accounts (continuwuity has no CLI user creation)

Register against loopback using the registration token. Use the **same password
value** you stored in `matrix/hermes_password` for the bot.

```
TOKEN=$(sudo cat /run/secrets/matrix_registration_token)

# Hermes bot:
curl -s http://127.0.0.1:6167/_matrix/client/v3/register \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"hermes\",\"password\":\"<matrix/hermes_password value>\",
       \"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$TOKEN\"},
       \"inhibit_login\":true}"

# Your own account (pick your own username/password), same shape — or use
# Element's "Create account" against matrix.jadee.fyi.
```

Restart Hermes so it logs in as the bot now that the account exists:
```
sudo systemctl restart hermes-agent
journalctl -u hermes-agent -b --no-pager | grep -i matrix | tail -20
```

---

## 6. Connect a client

1. Element → Sign in → Edit homeserver → `matrix.jadee.fyi` (auto-discovery works).
2. Sign in with the account from step 5.
3. Start a DM with `@hermes:matrix.jadee.fyi`. It auto-joins on invite; in rooms
   it only responds when `@`-mentioned (default).

---

## 7. (Optional) follow-ups

- **Home room for cron/notifications:** copy a room id (Element → Room settings →
  Advanced → Internal room ID, `!xxxx:matrix.jadee.fyi`) into `MATRIX_HOME_ROOM`
  in `hermes.nix`, then `flake switch`.
- **Apex IDs** (`@you:jadee.fyi` instead of `@you:matrix.jadee.fyi`): needs a
  well-known delegation vhost for `jadee.fyi` — ask to wire it.
- **honcho** (currently disabled): when re-enabled, give it a `honcho.jadee.fyi`
  vhost using the same `import tsnet` pattern instead of its own serve port.
- **Verify Hermes tools:** confirm `kagi`, `ctx7`, GitHub (`agent_pat`), and HF
  access work from a Hermes session.
