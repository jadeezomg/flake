import { atom, read, update } from "claude-code";
import type {
	EngineInterface,
	Register,
	RenderViewport,
	SessionUsage,
} from "claude-code";

import type {
	ActivityCall,
	ActivityEntry,
	AgentLabel,
	CallStatus,
	ContextInfo,
	ContextRow,
	FileChange,
	FileDiff,
	McpServerUse,
	SkillUse,
	TaskItem,
	TaskStatus,
} from "../types";
import {
	barCells,
	clockTime,
	commandOf,
	cut,
	cutStart,
	duration,
	firstLine,
	hardWrap,
	limitLabel,
	mcpParts,
	pathsOf,
	resetLabel,
	skillParts,
	summarize,
	tokenCount,
	toolLabel,
	turnsLeft,
} from "./format";
import { diffColor, diffCounts, gitLabel, parseStatus } from "./git";
import {
	FILE_TOOLS,
	TASK_TOOLS,
	fileRowsOf,
	fit,
	fitFiles,
	mcpRowsOf,
	nextFiles,
	nextMcp,
	nextSkills,
	nextTasks,
	shareRows,
} from "./work";
import type { FileRow, McpRow } from "./work";

const PANE = "activity";
const TITLE = "Activity";
const STORE_SPLIT = "isSplit";
const MAX_ENTRIES = 400;
const MAX_RESULT = 4000;
// Cells before a call's glyph: its duration, right-aligned, and a space.
const LEAD = 7;
// The minimum number of body rows for the split. A smaller body scrolls.
const MIN_BODY_ROWS = 12;
// The parts under the context: tasks, skills, MCP servers, and files. The
// context leaves at least their headings.
const WORK_PARTS = 4;
const RULE = "─".repeat(400);
// From these fills of the window, in percent, the bar takes the warning
// color and the Compact button shows, then the bar takes the error color.
const WARN_PERCENT = 70;
const ALERT_PERCENT = 90;
// The number of recent turns that the estimate of turns until compaction uses.
const TURN_SAMPLES = 6;

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
const contextInfo = atom(
	{ plugin: "stereo-view", key: "context" } as const,
	null,
);
const anchor = atom({ plugin: "stereo-view", key: "anchor" } as const, null);
const tasks = atom({ plugin: "stereo-view", key: "tasks" } as const, []);
const agents = atom({ plugin: "stereo-view", key: "agents" } as const, []);
const files = atom({ plugin: "stereo-view", key: "files" } as const, []);
const showCategories = atom(
	{ plugin: "stereo-view", key: "showCategories" } as const,
	false,
);
const turnTokens = atom(
	{ plugin: "stereo-view", key: "turnTokens" } as const,
	[],
);
const gitState = atom({ plugin: "stereo-view", key: "git" } as const, null);
const fileDiff = atom(
	{ plugin: "stereo-view", key: "fileDiff" } as const,
	null,
);
const diffScroll = atom(
	{ plugin: "stereo-view", key: "diffScroll" } as const,
	0,
);
const onlyFailed = atom(
	{ plugin: "stereo-view", key: "onlyFailed" } as const,
	false,
);
const skills = atom({ plugin: "stereo-view", key: "skills" } as const, []);
const mcp = atom({ plugin: "stereo-view", key: "mcp" } as const, []);
const closedServers = atom(
	{ plugin: "stereo-view", key: "closedServers" } as const,
	[],
);

// One row of the Tasks list: a task, or the label of the subagent whose
// tasks follow it, indented.
type TaskRow =
	| { kind: "task"; task: TaskItem; isNested: boolean }
	| { kind: "agent"; agent: AgentLabel };

// The main tasks first, then a label for each subagent that runs or that
// wrote tasks, with its tasks under it.
function taskRowsOf(
	list: readonly TaskItem[],
	labels: readonly AgentLabel[],
): TaskRow[] {
	const rows: TaskRow[] = [];
	for (const task of list)
		if (task.agentId === undefined)
			rows.push({ kind: "task", task, isNested: false });
	const ids = new Set([
		...labels.flatMap((one) => (one.isDone ? [] : [one.id])),
		...list.flatMap((task) => task.agentId ?? []),
	]);
	for (const id of ids) {
		const agent = labels.find((one) => one.id === id) ?? {
			id,
			label: "subagent",
			type: "agent",
			isDone: false,
		};
		rows.push({ kind: "agent", agent });
		for (const task of list)
			if (task.agentId === id)
				rows.push({ kind: "task", task, isNested: true });
	}

	return rows;
}

const TASK_GLYPH: Record<TaskStatus, string> = {
	pending: "○",
	in_progress: "◐",
	completed: "✓",
};

const TASK_COLOR: Record<TaskStatus, string | undefined> = {
	pending: undefined,
	in_progress: "warning",
	completed: "success",
};

// The lower half as the pane last drew it: the ids of the list's entries,
// oldest first, the first one the window may end on, so that the window
// stays full, and the rows that an open diff shows.
let layout: { ids: string[]; top: number; diffRows: number } = {
	ids: [],
	top: 0,
	diffRows: 0,
};

const AREA: Record<ContextRow["kind"], string> = {
	used: "█",
	free: "░",
	buffer: "▒",
};

const KIND_ORDER: Record<ContextRow["kind"], number> = {
	used: 0,
	free: 1,
	buffer: 2,
};

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

// Each folder's repository root, or null outside any. A folder that holds
// `.git` (a folder, or a file in a worktree) is a root.
const rootOf = new Map<string, string | null>();

async function repoRoot(
	$: EngineInterface,
	path: string,
): Promise<string | null> {
	const seen: string[] = [];
	let dir = path.slice(0, path.lastIndexOf("/"));
	let root: string | null = null;
	while (dir !== "") {
		const known = rootOf.get(dir);
		if (known !== undefined) {
			root = known;
			break;
		}
		seen.push(dir);
		if (await $.fs.exists(`${dir}/.git`).catch(() => false)) {
			root = dir;
			break;
		}
		dir = dir.slice(0, dir.lastIndexOf("/"));
	}
	for (const one of seen) rootOf.set(one, root);

	return root;
}

async function rootsFor(
	$: EngineInterface,
	input: Record<string, unknown>,
): Promise<string[]> {
	const roots = await Promise.all(
		pathsOf(input).map((path) => repoRoot($, path)),
	);

	return roots.filter((root): root is string => root !== null);
}

type ReadBack = {
	list: ActivityEntry[];
	taskList: TaskItem[];
	fileList: FileChange[];
	skillList: SkillUse[];
	mcpList: McpServerUse[];
};

// Rebuilds the list, the tasks, the changed files, the skills and the MCP
// servers from the stored conversation, for a resumed session. Subagent
// calls are not stored there. Of the skills, only the Skill tool's calls are
// stored: a skill that the person typed as `/name` is not read back.
async function readBack($: EngineInterface): Promise<ReadBack> {
	const messages = await $.session.messages();
	const list: ActivityEntry[] = [];
	let taskList: TaskItem[] = [];
	let fileList: FileChange[] = [];
	let skillList: SkillUse[] = [];
	let mcpList: McpServerUse[] = [];
	if (!Array.isArray(messages))
		return { list, taskList, fileList, skillList, mcpList };
	for (const [index, message] of messages.entries()) {
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
			const summary = summarize(use.input, await rootsFor($, use.input));
			list.push({
				kind: "call",
				id: use.tool_use_id,
				tool: use.tool,
				summary,
				command: commandOf(use.input)?.slice(0, MAX_RESULT),
				status: use.isError === true ? "error" : "done",
				result: use.text?.slice(0, MAX_RESULT),
			});
			// A call in flight has no text yet.
			if (use.text !== undefined)
				mcpList = nextMcp(mcpList, use.tool, use.isError === true);
			if (use.isError === true || use.text === undefined) continue;
			const skill = use.input.skill;
			if (use.tool === "Skill" && typeof skill === "string")
				skillList = nextSkills(skillList, { name: skill, source: "" });
			if (TASK_TOOLS.has(use.tool))
				taskList = nextTasks(taskList, use.tool, use.input, use.result);
			const path = pathsOf(use.input)[0];
			if (FILE_TOOLS.has(use.tool) && path !== undefined)
				fileList = nextFiles(fileList, path, summary);
		}
	}

	return {
		list: list.slice(-MAX_ENTRIES),
		taskList,
		fileList,
		skillList,
		mcpList,
	};
}

// Keeps the label of a subagent and marks it as running. The engine drops
// a finished agent from its own list after a while. A spawn gives the label,
// else the engine's list does.
async function noteAgent(
	$: EngineInterface,
	agentId: string,
	spawned?: { label: string; type: string },
): Promise<void> {
	if ((await read($, agents)).some((one) => one.id === agentId)) {
		await update($, agents, (list) =>
			list.map((one) => (one.id === agentId ? { ...one, isDone: false } : one)),
		);

		return;
	}
	const info =
		spawned === undefined
			? (await $.agent.list()).find((one) => one.id === agentId)
			: undefined;
	const agent: AgentLabel = {
		id: agentId,
		label: spawned?.label || info?.description || info?.name || "subagent",
		type: spawned?.type ?? info?.type ?? "agent",
		isDone: false,
	};
	await update($, agents, (list) =>
		list.some((one) => one.id === agentId) ? list : [...list, agent],
	);
}

function infoOf(usage: SessionUsage): ContextInfo {
	const { context } = usage;
	const breakdown = context.breakdown;
	const rows: ContextRow[] = [];
	for (const one of breakdown?.categories ?? []) {
		// Deferred tool schemas sit outside the window.
		if (one.kind === "deferred") continue;
		rows.push({
			name: one.name,
			tokens: one.tokens,
			color: one.color,
			kind: one.kind,
		});
	}
	// The used rows first, then the free space, then the compaction
	// buffer, so the bar ends where auto-compaction starts.
	rows.sort((a, b) => KIND_ORDER[a.kind] - KIND_ORDER[b.kind]);

	// The input of the last response, and the part of it that came from the
	// prompt cache.
	const api = breakdown?.apiUsage;
	const input =
		api === undefined || api === null
			? 0
			: api.input_tokens +
				api.cache_creation_input_tokens +
				api.cache_read_input_tokens;

	return {
		model: breakdown?.model,
		tokens: context.tokens,
		window: context.window,
		percent: context.percent,
		rowsWindow: breakdown?.rawMaxTokens,
		rows,
		compactAt: breakdown?.autoCompactThreshold,
		usd: usage.cost?.usd,
		cacheRate:
			api === undefined || api === null || input === 0
				? undefined
				: Math.round((api.cache_read_input_tokens / input) * 100),
		limits: usage.rateLimits.map(({ kind, percentUsed, resetsAt }) => ({
			kind,
			percentUsed,
			resetsAt,
		})),
	};
}

// Each reading runs only once at a time. A call during a reading starts
// one more reading after it. The engine follows `$` only into functions
// declared here, so each reading keeps its own loop.
const contextReading = { isReading: false, isStale: false };
const gitReading = { isReading: false, isStale: false };

// Reads the context window and its breakdown. The `summary` breakdown
// estimates locally and sends no request.
async function readContext($: EngineInterface): Promise<void> {
	if (contextReading.isReading) {
		contextReading.isStale = true;

		return;
	}
	contextReading.isReading = true;
	try {
		do {
			contextReading.isStale = false;
			const usage = await $.session.usage({ breakdown: "summary" });
			await update($, contextInfo, () => infoOf(usage));
		} while (contextReading.isStale);
	} finally {
		contextReading.isReading = false;
	}
}

// Reads the git state of the folder that the session runs in. Outside a
// repository, the state is null.
async function readGit($: EngineInterface): Promise<void> {
	if (gitReading.isReading) {
		gitReading.isStale = true;

		return;
	}
	gitReading.isReading = true;
	try {
		do {
			gitReading.isStale = false;
			const argv = ["git", "status", "--porcelain=v2", "--branch"];
			const ran = await $.process.run(argv);
			const state = ran.exitCode === 0 ? parseStatus(ran.stdout) : null;
			await update($, gitState, () => state);
		} while (gitReading.isStale);
	} finally {
		gitReading.isReading = false;
	}
}

const MAX_DIFF_LINES = 2000;

// The diff of one file against HEAD, one line each. A file that git does
// not track shows as new.
async function diffOf($: EngineInterface, path: string): Promise<string[]> {
	const root = await repoRoot($, path);
	if (root === null) return ["The file is not in a git repository."];
	const git = (argv: string[]) =>
		$.process.run(["git", ...argv], { cwd: root });
	const isTracked =
		(await git(["ls-files", "--error-unmatch", "--", path])).exitCode === 0;
	const ran = isTracked
		? await git(["diff", "--no-color", "HEAD", "--", path])
		: await git(["diff", "--no-color", "--no-index", "--", "/dev/null", path]);
	// `--no-index` ends with 1 when the files differ.
	if (ran.exitCode > 1) return [firstLine(ran.stderr) || "git diff failed."];
	const text = ran.stdout.replaceAll("\t", "  ").trimEnd();
	if (text === "") return ["No changes against HEAD."];

	return text.split("\n").slice(0, MAX_DIFF_LINES);
}

async function openDiff($: EngineInterface, file: FileChange): Promise<void> {
	const lines = await diffOf($, file.path);
	const diff: FileDiff = { path: file.path, label: file.label, lines };
	await update($, fileDiff, () => diff);
	await update($, diffScroll, () => 0);
}

export const register: Register = (on) => {
	on("session.start", async ($, e, next) => {
		await $.command.register({
			name: "stereo-view",
			description: "Split tool activity from the conversation into a side pane",
			argumentHint: "[on|off|results|clear]",
		});

		const stored = await $.store.get(STORE_SPLIT);
		const isOn = stored !== false;
		await update($, isSplit, () => isOn);

		// Each value that is still empty comes from the stored conversation.
		const isEmpty = {
			list: (await read($, entries)).length === 0,
			taskList: (await read($, tasks)).length === 0,
			fileList: (await read($, files)).length === 0,
			skillList: (await read($, skills)).length === 0,
			mcpList: (await read($, mcp)).length === 0,
		};
		if (Object.values(isEmpty).some((value) => value)) {
			const back = await readBack($).catch(() => null);
			if (back !== null && isEmpty.list)
				await update($, entries, () => back.list);
			if (back !== null && isEmpty.taskList)
				await update($, tasks, () => back.taskList);
			if (back !== null && isEmpty.fileList)
				await update($, files, () => back.fileList);
			if (back !== null && isEmpty.skillList)
				await update($, skills, () => back.skillList);
			if (back !== null && isEmpty.mcpList)
				await update($, mcp, () => back.mcpList);
		}

		// Opened unasked only where the pane is a sidebar: in fullscreen mode.
		const settings = await $.settings.read();
		if (isOn && e.isInteractive && settings.tui === "fullscreen") {
			void $.ui.open({ id: PANE, title: TITLE });
		}

		const started = await next(e);
		void readContext($).catch(() => undefined);
		void readGit($).catch(() => undefined);

		return started;
	});

	on("session.end", async ($, e, next) => {
		if (e.reason === "clear") {
			await update($, entries, () => []);
			await update($, expanded, () => null);
			await update($, anchor, () => null);
			await update($, contextInfo, () => null);
			await update($, tasks, () => []);
			await update($, agents, () => []);
			await update($, files, () => []);
			await update($, turnTokens, () => []);
			await update($, fileDiff, () => null);
			await update($, skills, () => []);
			await update($, mcp, () => []);
			await update($, closedServers, () => []);
		}

		return next(e);
	});

	// The engine loads a skill's prompt for a typed `/name`, for the Skill
	// tool, and for a subagent that preloads it. This hook only records.
	on("skill.prompt", async ($, e, next) => {
		const loaded = await next(e);
		await update($, skills, (list) =>
			nextSkills(list, {
				name: e.skill,
				source: e.source,
				...(e.pluginName === undefined ? {} : { pluginName: e.pluginName }),
			}),
		);

		return loaded;
	}).catch((_$, e, next) => next(e));

	// A subagent runs from its spawn. Its own description labels it.
	on("agent.spawn", async ($, e, next) => {
		const spawned = await next(e);
		if (spawned.agentId !== undefined) {
			await noteAgent($, spawned.agentId, {
				label: e.description,
				type: e.subagentType,
			});
		}

		return spawned;
	}).catch((_$, e, next) => next(e));

	// A subagent is done when its turn ends.
	on("turn.complete", async ($, e, next) => {
		const id = e.agentId;
		if (
			id !== undefined &&
			(await read($, agents)).some((one) => one.id === id)
		)
			await update($, agents, (list) =>
				list.map((one) => (one.id === id ? { ...one, isDone: true } : one)),
			);

		return next(e);
	}).catch((_$, e, next) => next(e));

	// The engine measures after each turn of the main conversation. The
	// input tokens of the recent turns give the turns until compaction. A
	// drop, as after a compaction, starts the samples again.
	on("session.measure", async ($, e, next) => {
		const tokens = e.context.tokens;
		if (e.changed.includes("context") && tokens !== undefined) {
			await update($, turnTokens, (list) => {
				const last = list.at(-1);
				if (last !== undefined && tokens < last) return [tokens];

				return [...list, tokens].slice(-TURN_SAMPLES);
			});
		}
		void readContext($).catch(() => undefined);
		void readGit($).catch(() => undefined);

		return next(e);
	}).catch((_$, e, next) => next(e));

	on("command.run", { command: "stereo-view" }, async ($, e) => {
		const arg = e.args.trim().toLowerCase();

		if (arg === "clear") {
			await update($, entries, () => []);
			await update($, anchor, () => null);
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
		const input = e as unknown as Record<string, unknown>;
		const call: ActivityCall = {
			kind: "call",
			id,
			tool: String(e.tool),
			summary: summarize(input, await rootsFor($, input)),
			command: commandOf(input)?.slice(0, MAX_RESULT),
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
			if (status === "done") {
				if (TASK_TOOLS.has(call.tool)) {
					await update($, tasks, (list) =>
						nextTasks(list, call.tool, input, ran.result, e.agentId),
					);
					if (e.agentId !== undefined) await noteAgent($, e.agentId);
				}
				const path = pathsOf(input)[0];
				if (FILE_TOOLS.has(call.tool) && path !== undefined) {
					await update($, files, (list) => nextFiles(list, path, call.summary));
					// An open diff of this file shows the new change.
					const open = await read($, fileDiff);
					if (open?.path === path) {
						const lines = await diffOf($, path);
						await update($, fileDiff, () => ({ ...open, lines }));
					}
				}
				// A file tool or a shell command can change the working tree.
				if (FILE_TOOLS.has(call.tool) || call.tool === "Bash")
					void readGit($).catch(() => undefined);
			}
		}
		// Each MCP call counts, also a failed or denied one.
		if (mcpParts(call.tool) !== undefined) {
			const isFailed = ran.deny !== undefined || ran.isError === true;
			await update($, mcp, (list) => nextMcp(list, call.tool, isFailed));
		}
		// The result is now part of the main conversation's context.
		if (e.agentId === undefined) void readContext($).catch(() => undefined);

		return ran;
	}).catch((_$, e, next) => next(e));

	// The tree fits the body, so the engine's window has nothing to move.
	// The lower half moves instead: an open diff by rows, else the list by
	// one entry for each row of the move.
	on("ui.scroll", { requestId: PANE }, async ($, e) => {
		const { ids, top, diffRows } = layout;
		if (e.by === 0) return {};
		const diff = await read($, fileDiff);
		if (diff !== null) {
			const most = Math.max(0, diff.lines.length - diffRows);
			await update($, diffScroll, (at) =>
				Math.min(most, Math.max(0, at + e.by)),
			);

			return {};
		}
		if (ids.length === 0) return {};
		const last = ids.length - 1;
		await update($, anchor, (current) => {
			const at = current === null ? -1 : ids.indexOf(current);
			const to = Math.min(last, Math.max(top, (at < 0 ? last : at) + e.by));

			return to >= last ? null : (ids[to] ?? null);
		});

		return {};
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
		const info = await read($, contextInfo);
		const pinned = await read($, anchor);
		const taskList = await read($, tasks);
		const agentList = await read($, agents);
		const fileList = await read($, files);
		const withCategories = await read($, showCategories);
		const samples = await read($, turnTokens);
		const git = await read($, gitState);
		const diff = await read($, fileDiff);
		const diffAt = await read($, diffScroll);
		const failedOnly = await read($, onlyFailed);
		const skillList = await read($, skills);
		const mcpList = await read($, mcp);
		const closed = await read($, closedServers);
		const now = await $.clock.now();

		// The body splits in half. The top half shows the context window,
		// then the tasks, the skills, the MCP servers and the changed files.
		// The lower half shows the calls. Each part gives its first row to
		// its heading.
		const bodyRows = Math.max(MIN_BODY_ROWS, e.props.scroll.bodyRows);
		const topRows = Math.floor(bodyRows / 2);
		const lowRows = bodyRows - topRows;
		const listRows = lowRows - 1;

		// A heading row: a title, dim details, and a rule to the right edge.
		const heading = (title: string, detail: string) => (
			<Box
				flexDirection="row"
				flexGrow={1}
				height={1}
				overflow="hidden"
				gap={1}
			>
				<Text wrap="truncate-end">
					<Text dimColor>{"── "}</Text>
					<Text weight="bold">{title}</Text>
					<Text dimColor>{detail === "" ? "" : ` ${detail}`}</Text>
				</Text>
				<Box flexGrow={1} width={0} minWidth={1} height={1} overflow="hidden">
					<Text dimColor>{RULE}</Text>
				</Box>
			</Box>
		);

		// From WARN_PERCENT, the used part of the bar takes the warning color
		// and the heading shows a Compact button.
		const fillPercent = info?.percent ?? 0;
		const isWarm = fillPercent >= WARN_PERCENT;
		const usedColor =
			fillPercent >= ALERT_PERCENT ? "error" : isWarm ? "warning" : undefined;

		// The bar and the categories measure against the compaction window,
		// which can be smaller than the model's window.
		const categories = info?.rows ?? [];
		const total =
			info === null
				? 0
				: categories.length > 0
					? (info.rowsWindow ??
						categories.reduce((sum, row) => sum + row.tokens, 0))
					: info.window;
		const parts =
			categories.length > 0
				? categories.map((row) => ({
						glyph: AREA[row.kind],
						color:
							row.kind === "used" && usedColor !== undefined
								? usedColor
								: row.color,
						tokens: row.tokens,
					}))
				: info === null
					? []
					: [
							{
								glyph: AREA.used,
								color: usedColor ?? "claude",
								tokens: info.tokens ?? 0,
							},
							{
								glyph: AREA.free,
								color: "inactive",
								tokens: Math.max(0, info.window - (info.tokens ?? 0)),
							},
						];
		const cells = barCells(
			parts.map((part) => part.tokens),
			total,
			width,
		);
		const share = (tokens: number) =>
			total > 0 ? `${((tokens / total) * 100).toFixed(1)}%` : "";
		// The categories are indented by two cells under their toggle.
		const nameRoom = Math.max(1, width - 18);

		let fill = "";
		const spend: string[] = [];
		// Each limit is one item of its row. The row spreads them out: two go
		// to the left and right edges, three also to the middle.
		const limits: string[] = [];
		if (info !== null) {
			fill =
				info.tokens === undefined
					? `${tokenCount(info.window)} window, no reply yet`
					: `${tokenCount(info.tokens)} / ${tokenCount(info.window)} tokens (${info.percent ?? 0}%)`;
			if (info.compactAt !== undefined) {
				fill += ` · compacts at ${tokenCount(info.compactAt)}`;
				const left = turnsLeft(samples, info.compactAt);
				if (left !== undefined) fill += `, ~${left} turns`;
			}
			if (info.usd !== undefined) spend.push(`$${info.usd.toFixed(2)}`);
			if (info.cacheRate !== undefined) spend.push(`cache ${info.cacheRate}%`);
			for (const limit of info.limits) {
				const reset =
					limit.resetsAt === undefined ? "" : resetLabel(limit.resetsAt, now);
				limits.push(
					`${limitLabel(limit.kind)} ${limit.percentUsed}%${reset === "" ? "" : `  ↻ ${reset}`}`,
				);
			}
		}

		// The context takes the rows it needs, at least its heading and its
		// bar. The parts under it keep at least the rows of their headings.
		const contextNeed =
			info === null
				? 2
				: 3 +
					(spend.length > 0 ? 1 : 0) +
					(limits.length > 0 ? 1 : 0) +
					(categories.length === 0
						? 0
						: 1 + (withCategories ? categories.length : 0));
		const contextRows = Math.min(
			contextNeed,
			Math.max(2, topRows - WORK_PARTS),
		);
		const workRows = topRows - contextRows;

		const contextPart = (
			<Box
				flexDirection="column"
				height={contextRows}
				flexShrink={0}
				overflow="hidden"
			>
				<Box flexDirection="row" height={1} gap={1}>
					{heading("Context", info?.model ?? "")}
					{isWarm && (
						<Box flexDirection="row" flexShrink={0}>
							<Button
								key="compact"
								label="Compact"
								onPress={async () => {
									$.ui.toast("Compacting the conversation");
									await $.session.compact();
								}}
							/>
						</Box>
					)}
				</Box>
				{info === null && <Text dimColor>No reading yet.</Text>}
				{info !== null && (
					<Text wrap="truncate-end">
						{parts.map((part, index) => (
							<Text color={part.color}>
								{part.glyph.repeat(cells[index] ?? 0)}
							</Text>
						))}
					</Text>
				)}
				{info !== null && <Text wrap="truncate-end">{fill}</Text>}
				{spend.length > 0 && (
					<Text dimColor wrap="truncate-end">
						{spend.join(" · ")}
					</Text>
				)}
				{limits.length > 0 && (
					<Box
						flexDirection="row"
						height={1}
						overflow="hidden"
						justifyContent="space-between"
					>
						{limits.map((limit) => (
							<Text dimColor wrap="truncate-end">
								{limit}
							</Text>
						))}
					</Box>
				)}
				{categories.length > 0 && (
					<Button
						key="categories"
						plain
						onPress={() => update($, showCategories, (value) => !value)}
					>
						<Text dimColor>{withCategories ? "▾ " : "▸ "}</Text>
						{"Categories"}
						<Text dimColor>{` ${categories.length}`}</Text>
					</Button>
				)}
				{withCategories &&
					categories.map((row) => (
						<Text wrap="truncate-end">
							<Text color={row.color}>{`  ${AREA[row.kind]} `}</Text>
							{cut(row.name, nameRoom).padEnd(nameRoom)}
							<Text dimColor>
								{`${tokenCount(row.tokens).padStart(7)}${share(row.tokens).padStart(7)}`}
							</Text>
						</Text>
					))}
			</Box>
		);

		// Each of the four parts gets its heading row, then an equal share of
		// the rows that are left, up to the rows that it needs. The files
		// show grouped by folder, and the git state takes one row under
		// their heading. An MCP server shows its tools unless the person
		// folded it.
		const gitRows = git === null ? 0 : 1;
		const allFileRows = fileRowsOf(fileList);
		const allMcpRows = mcpRowsOf(mcpList, closed);
		const otherNeeds = [
			1 + skillList.length,
			1 + allMcpRows.length,
			1 + gitRows + allFileRows.length,
		];
		// When the whole task list does not fit, the completed tasks hide
		// first. The rows that they free go to the other parts.
		const allTaskRows = taskRowsOf(taskList, agentList);
		let openTaskRows = allTaskRows;
		let shares = shareRows([1 + allTaskRows.length, ...otherNeeds], workRows);
		if ((shares[0] ?? 0) - 1 < allTaskRows.length) {
			openTaskRows = taskRowsOf(
				taskList.filter((task) => task.status !== "completed"),
				agentList,
			);
			shares = shareRows([1 + openTaskRows.length, ...otherNeeds], workRows);
		}
		const [taskRows = 0, skillRows = 0, mcpRows = 0, fileRows = 0] = shares;
		const done = taskList.filter((task) => task.status === "completed").length;
		const runningAgents = agentList.filter((one) => !one.isDone).length;
		const taskDetail: string[] = [];
		if (taskList.length > 0) taskDetail.push(`${done}/${taskList.length} done`);
		if (runningAgents > 0)
			taskDetail.push(
				`${runningAgents} ${runningAgents === 1 ? "agent" : "agents"} running`,
			);
		const shownTasks = fit(openTaskRows, taskRows - 1);

		// A count of uses or calls, right-aligned in the last six cells.
		const countCell = (n: number) => `×${n}`.padStart(6);
		const failedCell = (n: number) => (n > 0 ? ` ✗${n}` : "");
		const plural = (n: number, word: string) =>
			`${n} ${n === 1 ? word : `${word}s`}`;

		// Each skill reads its name, where it comes from, and its uses.
		const shownSkills = fit(skillList, skillRows - 1);
		const skillNames = shownSkills.kept.map(skillParts);
		const originRoom = Math.min(
			16,
			Math.max(0, ...skillNames.map((one) => one.origin.length)),
		);
		const skillRoom = Math.max(
			1,
			width - 6 - (originRoom > 0 ? originRoom + 1 : 0),
		);
		const skillLine = (skill: SkillUse, index: number) => {
			const { name, origin } = skillNames[index] ?? skillParts(skill);
			const originText =
				originRoom > 0 ? ` ${cut(origin, originRoom).padEnd(originRoom)}` : "";

			return (
				<Text wrap="truncate-end">
					{cut(name, skillRoom).padEnd(skillRoom)}
					<Text dimColor>{originText + countCell(skill.uses)}</Text>
				</Text>
			);
		};

		// A press on a server folds its tools away, or shows them again.
		const mcpCalls = mcpList.reduce(
			(sum, one) => sum + one.tools.reduce((all, t) => all + t.calls, 0),
			0,
		);
		const shownMcp = fit(allMcpRows, mcpRows - 1);
		const mcpLine = (row: McpRow) => {
			const failed = row.kind === "server" ? row.failed : row.tool.failed;
			const calls = row.kind === "server" ? row.calls : row.tool.calls;
			const tail = failedCell(failed);
			if (row.kind === "tool") {
				const room = Math.max(1, width - 4 - 6 - tail.length);

				return (
					<Text wrap="truncate-end">
						{`    ${cut(row.tool.name, room).padEnd(room)}`}
						{tail !== "" && <Text color="error">{tail}</Text>}
						<Text dimColor>{countCell(calls)}</Text>
					</Text>
				);
			}
			const room = Math.max(1, width - 2 - 6 - tail.length);

			return (
				<Button
					key={`mcp:${row.server}`}
					plain
					onPress={() =>
						update($, closedServers, (list) =>
							list.includes(row.server)
								? list.filter((one) => one !== row.server)
								: [...list, row.server],
						)
					}
				>
					<Text dimColor>{row.isOpen ? "▾ " : "▸ "}</Text>
					<Text weight="bold">{cut(row.server, room).padEnd(room)}</Text>
					{tail !== "" && <Text color="error">{tail}</Text>}
					<Text dimColor>{countCell(calls)}</Text>
				</Button>
			);
		};

		// A press on a file opens its diff in the lower half. A press on the
		// open file closes the diff.
		const gitShown = git !== null && fileRows > 1;
		const fileListRows = fileRows - 1 - (gitShown ? 1 : 0);
		const shownFiles = fitFiles(allFileRows, fileListRows);
		const fileRoom = Math.max(1, width - 2 - 6);
		const fileLine = (row: FileRow) => {
			if (row.kind === "dir") {
				return (
					<Text dimColor wrap="truncate-end">
						{cutStart(row.label, width)}
					</Text>
				);
			}
			const { file } = row;

			return (
				<Button
					key={`file:${file.path}`}
					plain
					onPress={() =>
						diff?.path === file.path
							? update($, fileDiff, () => null)
							: openDiff($, file)
					}
				>
					<Text weight={diff?.path === file.path ? "bold" : undefined}>
						{`  ${cut(row.name, fileRoom).padEnd(fileRoom)}`}
					</Text>
					<Text dimColor>{countCell(file.edits)}</Text>
				</Button>
			);
		};
		const gitLine = git !== null && (
			<Text dimColor wrap="truncate-end">{`⎇ ${gitLabel(git)}`}</Text>
		);

		// The tasks, the skills and the MCP servers start at the top. The
		// files end at the bottom, above the calls, and the free rows stay
		// between them.
		const workPart = (
			<Box
				flexDirection="column"
				height={workRows}
				flexShrink={0}
				overflow="hidden"
				justifyContent="space-between"
			>
				<Box flexDirection="column" flexShrink={0}>
					<Box flexDirection="row" height={1}>
						{heading(
							"Tasks",
							taskDetail.length === 0 ? "none" : taskDetail.join(" · "),
						)}
					</Box>
					{shownTasks.kept.map((row) =>
						row.kind === "agent" ? (
							<Text wrap="truncate-end">
								<Text dimColor>{"↳ "}</Text>
								{row.agent.label}
								<Text dimColor>
									{` ${row.agent.type} · ${row.agent.isDone ? "done" : "running"}`}
								</Text>
							</Text>
						) : (
							<Text wrap="truncate-end">
								{row.isNested ? "  " : ""}
								<Text color={TASK_COLOR[row.task.status]}>
									{`${TASK_GLYPH[row.task.status]} `}
								</Text>
								<Text
									dimColor={row.task.status === "completed"}
									weight={
										row.task.status === "in_progress" ? "bold" : undefined
									}
								>
									{row.task.subject}
								</Text>
							</Text>
						),
					)}
					{shownTasks.hidden > 0 && taskRows > 1 && (
						<Text dimColor>{`… ${shownTasks.hidden} more`}</Text>
					)}
					{skillRows > 0 && (
						<Box flexDirection="row" height={1}>
							{heading(
								"Skills",
								skillList.length === 0 ? "none" : `${skillList.length} used`,
							)}
						</Box>
					)}
					{shownSkills.kept.map(skillLine)}
					{shownSkills.hidden > 0 && skillRows > 1 && (
						<Text dimColor>{`… ${shownSkills.hidden} more`}</Text>
					)}
					{mcpRows > 0 && (
						<Box flexDirection="row" height={1}>
							{heading(
								"MCP",
								mcpList.length === 0
									? "none"
									: `${plural(mcpList.length, "server")} · ${plural(mcpCalls, "call")}`,
							)}
						</Box>
					)}
					{shownMcp.kept.map(mcpLine)}
					{shownMcp.hidden > 0 && mcpRows > 1 && (
						<Text dimColor>{`… ${shownMcp.hidden} more`}</Text>
					)}
				</Box>
				<Box flexDirection="column" flexShrink={0}>
					{fileRows > 0 && (
						<Box flexDirection="row" height={1}>
							{heading(
								"Files",
								fileList.length === 0 ? "none" : `${fileList.length} changed`,
							)}
						</Box>
					)}
					{gitShown && gitLine}
					{shownFiles.kept.map(fileLine)}
					{shownFiles.hidden > 0 && fileListRows > 0 && (
						<Text dimColor>{`… ${shownFiles.hidden} more`}</Text>
					)}
				</Box>
			</Box>
		);

		// While a subagent's transcript is in view, show only its calls. The
		// Failed filter shows only the calls that failed or were denied.
		const viewed = e.props.view.agentId;
		const inView =
			viewed === undefined
				? all
				: all.filter((entry) => isCall(entry) && entry.agentId === viewed);
		const isFailed = (entry: ActivityEntry) =>
			entry.kind === "call" &&
			(entry.status === "error" || entry.status === "denied");
		const shown = failedOnly ? inView.filter(isFailed) : inView;
		const calls = inView.filter(isCall);
		const running = calls.filter((call) => call.status === "running").length;
		const failed = calls.filter(isFailed).length;

		const counts = [`${calls.length} calls`];
		if (running > 0) counts.push(`${running} running`);

		// Each prompt's divider shows the time since the prompt before it.
		const sinceLast = new Map<string, number>();
		let lastAt: number | undefined;
		for (const entry of all) {
			if (entry.kind !== "turn") continue;
			if (entry.startedAt !== undefined && lastAt !== undefined)
				sinceLast.set(entry.id, entry.startedAt - lastAt);
			lastAt = entry.startedAt;
		}

		// An open shell call gets a button that puts its command in the prompt.
		const canCopy = (entry: ActivityCall) =>
			entry.tool === "Bash" && entry.command !== undefined;

		// An open call's lines, each one row, cut to fit the list together
		// with the call's own row, its button, and its margin.
		const detailOf = (entry: ActivityCall) => {
			const inner = width - LEAD;
			const lines: { text: string; isDim: boolean }[] = [];
			if (entry.startedAt !== undefined) {
				const span =
					entry.endedAt === undefined
						? clockTime(entry.startedAt)
						: `${clockTime(entry.startedAt)} – ${clockTime(entry.endedAt)}`;
				lines.push({ text: span, isDim: true });
			}
			for (const text of hardWrap(entry.command ?? entry.summary, inner))
				lines.push({ text, isDim: false });
			if (entry.result !== undefined) {
				for (const text of hardWrap(entry.result, inner))
					lines.push({ text, isDim: true });
			}
			const room = Math.max(1, listRows - 2 - (canCopy(entry) ? 1 : 0));
			if (lines.length <= room) return lines;
			const kept = lines.slice(0, room - 1);

			return [
				...kept,
				{ text: `… ${lines.length - kept.length} more lines`, isDim: true },
			];
		};

		// The number of rows that an entry takes in the list. Each line is cut
		// to one row.
		const rowsOf = (entry: ActivityEntry, openId = open): number => {
			if (entry.kind === "turn") return 2;
			if (entry.id === openId)
				return 2 + (canCopy(entry) ? 1 : 0) + detailOf(entry).length;

			return withResults && entry.result !== undefined ? 2 : 1;
		};

		// The window ends on the pinned entry, or on the newest one. It never
		// ends before `top`, the first entry that fills it from the start.
		const ids = shown.map((entry) => entry.id);
		const last = shown.length - 1;
		let top = last;
		let filled = 0;
		for (const [index, entry] of shown.entries()) {
			filled += rowsOf(entry);
			if (filled >= listRows) {
				top = index;
				break;
			}
		}
		layout = { ids, top, diffRows: listRows };
		const at = pinned === null ? -1 : ids.indexOf(pinned);
		const end = at < 0 ? last : Math.max(top, at);
		const newer = last - end;
		let start = end + 1;
		let drawn = 0;
		for (const entry of shown.slice(0, end + 1).reverse()) {
			if (drawn >= listRows) break;
			drawn += rowsOf(entry);
			start -= 1;
		}

		// An opened call whose lines would run past the top of the window
		// holds the window at itself. Closing it follows the newest again.
		const toggle = (entry: ActivityCall) => async () => {
			const openId = await update($, expanded, (id) =>
				id === entry.id ? null : entry.id,
			);
			if (openId === null) {
				await update($, anchor, (id) => (id === entry.id ? null : id));

				return;
			}
			const below = shown
				.slice(shown.indexOf(entry), end + 1)
				.reduce((sum, one) => sum + rowsOf(one, openId), 0);
			if (below > listRows) await update($, anchor, () => entry.id);
		};

		const listItems = shown.slice(start, end + 1).map((entry) => {
			if (entry.kind === "turn") {
				const gap = sinceLast.get(entry.id);
				const since = gap === undefined ? "" : ` +${duration(gap)}`;
				const head = `── ${clockTime(entry.startedAt)}${since} `;

				return (
					<Box marginTop={1} flexShrink={0}>
						<Text dimColor wrap="truncate-end">
							{head + cut(entry.text, width - head.length)}
						</Text>
					</Box>
				);
			}

			const isSub = entry.agentId !== undefined;
			const indent = isSub ? "↳ " : "";
			const took =
				entry.startedAt === undefined
					? ""
					: duration((entry.endedAt ?? now) - entry.startedAt);
			const lead = `${took.padStart(LEAD - 1)} `;
			const label = cut(
				toolLabel(entry.tool),
				Math.max(1, width - lead.length - indent.length - 2),
			);
			const room = width - lead.length - indent.length - 2 - label.length - 1;
			const isOpen = open === entry.id;

			return (
				<Box flexDirection="column" flexShrink={0}>
					<Button key={`call:${entry.id}`} plain onPress={toggle(entry)}>
						<Text dimColor>{lead}</Text>
						{indent}
						<Text color={COLOR[entry.status]}>{GLYPH[entry.status]} </Text>
						<Text weight="bold">{label}</Text>
						{` ${cut(entry.summary, room)}`}
					</Button>
					{withResults && !isOpen && entry.result !== undefined && (
						<Text dimColor wrap="truncate-end">
							{`${" ".repeat(LEAD)}⎿ ${cut(firstLine(entry.result), width - LEAD - 2)}`}
						</Text>
					)}
					{isOpen && (
						<Box flexDirection="column" marginLeft={LEAD} marginBottom={1}>
							{canCopy(entry) && (
								<Box flexDirection="row">
									<Button
										key={`prompt:${entry.id}`}
										label="Copy to prompt"
										onPress={async () => {
											await $.prompt.fill({ text: entry.command ?? "" });
											$.ui.toast("The command is in the prompt");
										}}
									/>
								</Box>
							)}
							{detailOf(entry).map((line) => (
								<Text dimColor={line.isDim} wrap="truncate-end">
									{line.text === "" ? " " : line.text}
								</Text>
							))}
						</Box>
					)}
				</Box>
			);
		});

		// An open diff takes the lower half in place of the calls.
		const changes = diff === null ? null : diffCounts(diff.lines);
		const diffHalf = diff !== null && changes !== null && (
			<Box flexDirection="column" height={lowRows} flexShrink={0}>
				<Box flexDirection="row" height={1} gap={1}>
					{heading(
						"Diff",
						`${cutStart(diff.label, Math.max(8, width - 32))} +${changes.added} −${changes.removed}`,
					)}
					<Box flexDirection="row" flexShrink={0}>
						<Button
							key="close-diff"
							label="Close"
							onPress={() => update($, fileDiff, () => null)}
						/>
					</Box>
				</Box>
				<Box flexDirection="column" height={listRows} overflow="hidden">
					{diff.lines.slice(diffAt, diffAt + listRows).map((line) => (
						<Text color={diffColor(line)} wrap="truncate-end">
							{line === "" ? " " : line}
						</Text>
					))}
				</Box>
			</Box>
		);

		const activityHalf = (
			<Box flexDirection="column" height={lowRows} flexShrink={0}>
				<Box flexDirection="row" height={1} gap={1}>
					{heading("Activity", counts.join(" · "))}
					<Box flexDirection="row" flexShrink={0} gap={1}>
						{(failed > 0 || failedOnly) && (
							<Button
								key="failed"
								label={failedOnly ? "All calls" : `${failed} failed`}
								onPress={async () => {
									await update($, onlyFailed, (value) => !value);
									await update($, anchor, () => null);
								}}
							/>
						)}
						{newer > 0 && (
							<Button
								key="newest"
								label={`↓ ${newer}`}
								onPress={() => update($, anchor, () => null)}
							/>
						)}
						<Button
							key="results"
							label={withResults ? "Hide results" : "Results"}
							onPress={() => update($, showResults, (value) => !value)}
						/>
						<Button
							key="clear"
							label="Clear"
							onPress={async () => {
								await update($, entries, () => []);
								await update($, anchor, () => null);
							}}
						/>
					</Box>
				</Box>
				<Box
					flexDirection="column"
					height={listRows}
					overflow="hidden"
					justifyContent={drawn > listRows ? "flex-end" : "flex-start"}
				>
					{shown.length === 0 && (
						<Text dimColor>
							{failedOnly ? "No failed calls." : "No tool calls yet."}
						</Text>
					)}
					{listItems}
				</Box>
			</Box>
		);

		return (
			<Box flexDirection="column">
				{contextPart}
				{workPart}
				{diffHalf || activityHalf}
			</Box>
		);
	});
};
