import type { GitState } from "../types";

/** Reads the output of `git status --porcelain=v2 --branch`. */
export function parseStatus(stdout: string): GitState {
	const state: GitState = {
		branch: "",
		ahead: 0,
		behind: 0,
		changed: 0,
		staged: 0,
	};
	for (const line of stdout.split("\n")) {
		if (line.startsWith("# branch.head ")) {
			state.branch = line.slice("# branch.head ".length);
		} else if (line.startsWith("# branch.ab ")) {
			const [ahead, behind] = line.slice("# branch.ab ".length).split(" ");
			state.ahead = Math.abs(Number(ahead) || 0);
			state.behind = Math.abs(Number(behind) || 0);
		} else if (line.startsWith("? ")) {
			state.changed += 1;
		} else if (/^[12u] /.test(line)) {
			// The second field holds the staged and the unstaged state.
			state.changed += 1;
			if (line[2] !== ".") state.staged += 1;
		}
	}

	return state;
}

/** One line for the git state, such as `main ↑1 · 4 uncommitted, 1 staged`. */
export function gitLabel(state: GitState): string {
	let text = state.branch === "(detached)" ? "detached HEAD" : state.branch;
	if (state.ahead > 0) text += ` ↑${state.ahead}`;
	if (state.behind > 0) text += ` ↓${state.behind}`;
	if (state.changed === 0) return `${text} · clean`;
	text += ` · ${state.changed} uncommitted`;

	return state.staged > 0 ? `${text}, ${state.staged} staged` : text;
}

/** How many lines a diff adds and removes, without its file headers. */
export function diffCounts(lines: readonly string[]): {
	added: number;
	removed: number;
} {
	let added = 0;
	let removed = 0;
	for (const line of lines) {
		if (line.startsWith("+") && !line.startsWith("+++")) added += 1;
		if (line.startsWith("-") && !line.startsWith("---")) removed += 1;
	}

	return { added, removed };
}

/** The theme color of one diff line; undefined keeps the text color. */
export function diffColor(line: string): string | undefined {
	if (line.startsWith("+++") || line.startsWith("---")) return "inactive";
	if (line.startsWith("+")) return "success";
	if (line.startsWith("-")) return "error";
	if (line.startsWith("@@")) return "suggestion";
	if (/^(diff|index|new file|deleted file|similarity|rename) /.test(line))
		return "inactive";

	return undefined;
}
