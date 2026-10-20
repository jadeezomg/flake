import { atom, read, update } from "claude-code";
import type { EngineInterface, Register, RenderViewport } from "claude-code";

import type { ActivityCall, ActivityEntry, CallStatus } from "../types";
import { clockTime, cut, duration, firstLine, summarize } from "./format";

const PANE = "activity";
const TITLE = "Activity";
const STORE_SPLIT = "isSplit";
const MAX_ENTRIES = 400;
const MAX_RESULT = 4000;
const EXPANDED_LINES = 40;

// The person answers these tools, so their rows stay in the conversation.
const CONVERSATION_TOOLS = new Set(["AskUserQuestion", "ExitPlanMode"]);

const USAGE = "Usage: /stereo-view [on|off|results|clear]";

const entries = atom({ plugin: "stereo-view", key: "entries" } as const, []);
const isSplit = atom({ plugin: "stereo-view", key: "isSplit" } as const, true);
const expanded = atom(
	{ plugin: "stereo-view", key: "expanded" } as const,
	null,
);
const showResults = atom(
	{ plugin: "stereo-view", key: "showResults" } as const,
	false,
);

const GLYPH: Record<CallStatus, string> = {
	running: "○",
	done: "✓",
	error: "✗",
	denied: "⊘",
};

const COLOR: Record<CallStatus, string> = {
	running: "warning",
	done: "success",
	error: "error",
	denied: "error",
};

function isCall(entry: ActivityEntry): entry is ActivityCall {
	return entry.kind === "call";
}

function append(list: ActivityEntry[], entry: ActivityEntry): ActivityEntry[] {
	return [...list, entry].slice(-MAX_ENTRIES);
}

function finish(
	list: ActivityEntry[],
	id: string,
	change: Partial<ActivityCall>,
): ActivityEntry[] {
	return list.map((entry) =>
		entry.kind === "call" && entry.id === id ? { ...entry, ...change } : entry,
	);
}

// Tool rows hide only while the Activity pane is on screen beside a
// fullscreen transcript. A change of width redraws every row, so a pane
// that becomes placed on a wider terminal takes the rows with it.
async function isActivityShown(
	$: EngineInterface,
	viewport: RenderViewport | undefined,
): Promise<boolean> {
	if (viewport?.isFullscreen !== true) return false;
	if (!(await read($, isSplit))) return false;
	const panes = await $.ui.panes();

	return panes.some((pane) => pane.id === PANE && pane.isPlaced);
}

async function setSplit($: EngineInterface, isOn: boolean): Promise<void> {
	await $.store.set(STORE_SPLIT, isOn);
	if (!isOn) {
		await update($, isSplit, () => false);
		await $.ui.close({ id: PANE });

		return;
	}
	const opened = await $.ui.open({ id: PANE, title: TITLE });
	await update($, isSplit, () => true);
	if (!opened.isPlaced) $.ui.toast(`Activity waits: ${opened.reason}`);
}

// Rebuilds the list from the stored conversation, for a resumed session.
async function readBack(
	$: EngineInterface,
	cwd: string,
): Promise<ActivityEntry[]> {
	const messages = await $.session.messages();
	if (!Array.isArray(messages)) return [];
	const list: ActivityEntry[] = [];
	messages.forEach((message, index) => {
		if (
			message.role === "user" &&
			message.text.trim() !== "" &&
			message.toolResults === undefined
		) {
			list.push({
				kind: "turn",
				id: `turn:${index}`,
				text: firstLine(message.text),
			});
		}
		for (const use of message.toolUses) {
			list.push({
				kind: "call",
				id: use.tool_use_id,
				tool: use.tool,
				summary: summarize(use.input, cwd),
				status: use.isError === true ? "error" : "done",
				result: use.text?.slice(0, MAX_RESULT),
			});
		}
	});

	return list.slice(-MAX_ENTRIES);
}

export const register: Register = (on) => {
	let cwd = "";

	on("session.start", async ($, e, next) => {
		cwd = e.cwd;
		await $.command.register({
			name: "stereo-view",
			description: "Split tool activity from the conversation into a side pane",
			argumentHint: "[on|off|results|clear]",
		});

		const stored = await $.store.get(STORE_SPLIT);
		const isOn = stored !== false;
		await update($, isSplit, () => isOn);

		if ((await read($, entries)).length === 0) {
			const list = await readBack($, cwd).catch(() => []);
			await update($, entries, () => list);
		}

		// Opened unasked only where the pane is a sidebar: in fullscreen mode.
		const settings = await $.settings.read();
		if (isOn && e.isInteractive && settings.tui === "fullscreen") {
			void $.ui.open({ id: PANE, title: TITLE });
		}

		return next(e);
	});

	on("session.end", async ($, e, next) => {
		if (e.reason === "clear") {
			await update($, entries, () => []);
			await update($, expanded, () => null);
		}

		return next(e);
	});

	on("command.run", { command: "stereo-view" }, async ($, e) => {
		const arg = e.args.trim().toLowerCase();

		if (arg === "clear") {
			await update($, entries, () => []);
			$.ui.toast("Activity cleared");

			return {};
		}
		if (arg === "results") {
			const isShown = await update($, showResults, (value) => !value);
			$.ui.toast(isShown ? "Activity shows results" : "Activity hides results");

			return {};
		}
		if (arg !== "" && arg !== "on" && arg !== "off") return { text: USAGE };

		const isOn = arg === "" ? !(await read($, isSplit)) : arg === "on";
		await setSplit($, isOn);

		return {};
	});

	// The person closed the pane with its mark: show tool rows again.
	on("ui.close", { id: PANE }, async ($, e, next) => {
		if (e.origin.kind === "person") {
			await update($, isSplit, () => false);
			await $.store.set(STORE_SPLIT, false);
		}

		return next(e);
	}).catch((_$, e, next) => next(e));

	on("prompt.submit", async ($, e, next) => {
		if (e.command === undefined && e.isMeta !== true && e.text.trim() !== "") {
			const startedAt = await $.clock.now();
			const id = `turn:${startedAt}`;
			await update($, entries, (list) =>
				append(list, { kind: "turn", id, text: firstLine(e.text), startedAt }),
			);
		}

		return next(e);
	}).catch((_$, e, next) => next(e));

	// These hooks only record. If one fails, the call goes on without the mod.
	on("tool.call", async ($, e, next) => {
		const startedAt = await $.clock.now();
		const id = e.tool_use_id;
		const call: ActivityCall = {
			kind: "call",
			id,
			tool: String(e.tool),
			summary: summarize(e as unknown as Record<string, unknown>, cwd),
			agentId: e.agentId,
			startedAt,
			status: "running",
		};
		await update($, entries, (list) => append(list, call));

		const ran = await next(e);
		const endedAt = await $.clock.now();
		if (ran.deny !== undefined) {
			await update($, entries, (list) =>
				finish(list, id, { status: "denied", endedAt, result: ran.deny }),
			);
		} else {
			const status: CallStatus = ran.isError === true ? "error" : "done";
			const result = ran.text?.slice(0, MAX_RESULT);
			await update($, entries, (list) =>
				finish(list, id, { status, endedAt, result }),
			);
		}

		return ran;
	}).catch((_$, e, next) => next(e));

	on("ui.render", { component: "ToolUse" }, async ($, e, next) => {
		if (CONVERSATION_TOOLS.has(e.props.tool)) return next(e);
		if (!(await isActivityShown($, e.viewport))) return next(e);
		const { Box } = $.ui.resolve(e);

		return <Box />;
	});

	on("ui.render", { component: "ToolResult" }, async ($, e, next) => {
		if (CONVERSATION_TOOLS.has(e.props.tool)) return next(e);
		if (!(await isActivityShown($, e.viewport))) return next(e);
		const { Box } = $.ui.resolve(e);

		return <Box />;
	});

	on("ui.render", { component: "ToolGroup" }, async ($, e, next) => {
		if (e.props.calls.some((call) => CONVERSATION_TOOLS.has(call.tool)))
			return next(e);
		if (!(await isActivityShown($, e.viewport))) return next(e);
		const { Box } = $.ui.resolve(e);

		return <Box />;
	});

	on("ui.render", { component: "Pane", requestId: PANE }, async ($, e) => {
		const { Box, Button, Text } = $.ui.resolve(e);
		const width = Math.max(20, e.props.bodyColumns);
		const all = await read($, entries);
		const open = await read($, expanded);
		const withResults = await read($, showResults);
		const now = await $.clock.now();

		// While a subagent's transcript is in view, show only its calls.
		const viewed = e.props.view.agentId;
		const shown =
			viewed === undefined
				? all
				: all.filter((entry) => isCall(entry) && entry.agentId === viewed);
		const calls = shown.filter(isCall);
		const running = calls.filter((call) => call.status === "running").length;
		const failed = calls.filter(
			(call) => call.status === "error" || call.status === "denied",
		).length;

		const counts = [`${calls.length} calls`];
		if (running > 0) counts.push(`${running} running`);
		if (failed > 0) counts.push(`${failed} failed`);

		const rows = shown.map((entry) => {
			if (entry.kind === "turn") {
				const head = `── ${clockTime(entry.startedAt)} `;

				return (
					<Box marginTop={1}>
						<Text dimColor wrap="truncate-end">
							{head + cut(entry.text, width - head.length)}
						</Text>
					</Box>
				);
			}

			const isSub = entry.agentId !== undefined;
			const time = `${clockTime(entry.startedAt)} `;
			const indent = isSub ? "↳ " : "";
			const took =
				entry.startedAt === undefined
					? ""
					: ` ${duration((entry.endedAt ?? now) - entry.startedAt)}`;
			const room =
				width -
				time.length -
				indent.length -
				2 -
				entry.tool.length -
				1 -
				took.length;
			const isOpen = open === entry.id;
			const resultLines = (entry.result ?? "").split("\n");

			return (
				<Box flexDirection="column">
					<Button
						key={`call:${entry.id}`}
						plain
						onPress={() =>
							update($, expanded, (id) => (id === entry.id ? null : entry.id))
						}
					>
						<Text dimColor>{time}</Text>
						{indent}
						<Text color={COLOR[entry.status]}>{GLYPH[entry.status]} </Text>
						<Text bold>{entry.tool}</Text>
						{` ${cut(entry.summary, room)}`}
						<Text dimColor>{took}</Text>
					</Button>
					{withResults && !isOpen && entry.result !== undefined && (
						<Text dimColor wrap="truncate-end">
							{`         ⎿ ${cut(firstLine(entry.result), width - 11)}`}
						</Text>
					)}
					{isOpen && (
						<Box flexDirection="column" marginLeft={9} marginBottom={1}>
							<Text wrap="wrap">{entry.summary}</Text>
							{entry.result !== undefined && (
								<Text dimColor wrap="wrap">
									{resultLines.slice(0, EXPANDED_LINES).join("\n")}
									{resultLines.length > EXPANDED_LINES
										? `\n… ${resultLines.length - EXPANDED_LINES} more lines`
										: ""}
								</Text>
							)}
						</Box>
					)}
				</Box>
			);
		});

		return (
			<Box flexDirection="column">
				<Box flexDirection="row" gap={1}>
					<Text dimColor>{counts.join(" · ")}</Text>
					<Button
						key="results"
						label={withResults ? "Hide results" : "Results"}
						onPress={() => update($, showResults, (value) => !value)}
					/>
					<Button
						key="clear"
						label="Clear"
						onPress={() => update($, entries, () => [])}
					/>
				</Box>
				{shown.length === 0 && <Text dimColor>No tool calls yet.</Text>}
				{rows}
			</Box>
		);
	});
};
