import { expect, mock, test } from "claude-code/testing";
import type { On, RenderElement, RenderPropsOf } from "claude-code";

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
	expect(await ui.find({ text: /npx vitest run --reporter=dot/ })).toBeDefined();
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
	await $.tool.call({ tool: "mcp__claude_ai_Notion__notion-search", query: "q" });

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
