import { expect, test } from "claude-code/testing";

import type { TaskItem } from "../types";
import {
	fileRowsOf,
	fitFiles,
	matchSkill,
	mcpRowsOf,
	nextMcp,
	nextSkills,
	nextTasks,
	shareRows,
} from "../hooks/work";

const LIST: TaskItem[] = [
	{ id: "1", subject: "Main task", status: "pending" },
	{ id: "2", subject: "Old main task", status: "pending" },
	{ id: "3", subject: "Agent task", status: "pending", agentId: "a1" },
	{ id: "todo:main:0", subject: "A todo", status: "pending" },
];

test("TaskList updates tasks in any group and drops the caller's missing tasks", () => {
	const result = {
		tasks: [
			{ id: "1", subject: "Main task", status: "completed", blockedBy: [] },
			{ id: "3", subject: "Agent task", status: "in_progress", blockedBy: [] },
			{ id: "4", subject: "New task", status: "pending", blockedBy: [] },
		],
	};
	const next = nextTasks(LIST, "TaskList", {}, result);

	expect(next).toEqual([
		{ id: "1", subject: "Main task", status: "completed" },
		{ id: "3", subject: "Agent task", status: "in_progress", agentId: "a1" },
		{ id: "todo:main:0", subject: "A todo", status: "pending" },
		{ id: "4", subject: "New task", status: "pending" },
	]);
});

test("TodoWrite of a subagent replaces only that subagent's tasks", () => {
	const input = {
		todos: [{ content: "Agent todo", status: "pending", activeForm: "Doing" }],
	};
	const next = nextTasks(LIST, "TodoWrite", input, {}, "a1");

	expect(next.filter((task) => task.agentId === "a1")).toEqual([
		{
			id: "todo:a1:0",
			subject: "Agent todo",
			status: "pending",
			agentId: "a1",
		},
	]);
	expect(next.filter((task) => task.agentId === undefined)).toHaveLength(3);
});

test("the files group by folder, the folder with the newest change first", () => {
	const rows = fileRowsOf([
		{ path: "/r/src/b.ts", label: "src/b.ts", edits: 1 },
		{ path: "/r/README.md", label: "README.md", edits: 2 },
		{ path: "/r/src/a.ts", label: "src/a.ts", edits: 3 },
	]);

	expect(
		rows.map((row) => (row.kind === "dir" ? row.label : `  ${row.name}`)),
	).toEqual(["src/", "  b.ts", "  a.ts", "./", "  README.md"]);
});

test("a folder row never ends the files that fit, and the rest count as files", () => {
	const rows = fileRowsOf([
		{ path: "/r/a/1.ts", label: "a/1.ts", edits: 1 },
		{ path: "/r/a/2.ts", label: "a/2.ts", edits: 1 },
		{ path: "/r/b/3.ts", label: "b/3.ts", edits: 1 },
		{ path: "/r/b/4.ts", label: "b/4.ts", edits: 1 },
	]);
	// Five rows: `fit` keeps a/, 1.ts, 2.ts and b/, and gives the last row
	// to the count. The folder b/ then has no file, so it goes too.
	const { kept, hidden } = fitFiles(rows, 5);

	expect(kept.map((row) => row.kind)).toEqual(["dir", "file", "file"]);
	expect(hidden).toBe(2);
	expect(fitFiles(rows, 6)).toEqual({ kept: rows, hidden: 0 });
});

test("each part gets its heading first, then an equal share of the rest", () => {
	expect(shareRows([10, 1, 4, 3], 12)).toEqual([4, 1, 4, 3]);
	expect(shareRows([10, 10], 9)).toEqual([5, 4]);
	expect(shareRows([2, 2, 2, 2], 20)).toEqual([2, 2, 2, 2]);
	// Too few rows: the headings go in order.
	expect(shareRows([3, 3, 3, 3], 2)).toEqual([1, 1, 0, 0]);
});

test("a skill keeps one entry, and a later use fills in its source", () => {
	const back = nextSkills([], { name: "adr", source: "" });
	const live = nextSkills(nextSkills(back, { name: "pdf", source: "plugin" }), {
		name: "adr",
		source: "plugin",
		pluginName: "caya-working-docs",
	});

	expect(live).toEqual([
		{ name: "adr", source: "plugin", pluginName: "caya-working-docs", uses: 2 },
		{ name: "pdf", source: "plugin", uses: 1 },
	]);
});

test("an MCP call counts under its server and tool, and other tools change nothing", () => {
	let list = nextMcp([], "mcp__linear__list_issues", false);
	list = nextMcp(list, "mcp__claude_ai_Notion__notion-search", false);
	list = nextMcp(list, "mcp__linear__get_issue", true);
	list = nextMcp(list, "Bash", false);

	expect(list).toEqual([
		{
			server: "linear",
			tools: [
				{ name: "get_issue", calls: 1, failed: 1 },
				{ name: "list_issues", calls: 1, failed: 0 },
			],
		},
		{ server: "Notion", tools: [{ name: "search", calls: 1, failed: 0 }] },
	]);
	expect(mcpRowsOf(list, ["linear"]).map((row) => row.kind)).toEqual([
		"server",
		"server",
		"tool",
	]);
});

test("a skill matches its listed name with or without its plugin prefix", () => {
	const listed = [
		{
			name: "simple-english:simple-english",
			source: "plugin",
			pluginName: "simple-english",
		},
		{ name: "agent-structure", source: "projectSettings" },
	];

	expect(matchSkill(listed, "simple-english")?.name).toBe(
		"simple-english:simple-english",
	);
	expect(matchSkill(listed, "agent-structure")?.source).toBe("projectSettings");
	expect(matchSkill(listed, "compact")).toBeUndefined();
});
