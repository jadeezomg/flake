---
name: kagi
description: Use the `kagi` CLI for web search, page extraction/summarization, quick factual answers with references, and the Kagi Assistant. Trigger whenever you need to search the web, read or summarize a URL, get a referenced answer to a current-events or factual question, or fetch readable page content — reach for this before built-in WebFetch/WebSearch. Not for library/SDK/API docs (use ctx7) or nixpkgs/NixOS options (use mcp-nixos).
---

# Kagi CLI

`kagi` is a JSON-first command surface for Kagi: web search, Quick Answer, page extraction, summarization, and the Assistant. Prefer it over built-in `WebFetch`/`WebSearch` — it has caching, structured/LLM-friendly output, and account-backed features.

## Core workflow

1. Choose the **narrowest** command for the task.
2. Pick output: `--format toon` for results you feed back into your own context, `--format json` when a program parses stdout, `--format markdown` for answers shown to the user.
3. If a command fails unexpectedly, run `kagi auth status` before declaring it broken — and **never print credential values**.

## Picking a command

| Need | Command |
| --- | --- |
| Web search / discover sources | `kagi search "<query>"` |
| Direct factual answer **with references** | `kagi quick "<question>"` |
| Full readable page content as markdown | `kagi extract <url>` |
| Gist / summary of a page or text | `kagi summarize --subscriber --url <url>` |
| A question about **one specific page** | `kagi ask-page <url> "<question>"` |
| Conversational / multi-step / threaded | `kagi assistant "<prompt>"` |
| Current news (no auth) | `kagi news --category tech --limit 10` |

```bash
kagi search "rust async cancellation" --format toon --limit 5
kagi quick "who maintains the rust release train?" --format markdown
kagi extract "https://example.com/article"
```

Useful `search` flags: `--limit N`, `--snap reddit`, `--time week`, `--news`. For Assistant threads/custom assistants, `--follow`, batch/watch, translate, account settings (lenses, bangs), the full flag set, and the MCP server, see `references/advanced.md`.

## The CLI is self-documenting

The installed CLI ships a **version-matched** guide — authoritative when a flag is unclear:

```bash
kagi agent           # full embedded usage guide
kagi skills get kagi # same guide via the skills surface
kagi <cmd> --help    # exact flags for any subcommand
```

## When NOT to use kagi

- Library / SDK / framework / API / CLI docs → `ctx7` (find-docs skill).
- nixpkgs packages or NixOS/home-manager/darwin/nixvim options → the `mcp-nixos` MCP.
