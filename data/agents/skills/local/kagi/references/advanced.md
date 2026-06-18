# Kagi CLI — Advanced Usage

Read this when the basic command set in `SKILL.md` isn't enough. The in-CLI `kagi agent` / `kagi skills get kagi` guide is always version-matched — consult it when a flag here looks stale.

## Credentials available here

Provisioned into `~/.kagi.toml` by the flake (`secrets/SCHEMA.md`):

| Credential | Status | Unlocks |
| --- | --- | --- |
| `KAGI_SESSION_TOKEN` | configured | subscriber search path, session-only search filters, `quick`, `assistant`, `ask-page`, `translate`, `summarize --subscriber` |
| `KAGI_API_KEY` | configured | `/api/v1` Search API (`--region`, `--from-date`, `--to-date`) and `extract` |
| `KAGI_API_TOKEN` (legacy) | **not configured** | would unlock `fastgpt`, `enrich web`/`enrich news`, and the legacy public-API `summarize` mode — **omitted below** |

`--profile NAME` selects `[profiles.NAME.auth]`. Base `search` prefers the session path when both creds are present, unless config sets `preferred_auth = "api"`.

## Search — flag set

```bash
kagi search "query" --format toon --limit 5
kagi search "query" --snap reddit --format toon
kagi search "query" --region us --from-date 2026-01-01 --format json
```

| Flag | Purpose |
| --- | --- |
| `--limit N` | cap returned results |
| `--snap NAME` | prefix query with a Kagi Snap shortcut (`reddit` → `@reddit QUERY`) |
| `--lens INDEX` | scope to a Kagi lens by numeric index — session path |
| `--region CODE` | region-bias (`us`, `gb`, …) — V1 API path |
| `--from-date` / `--to-date` | date filters — V1 API path |
| `--time day\|week\|month\|year` | recent window — session path |
| `--order default\|recency\|website\|trackers` | result ordering — session path |
| `--verbatim` | verbatim search mode — session path |
| `--personalized` / `--no-personalized` | force personalization — session path |
| `--news` | search the Kagi News vertical — session path |
| `--follow N` | search, then summarize the top N result pages |
| `--local-cache` | reuse a cached response (only when stale data is OK) |

`--lens`, `--time`, `--order`, `--verbatim`, and personalization require the session token.

```bash
# Search + synthesized coverage of the top pages
kagi search "what changed in the rust 2024 edition" --follow 3 --format markdown
```

## Readable page extraction

Use `extract` for full readable page content as markdown (requires `KAGI_API_KEY`). Prefer it over scraping rendered browser text when exact article content is the goal.

```bash
kagi extract "https://example.com/article"
kagi extract "https://example.com/article" --format json   # full envelope incl. link metadata
```

## Summarize (subscriber)

```bash
kagi summarize --subscriber --url "https://example.com/article"
kagi summarize --subscriber --url "https://example.com/article" --summary-type keypoints   # summary|keypoints|eli5
kagi summarize --subscriber --url "https://example.com/article" --length overview            # headline|overview|digest|medium|long
kagi summarize --subscriber --text "long text..." --target-language EN

# Summarize many URLs/items from stdin, one per line
printf 'https://a.com\nhttps://b.com\n' | kagi summarize --subscriber --filter
```

The legacy public-API mode (`kagi summarize --url ... --engine cecil`) needs `KAGI_API_TOKEN`, which isn't configured here — use `extract` or `--subscriber` instead.

## Assistant — conversational & threaded

```bash
kagi assistant "explain this release note" --format markdown
kagi assistant --stream --stream-output json "draft a migration checklist"   # stream-output: text|json
kagi assistant --thread-id THREAD_ID "continue from the previous answer"
kagi assistant --attach ./notes.md "summarize the attached notes"            # repeat --attach for more files
kagi assistant --assistant research "summarize the latest rust release"      # use a saved assistant

# Thread management
kagi assistant thread list
kagi assistant thread get THREAD_ID
kagi assistant thread export THREAD_ID --format markdown
kagi assistant thread delete THREAD_ID

# Custom assistants
kagi assistant custom list
kagi assistant custom get "Researcher"
kagi assistant custom create "CLI Researcher" --web-access --model gpt-5-mini
kagi assistant models   # list available base-model slugs
kagi assistant repl     # interactive REPL with thread continuity
```

## Ask a page

```bash
kagi ask-page "https://example.com/article" "what are the main claims?" --format markdown
```

## Batch & watch

```bash
kagi batch "rust" "zig" "go" --format toon --limit 3
printf 'rust\nzig\ngo\n' | kagi batch --format compact
kagi watch "site:example.com release notes" --interval 300   # emit result diffs over time
```

## News & public feeds (no auth)

```bash
kagi news --category tech --limit 10
kagi news --list-categories
kagi news --chaos
kagi smallweb
kagi search "open source ai" --news --format toon   # News vertical, session auth
```

## Translate

```bash
kagi translate --text "Bonjour tout le monde" --target-language EN   # session-token auth
```

## Account settings

```bash
kagi lens list
kagi lens get "Default"
kagi bang custom list
kagi bang custom create "Docs" --trigger docs --template "https://docs.rs/releases/search?query=%s"
kagi redirect list
```

## MCP server

Expose Kagi tools to another agent over stdio MCP:

```bash
kagi mcp
```

## jq / parsing patterns

```bash
# Markdown links from search results
kagi search "rust" --format json | jq -r '.data[0:5][] | "- [\(.title)](\(.url))"'

# Only organic results (t == 0)
kagi search "rust" --format json | jq '.data | map(select(.t == 0))'

# Pull the summary text
kagi summarize --subscriber --url "https://example.com" --format json | jq -r '.data.output'

# Assistant reply markdown
kagi assistant "hello" | jq -r '.message.markdown'
```

## Agent-safe patterns

- Prefer the narrowest command: `extract` for readable pages, `quick` for direct answers, `assistant` for conversational/threaded work, `news` for public feeds.
- Prefer `--format toon` for LLM context, `--format json` for programmatic parsing; treat `--format pretty` as human-facing only.
- Run `kagi auth status` before declaring credentials unavailable; never print credential values.
- Use `--local-cache` only when stale data is acceptable.
- Avoid browser automation for Kagi content retrieval unless the workflow truly needs rendered interaction.

## Exit codes

`0` success, `1` error (auth/network/etc.) — chain with `&&` / `||` in scripts.

```bash
kagi search "test" >/dev/null 2>&1 && echo ok || echo failed
```
