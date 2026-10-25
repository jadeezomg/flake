import { expect, mock, test } from "claude-code/testing";
import type { Engine } from "claude-code/testing";
import type {
	On,
	RenderElement,
	RenderPropsOf,
	SessionUsage,
} from "claude-code";

const PANE_PROPS: RenderPropsOf["Pane"] = {
	title: "Activity",
	isFocused: false,
	bodyColumns: 80,
	placement: "dock",
	scroll: { offset: 0, bodyRows: 30 },
	view: {},
};

const BASH_ROW: RenderPropsOf["ToolUse"] = {
	tool_use_id: "toolu_1",
	tool: "Bash",
	input: { command: "npm test" },
	isRunning: false,
	isErrored: false,
	isInterrupted: false,
	output: { stdout: "ok", stderr: "" },
};

const FULLSCREEN = { columns: 200, rows: 50, isFullscreen: true };

const ENGINE_ROW = "engine row";

const CLOCK = /\d\d:\d\d:\d\d/;

// Stands for the engine's own tool row beneath the plugin.
function engineRow(on: On): void {
	on("ui.render", { component: "ToolUse" }, () => {
		return {
			type: "Text",
			props: {},
			children: [ENGINE_ROW],
		} as unknown as RenderElement;
	});
}

async function isRowShown(ui: {
	find: (query: { text: RegExp }) => Promise<unknown>;
}): Promise<boolean> {
	return (await ui.find({ text: new RegExp(ENGINE_ROW) })) !== undefined;
}

test("a tool call shows in the Activity pane with its result", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({
		result: { stdout: "all 12 passed", stderr: "" },
		text: "all 12 passed",
	}));

	await $.tool.call({ tool: "Bash", command: "npm test" });

	for (const surface of ["terminal", "desktop"] as const) {
		const ui = await $.ui.mount({
			plugin: "stereo-view",
			surface,
			component: "Pane",
			requestId: "activity",
			props: PANE_PROPS,
			viewport: FULLSCREEN,
		});
		const row = await ui.findAll({ type: "Button" });
		const call = row.find((one) => one.key?.startsWith("call:"));
		expect(call?.text).toContain("Bash");
		expect(call?.text).toContain("npm test");
		expect((await ui.find({ text: /1 calls/ }))?.text).toContain("1 calls");

		await ui.press({ key: call?.key ?? "" });
		expect(await ui.find({ text: /all 12 passed/ })).toBeDefined();

		await ui.press({ key: "clear" });
		expect(await ui.find({ text: /No tool calls yet/ })).toBeDefined();
		await ui.unmount();

		await $.tool.call({ tool: "Bash", command: "npm test" });
	}
});

test("a described command shows its description, and the expanded row shows the command", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({
		result: { stdout: "ok", stderr: "" },
		text: "ok",
	}));

	await $.tool.call({
		tool: "Bash",
		command: "cd mods && npx vitest run --reporter=dot",
		description: "Run the mod tests",
	});

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const row = await ui.findAll({ type: "Button" });
	const call = row.find((one) => one.key?.startsWith("call:"));
	expect(call?.text).toContain("Run the mod tests");
	expect(call?.text).not.toContain("vitest");
	expect(call?.text).not.toMatch(CLOCK);

	await ui.press({ key: call?.key ?? "" });
	expect(
		await ui.find({ text: /npx vitest run --reporter=dot/ }),
	).toBeDefined();
	expect(await ui.find({ text: CLOCK })).toBeDefined();
	await ui.unmount();
});

test("a path shows from its repository root", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("fs.exists", (_$, e) => ({ value: e.path === "/work/repo/.git" }));
	on("tool.call", () => ({ result: {}, text: "ok" }));

	const edit = { tool: "Edit", old_string: "a", new_string: "b" } as const;
	await $.tool.call({ ...edit, file_path: "/work/repo/data/settings.json" });
	await $.tool.call({ ...edit, file_path: "/etc/hosts" });

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const rows = (await ui.findAll({ type: "Button" })).filter((one) =>
		one.key?.startsWith("call:"),
	);
	expect(rows[0]?.text).toContain("Edit data/settings.json");
	expect(rows[1]?.text).toContain("Edit /etc/hosts");
	await ui.unmount();
});

test("an MCP tool shows by its server and tool name", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({ result: {}, text: "ok" }));

	await $.tool.call({ tool: "mcp__linear__save_issue", title: "Fix it" });
	await $.tool.call({
		tool: "mcp__claude_ai_Notion__notion-search",
		query: "q",
	});

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const rows = (await ui.findAll({ type: "Button" })).filter((one) =>
		one.key?.startsWith("call:"),
	);
	expect(rows[0]?.text).toContain("linear:save_issue");
	expect(rows[0]?.text).not.toContain("mcp__");
	expect(rows[1]?.text).toContain("Notion:search q");
	await ui.unmount();
});

test("a prompt's divider shows the time since the prompt before it", async ($, on) => {
	const clock = mock.clock(on, { now: 1_000 });
	on("prompt.submit", (_$, e) => ({ text: e.text }));

	const typed = { wait: false, origin: { kind: "composer" } } as const;
	await $.prompt.submit({ ...typed, text: "first prompt" });
	await clock.advance(90_000);
	await $.prompt.submit({ ...typed, text: "second prompt" });

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const text = (await ui.find({ text: /second prompt/ }))?.text;
	expect(text).toMatch(/── \d\d:\d\d:\d\d first prompt/);
	expect(text).toMatch(/── \d\d:\d\d:\d\d \+1m30s second prompt/);
	await ui.unmount();
});

test("tool rows hide only while the pane is placed beside a fullscreen transcript", async ($, on) => {
	let isPlaced = true;
	engineRow(on);
	on("ui.panes", () => ({
		value: [
			{
				id: "activity",
				title: "Activity",
				isShown: true,
				isFocused: false,
				isPlaced,
			},
		],
	}));

	const docked = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "ToolUse",
		props: BASH_ROW,
		viewport: FULLSCREEN,
	});
	expect(await isRowShown(docked)).toBe(false);
	await docked.unmount();

	const mainScreen = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "ToolUse",
		props: BASH_ROW,
		viewport: { ...FULLSCREEN, isFullscreen: false },
	});
	expect(await isRowShown(mainScreen)).toBe(true);
	await mainScreen.unmount();

	isPlaced = false;
	const waiting = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "ToolUse",
		props: BASH_ROW,
		viewport: FULLSCREEN,
	});
	expect(await isRowShown(waiting)).toBe(true);
	await waiting.unmount();
});

test("the question dialog row stays in the conversation", async ($, on) => {
	engineRow(on);
	on("ui.panes", () => ({
		value: [
			{
				id: "activity",
				title: "Activity",
				isShown: true,
				isFocused: false,
				isPlaced: true,
			},
		],
	}));

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "ToolUse",
		props: { ...BASH_ROW, tool: "AskUserQuestion", input: { questions: [] } },
		viewport: FULLSCREEN,
	});
	expect(await isRowShown(ui)).toBe(true);
	await ui.unmount();
});

const USAGE = {
	startedAt: 0,
	context: {
		tokens: 83_200,
		window: 200_000,
		percent: 42,
		breakdown: {
			categories: [
				{
					name: "System prompt",
					tokens: 3_100,
					color: "promptBorder",
					isDeferred: false,
					kind: "used",
				},
				{
					name: "Messages",
					tokens: 80_100,
					color: "permission",
					isDeferred: false,
					kind: "used",
				},
				{
					name: "Deferred tools",
					tokens: 9_000,
					color: "inactive",
					isDeferred: true,
					kind: "deferred",
				},
				{
					name: "Free space",
					tokens: 83_800,
					color: "inactive",
					isDeferred: false,
					kind: "free",
				},
				{
					name: "Autocompact buffer",
					tokens: 33_000,
					color: "inactive",
					isDeferred: false,
					kind: "buffer",
				},
			],
			totalTokens: 83_200,
			maxTokens: 200_000,
			rawMaxTokens: 200_000,
			autocompactSource: "model",
			percentage: 42,
			gridRows: [],
			model: "Opus 5.5",
			memoryFiles: [],
			mcpTools: [],
			agents: [],
			autoCompactThreshold: 167_000,
			isAutoCompactEnabled: true,
			apiUsage: null,
		},
	},
	rateLimits: [
		{ kind: "five_hour", percentUsed: 23, resetsAt: "1970-01-01T05:00:00Z" },
		{ kind: "seven_day", percentUsed: 41 },
	],
	cost: { usd: 1.234 },
} as unknown as SessionUsage;

// With 30 body rows, the list in the lower half shows 14 rows.
async function runCalls($: Engine, count: number): Promise<void> {
	for (let n = 1; n <= count; n += 1) {
		await $.tool.call({
			tool: "Bash",
			command: `echo call-${String(n).padStart(2, "0")}`,
		});
	}
}

async function shownCalls(ui: {
	findAll: (query: {
		type: "Button";
	}) => Promise<{ key?: string; text: string }[]>;
}): Promise<string[]> {
	return (await ui.findAll({ type: "Button" }))
		.filter((one) => one.key?.startsWith("call:"))
		.map((one) => one.text.match(/call-\d\d/)?.[0] ?? "");
}

test("the context shows the window and the spend, and its categories open on a press", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("session.usage", () => ({ value: USAGE }));
	on("session.measure", (_$, e) => ({ changed: e.changed }));
	await $.session.measure({
		context: USAGE.context,
		rateLimits: USAGE.rateLimits,
		changed: ["context"],
	});

	for (const surface of ["terminal", "desktop"] as const) {
		const ui = await $.ui.mount({
			plugin: "stereo-view",
			surface,
			component: "Pane",
			requestId: "activity",
			props: PANE_PROPS,
			viewport: FULLSCREEN,
		});
		expect(await ui.find({ text: /Context Opus 5\.5/ })).toBeDefined();
		expect(
			await ui.find({
				text: /83\.2k \/ 200k tokens \(42%\) · compacts at 167k/,
			}),
		).toBeDefined();
		expect(await ui.find({ text: /\$1\.23/ })).toBeDefined();
		const texts = (await ui.findAll({ type: "Text" })).map((one) => one.text);
		expect(texts.some((one) => /^5h 23% {2}↻ \d\d:\d\d$/.test(one))).toBe(true);
		expect(texts).toContain("7d 41%");
		expect(await ui.find({ text: /▸ Categories 4/ })).toBeDefined();
		expect(await ui.find({ text: /Messages/ })).toBeUndefined();

		await ui.press({ key: "categories" });
		expect(await ui.find({ text: /▾ Categories/ })).toBeDefined();
		expect(await ui.find({ text: /Messages +80\.1k +40\.1%/ })).toBeDefined();
		expect(await ui.find({ text: /Free space/ })).toBeDefined();
		expect(await ui.find({ text: /Deferred tools/ })).toBeUndefined();
		expect(await ui.find({ text: /No tool calls yet/ })).toBeDefined();

		await ui.press({ key: "categories" });
		expect(await ui.find({ text: /Messages/ })).toBeUndefined();
		await ui.unmount();
	}
});

test("the list follows the newest call and scrolls back by entries", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({ result: {}, text: "ok" }));
	await runCalls($, 20);

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	let calls = await shownCalls(ui);
	expect(calls[0]).toBe("call-07");
	expect(calls.at(-1)).toBe("call-20");

	await $.ui.scroll({
		component: "Pane",
		requestId: "activity",
		offset: 0,
		by: -3,
		bodyRows: 30,
		contentRows: 30,
		origin: { kind: "person" },
	});
	calls = await shownCalls(ui);
	expect(calls[0]).toBe("call-04");
	expect(calls.at(-1)).toBe("call-17");

	// The window stops where the list would no longer fill it.
	await $.ui.scroll({
		component: "Pane",
		requestId: "activity",
		offset: 0,
		by: -10,
		bodyRows: 30,
		contentRows: 30,
		origin: { kind: "person" },
	});
	calls = await shownCalls(ui);
	expect(calls[0]).toBe("call-01");
	expect(calls.at(-1)).toBe("call-14");

	await ui.press({ key: "newest" });
	calls = await shownCalls(ui);
	expect(calls.at(-1)).toBe("call-20");
	expect(await ui.find({ key: "newest" })).toBeUndefined();
	await ui.unmount();
});

test("an opened call near the top holds the window at itself", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({ result: {}, text: "one\ntwo\nthree\nfour\nfive" }));
	await runCalls($, 30);

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const first = (await ui.findAll({ type: "Button" })).find((one) =>
		one.text.includes("call-17"),
	);
	await ui.press({ key: first?.key ?? "" });
	let calls = await shownCalls(ui);
	expect(calls.at(-1)).toBe("call-17");
	expect(await ui.find({ text: /five/ })).toBeDefined();
	expect((await ui.find({ key: "newest" }))?.text).toContain("13");

	await ui.press({ key: first?.key ?? "" });
	calls = await shownCalls(ui);
	expect(calls.at(-1)).toBe("call-30");
	await ui.unmount();
});

test("the top half shows the todo list and the changed files", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("fs.exists", (_$, e) => ({ value: e.path === "/work/repo/.git" }));
	on("tool.call", () => ({ result: {}, text: "ok" }));

	await $.tool.call({
		tool: "TodoWrite",
		todos: [
			{ content: "Read the code", status: "completed", activeForm: "Reading" },
			{
				content: "Write the fix",
				status: "in_progress",
				activeForm: "Writing",
			},
			{ content: "Run the tests", status: "pending", activeForm: "Running" },
		],
	});
	const edit = { tool: "Edit", old_string: "a", new_string: "b" } as const;
	await $.tool.call({ ...edit, file_path: "/work/repo/src/a.ts" });
	await $.tool.call({ ...edit, file_path: "/work/repo/src/b.ts" });
	await $.tool.call({ ...edit, file_path: "/work/repo/src/a.ts" });

	for (const surface of ["terminal", "desktop"] as const) {
		const ui = await $.ui.mount({
			plugin: "stereo-view",
			surface,
			component: "Pane",
			requestId: "activity",
			props: PANE_PROPS,
			viewport: FULLSCREEN,
		});
		expect(await ui.find({ text: /Tasks 1\/3 done/ })).toBeDefined();
		expect(await ui.find({ text: /✓ Read the code/ })).toBeDefined();
		expect(await ui.find({ text: /◐ Write the fix/ })).toBeDefined();
		expect(await ui.find({ text: /○ Run the tests/ })).toBeDefined();
		expect(await ui.find({ text: /Recent files 2 changed/ })).toBeDefined();
		expect(await ui.find({ text: /Most edited/ })).toBeDefined();
		const text = (await ui.find({ text: /src\/b\.ts/ }))?.text ?? "";
		expect(text).toMatch(/src\/a\.ts +×2.*src\/b\.ts +×1/s);
		await ui.unmount();
	}
});

test("the task tools keep the task list, and completed tasks hide first", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	let next = 0;
	on("tool.call", (_$, e) => {
		if (e.tool === "TaskCreate") {
			next += 1;
			return {
				result: { task: { id: String(next), subject: e.subject } },
				text: "ok",
			};
		}
		return { result: { success: true }, text: "ok" };
	});

	for (let n = 1; n <= 15; n += 1) {
		const subject = `Task ${String(n).padStart(2, "0")}`;
		await $.tool.call({ tool: "TaskCreate", subject, description: subject });
	}
	for (const taskId of ["1", "2", "3"])
		await $.tool.call({ tool: "TaskUpdate", taskId, status: "completed" });
	await $.tool.call({ tool: "TaskUpdate", taskId: "4", status: "in_progress" });
	await $.tool.call({ tool: "TaskUpdate", taskId: "15", status: "deleted" });

	// The top half has 15 rows. The context without a reading takes 2.
	// With no files, the tasks take 12 of the other 13: 11 rows of tasks.
	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	expect(await ui.find({ text: /Tasks 3\/14 done/ })).toBeDefined();
	expect(await ui.find({ text: /✓ Task 01/ })).toBeUndefined();
	expect(await ui.find({ text: /◐ Task 04/ })).toBeDefined();
	expect(await ui.find({ text: /○ Task 14/ })).toBeDefined();
	expect(await ui.find({ text: /○ Task 15/ })).toBeUndefined();
	expect(await ui.find({ text: /Files none/ })).toBeDefined();
	await ui.unmount();
});

test("a subagent's todos show indented under its label", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({ result: {}, text: "ok" }));
	on("agent.list", () => ({
		value: [
			{
				id: "a1",
				description: "Find the auth code",
				type: "Explore",
				status: "running",
			},
		],
	}));
	on("turn.complete", (_$, e) => ({ text: e.answer }));

	await $.tool.call({
		tool: "TodoWrite",
		todos: [
			{
				content: "Plan the change",
				status: "in_progress",
				activeForm: "Planning",
			},
		],
	});
	await $.tool.call({
		tool: "TodoWrite",
		agentId: "a1",
		todos: [
			{
				content: "Search the repo",
				status: "completed",
				activeForm: "Searching",
			},
			{ content: "Read the handler", status: "pending", activeForm: "Reading" },
		],
	});

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const lines = async () =>
		(await ui.findAll({ type: "Text" })).map((one) => one.text);
	expect(await ui.find({ text: /Tasks 1\/3 done/ })).toBeDefined();
	expect(await lines()).toContain("◐ Plan the change");
	expect(await lines()).toContain("↳ Find the auth code Explore · running");
	expect(await lines()).toContain("  ✓ Search the repo");
	expect(await lines()).toContain("  ○ Read the handler");

	await $.turn.complete({
		answer: "found it",
		durationMs: 10,
		isAborted: false,
		turnId: "t1",
		agentId: "a1",
		reason: "answer",
	});
	expect(await lines()).toContain("↳ Find the auth code Explore · done");
	await ui.unmount();
});

test("the files show the 5 newest changes and the 3 most changed files", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("fs.exists", (_$, e) => ({ value: e.path === "/work/repo/.git" }));
	on("tool.call", () => ({ result: {}, text: "ok" }));

	const edit = { tool: "Edit", old_string: "a", new_string: "b" } as const;
	const order = ["f1", "f1", "f1", "f1", "f2", "f2", "f2", "f3", "f3"];
	for (const name of [...order, "f4", "f5", "f6", "f7"])
		await $.tool.call({ ...edit, file_path: `/work/repo/src/${name}.ts` });

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	expect(await ui.find({ text: /Recent files 7 changed/ })).toBeDefined();
	expect(await ui.find({ text: /── Most edited/ })).toBeDefined();
	// Each file line is a button keyed by its list. It reads `src/f1.ts  ×4`.
	const buttons = await ui.findAll({ type: "Button" });
	const filesOf = (list: string) =>
		buttons.flatMap((one) =>
			one.key?.startsWith(`${list}:`)
				? [one.text.replace(/^src\/(f\d)\.ts +×(\d)$/, "$1×$2")]
				: [],
		);
	expect(filesOf("recent")).toEqual(["f7×1", "f6×1", "f5×1", "f4×1", "f3×2"]);
	expect(filesOf("top")).toEqual(["f1×4", "f2×3", "f3×2"]);
	await ui.unmount();
});

const GIT_STATUS =
	"# branch.head main\n# branch.ab +1 -0\n1 .M N... 1 1 1 a a src/a.ts\n";
const GIT_DIFF = [
	"diff --git a/src/a.ts b/src/a.ts",
	"--- a/src/a.ts",
	"+++ b/src/a.ts",
	"@@ -1 +1 @@",
	"-const a = 1;",
	"+const a = 2;",
].join("\n");

// Stands for git: `status`, `ls-files` of a tracked file, and `diff`.
function fakeGit(on: On): void {
	on("process.run", (_$, e) => {
		const command = e.argv.slice(1, 2)[0];
		const stdout =
			command === "status" ? GIT_STATUS : command === "diff" ? GIT_DIFF : "";
		return {
			value: {
				exitCode: 0,
				stdout,
				stderr: "",
				isStdoutTruncated: false,
				isStderrTruncated: false,
			},
		};
	});
}

test("the git state shows under the files, and a press on a file opens its diff", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("fs.exists", (_$, e) => ({ value: e.path === "/work/repo/.git" }));
	on("tool.call", () => ({ result: {}, text: "ok" }));
	fakeGit(on);
	const edit = { tool: "Edit", old_string: "1", new_string: "2" } as const;
	await $.tool.call({ ...edit, file_path: "/work/repo/src/a.ts" });

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});

	// A press settles the work that the hooks left running, the git reading too.
	await ui.press({ key: "recent:/work/repo/src/a.ts" });
	expect(await ui.find({ text: /⎇ main ↑1 · 1 uncommitted/ })).toBeDefined();
	expect(await ui.find({ text: /Diff src\/a\.ts \+1 −1/ })).toBeDefined();
	expect(await ui.find({ text: /\+const a = 2;/ })).toBeDefined();
	expect(await ui.find({ text: /Activity/ })).toBeUndefined();

	await ui.press({ key: "close-diff" });
	expect(await ui.find({ text: /Activity 1 calls/ })).toBeDefined();
	await ui.unmount();
});

test("the Compact button shows from 70% of the window", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	let percent = 42;
	on("session.usage", () => ({
		value: { ...USAGE, context: { ...USAGE.context, percent } },
	}));
	on("session.measure", (_$, e) => ({ changed: e.changed }));
	const measure = () =>
		$.session.measure({
			context: USAGE.context,
			rateLimits: [],
			changed: ["context"],
		});

	await measure();
	let ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	expect(await ui.find({ key: "compact" })).toBeUndefined();
	await ui.unmount();

	percent = 75;
	await measure();
	ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	expect(await ui.find({ key: "compact" })).toBeDefined();
	await ui.unmount();
});

test("the Failed filter shows only the failed calls", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", (_$, e) =>
		e.tool === "Bash" && e.command === "false"
			? { result: { stdout: "", stderr: "" }, text: "exit 1", isError: true }
			: { result: { stdout: "", stderr: "" }, text: "ok" },
	);
	await $.tool.call({ tool: "Bash", command: "true" });
	await $.tool.call({ tool: "Bash", command: "false" });
	await $.tool.call({ tool: "Bash", command: "true" });

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const rows = async () =>
		(await ui.findAll({ type: "Button" })).filter((one) =>
			one.key?.startsWith("call:"),
		);
	expect(await rows()).toHaveLength(3);
	expect((await ui.find({ key: "failed" }))?.text).toContain("1 failed");

	await ui.press({ key: "failed" });
	expect(await rows()).toHaveLength(1);
	expect((await rows())[0]?.text).toContain("false");
	expect((await ui.find({ key: "failed" }))?.text).toContain("All calls");
	await ui.unmount();
});

test("an opened shell call puts its command in the prompt", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("tool.call", () => ({ result: { stdout: "", stderr: "" }, text: "ok" }));
	let filled = "";
	on("prompt.fill", (_$, e) => {
		filled = e.text;
		return { isFilled: true, text: e.text, cursor: e.text.length };
	});
	await $.tool.call({ tool: "Bash", command: "git status --short" });

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const call = (await ui.findAll({ type: "Button" })).find((one) =>
		one.key?.startsWith("call:"),
	);
	await ui.press({ key: call?.key ?? "" });
	const copy = (await ui.findAll({ type: "Button" })).find((one) =>
		one.key?.startsWith("prompt:"),
	);
	await ui.press({ key: copy?.key ?? "" });
	expect(filled).toBe("git status --short");
	await ui.unmount();
});

test("a running subagent shows under Tasks without tasks of its own", async ($, on) => {
	mock.clock(on, { now: 1_000 });
	on("agent.spawn", () => ({ model: "claude-haiku-5-5", agentId: "a2" }));
	on("turn.complete", (_$, e) => ({ text: e.answer }));
	await $.agent.spawn({
		tool_use_id: "toolu_spawn",
		prompt: "Map the repository.",
		description: "Map the repository",
		subagentType: "Explore",
		provider: { plugin: "engine", tier: "core" },
		parentModel: "claude-opus-5-5",
		background: false,
		fork: false,
	});

	const ui = await $.ui.mount({
		plugin: "stereo-view",
		surface: "terminal",
		component: "Pane",
		requestId: "activity",
		props: PANE_PROPS,
		viewport: FULLSCREEN,
	});
	const lines = async () =>
		(await ui.findAll({ type: "Text" })).map((one) => one.text);
	expect(await ui.find({ text: /Tasks 1 agent running/ })).toBeDefined();
	expect(await lines()).toContain("↳ Map the repository Explore · running");

	await $.turn.complete({
		answer: "done",
		durationMs: 10,
		isAborted: false,
		turnId: "t2",
		agentId: "a2",
		reason: "answer",
	});
	expect(await ui.find({ text: /Tasks none/ })).toBeDefined();
	await ui.unmount();
});
