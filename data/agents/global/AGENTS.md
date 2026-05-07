# Global Instructions

Applies across projects. Local instructions override.

## Rules

- Never game verification — don't weaken assertions, narrow scope, reduce coverage, or skip checks to get a pass.
- If checks already fail, state that and don't attribute the failure to your work.
- If verification fails after a change, make one targeted fix when the cause is clear; otherwise stop and report.

## Uncertainty

Ask before changes to behavior, API, UX, naming, persistence, auth, dependencies, or config. One targeted question; if bundling, each must be independently answerable. When proceeding under low-risk ambiguity, state the assumption.

## Evidence

Gather evidence proportional to risk. For behavior/API/infra changes, trace execution path and regression surface before editing. Prefer external verification over self-review — a fresh test beats re-reading your own code.
