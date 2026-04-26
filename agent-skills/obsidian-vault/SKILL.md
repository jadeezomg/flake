---
name: obsidian-vault
description: Search, create, and manage notes in jadee's agent-managed Obsidian vault at ~/Git/vault. Use when the user wants to find, file, or organize notes, capture insights/plans/people/events/reading/decisions, or any time you need to write durable knowledge. Read ~/Git/vault/AGENTS.md first for layout and frontmatter schemas.
---

# Obsidian Vault

## Vault location

`~/Git/vault` — git-synced (private) to `github.com/jadeezomg/vault`. Pull/push freely. The vault is **agent-managed**: you write most notes on the user's behalf.

## Read this first

`~/Git/vault/AGENTS.md` is the source of truth for the layout, tag taxonomy, and per-type frontmatter schemas. Open it on entry and follow it.

## Layout (summary)

| Folder | What goes here |
|--------|----------------|
| `inbox/` | Drafts, unsorted material. File here when uncertain. |
| `journal/` | Daily notes (`YYYY-MM-DD.md`). Daily-notes plugin owns. Don't write here directly. |
| `insights/` | Atomic claims. One claim per note. Heavily tagged. |
| `plans/` | Goals, intentions, roadmaps. |
| `people/` | One note per person. |
| `events/` | Trips, birthdays, deadlines, milestones. |
| `reading/` | News/articles/papers with URL + excerpt + take. |
| `reference/` | Durable evergreen knowledge. |
| `projects/` | Active multi-note work threads. |
| `decisions/` | Personal ADRs. |
| `index/` | MOCs (Maps of Content). |
| `archive/` | Done/abandoned. |
| `templates/` | Templates plugin source. Don't write notes here. |
| `assets/` | Attachments only. |

## Filing rules

When writing a new note:

1. Pick the type from context. Map to folder:
   - `insight` → `insights/`
   - `plan` → `plans/`
   - `project` → `projects/`
   - `person` → `people/`
   - `event` → `events/`
   - `reading` → `reading/`
   - `decision` → `decisions/`
   - `reference` → `reference/`
   - unsure → `inbox/`
2. Filename: **Title Case** `.md`. For people, use the person's actual name.
3. Pull frontmatter scaffold from `templates/<type>.md`. Fill required fields.
4. Wikilinks at the bottom under `## Related`.

## Tagging rules

Use Obsidian nested tags (`#a/b/c`). Multi-axis. Every note gets at least one `domain/*` tag.

| Axis | Examples | Applies to |
|------|----------|------------|
| `domain/*` | tech, health, work, family, finance, travel, philosophy, ai, music | every note |
| `status/*` | active, parked, done | plans, projects, decisions |
| `confidence/*` | high, medium, low | insights |
| `source/*` | own, news, conversation, book, podcast, paper | insights, reading |
| `relation/*` | family, friend, colleague, vendor | people |
| `event/*` | birthday, trip, deadline, milestone | events |

## Workflows

### Search

Use Grep / Glob directly on `~/Git/vault`. Tag-based queries: `grep -rl "#domain/ai" ~/Git/vault --include="*.md"`. CLI fallback:

```bash
find ~/Git/vault -name "*.md" -iname "*keyword*"
grep -rl "keyword" ~/Git/vault --include="*.md"
```

### Create a new note

1. Determine type → folder.
2. Read `~/Git/vault/templates/<type>.md`.
3. Write `~/Git/vault/<folder>/<Title Case>.md` with filled frontmatter.
4. Add wikilinks under `## Related`.
5. Don't `git commit` unless the user asked — they may batch.

### Find related (backlinks)

```bash
grep -rl "\\[\\[Note Title\\]\\]" ~/Git/vault
```

### Find index notes

```bash
find ~/Git/vault/index -name "*.md"
```

## Don't

- Don't put notes in `templates/` or `journal/` (plugin-owned).
- Don't put attachments anywhere except `assets/`.
- Don't invent new top-level folders without updating `~/Git/vault/AGENTS.md`.
- Don't use markdown links for inter-vault references — use `[[wikilinks]]`.
