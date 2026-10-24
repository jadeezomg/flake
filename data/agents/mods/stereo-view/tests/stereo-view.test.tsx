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
