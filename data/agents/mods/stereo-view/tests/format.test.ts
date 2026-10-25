import { expect, test } from "claude-code/testing";

import { resetLabel, turnsLeft } from "../hooks/format";
import { diffColor, diffCounts, gitLabel, parseStatus } from "../hooks/git";

const STATUS = [
	"# branch.oid d4bdb0b1",
	"# branch.head main",
	"# branch.upstream origin/main",
	"# branch.ab +2 -1",
	"1 .M N... 100644 100644 100644 9f48 9f48 data/a.json",
	"1 M. N... 100644 100644 100644 f4a8 f4a9 data/b.json",
	"2 R. N... 100644 100644 100644 aaaa aaaa R100 c.ts\tb.ts",
	"? notes.md",
	"",
].join("\n");

test("git status reads as the branch, the counts and one label", () => {
	const state = parseStatus(STATUS);

	expect(state).toEqual({
		branch: "main",
		ahead: 2,
		behind: 1,
		changed: 4,
		staged: 2,
	});
	expect(gitLabel(state)).toBe("main ↑2 ↓1 · 4 uncommitted, 2 staged");
	expect(gitLabel(parseStatus("# branch.head main\n"))).toBe("main · clean");
});

test("a diff counts its added and removed lines, without the file headers", () => {
	const lines = [
		"diff --git a/x b/x",
		"--- a/x",
		"+++ b/x",
		"@@ -1,2 +1,2 @@",
		"-old",
		"+new",
		"+more",
		" same",
	];

	expect(diffCounts(lines)).toEqual({ added: 2, removed: 1 });
	expect(lines.map(diffColor)).toEqual([
		"inactive",
		"inactive",
		"inactive",
		"suggestion",
		"error",
		"success",
		"success",
		undefined,
	]);
});

test("a reset within a day shows its time, a later one also its day", () => {
	const now = Date.parse("2026-10-25T12:00:00");

	expect(resetLabel("2026-10-25T18:30:00", now)).toBe("18:30");
	expect(resetLabel("2026-10-30T09:00:00", now)).toBe("Fri 09:00");
	expect(resetLabel("not a date", now)).toBe("");
});

test("the turns until compaction come from the mean growth of the turns", () => {
	expect(turnsLeft([100_000, 120_000, 140_000], 200_000)).toBe(3);
	expect(turnsLeft([100_000], 200_000)).toBeUndefined();
	expect(turnsLeft([120_000, 100_000], 200_000)).toBeUndefined();
});
