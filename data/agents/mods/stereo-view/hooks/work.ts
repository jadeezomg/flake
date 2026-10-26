import type {
	FileChange,
	McpServerUse,
	McpToolUse,
	SkillUse,
	TaskItem,
	TaskStatus,
} from "../types";
import { mcpParts } from "./format";

/** The tools that change the task list. */
export const TASK_TOOLS = new Set([
	"TodoWrite",
	"TaskCreate",
	"TaskUpdate",
	"TaskList",
]);

/** The tools that change a file. */
export const FILE_TOOLS = new Set([
	"Edit",
	"MultiEdit",
	"Write",
	"NotebookEdit",
]);

const MAX_FILES = 200;

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

function statusOf(value: unknown): TaskStatus | undefined {
	return value === "pending" || value === "in_progress" || value === "completed"
		? value
		: undefined;
}

/**
 * The task list after a successful call of `tool` by `agentId` (absent for
 * the main conversation). TodoWrite gives the whole list of that agent.
 * The Task tools share one list: a new task goes to the agent that made it,
 * and an update finds the task by its id in any agent's group.
 */
export function nextTasks(
	list: readonly TaskItem[],
	tool: string,
	input: Record<string, unknown>,
	result: unknown,
	agentId?: string,
): TaskItem[] {
	const isOwn = (task: TaskItem) => task.agentId === agentId;
	const owner = agentId === undefined ? {} : { agentId };

	if (tool === "TodoWrite" && Array.isArray(input.todos)) {
		const todos = input.todos.flatMap((todo: unknown, index) => {
			if (!isRecord(todo) || typeof todo.content !== "string") return [];
			const status = statusOf(todo.status) ?? "pending";
			const id = `todo:${agentId ?? "main"}:${index}`;

			return [{ id, subject: todo.content, status, ...owner }];
		});

		return [...list.filter((task) => !isOwn(task)), ...todos];
	}
	if (tool === "TaskList" && isRecord(result) && Array.isArray(result.tasks)) {
		const listed = new Map<string, TaskItem>();
		for (const task of result.tasks as unknown[]) {
			if (!isRecord(task)) continue;
			const { id, subject } = task;
			if (typeof id !== "string" || typeof subject !== "string") continue;
			const status = statusOf(task.status) ?? "pending";
			listed.set(id, { id, subject, status });
		}
		// A task of the caller that the list leaves out is gone.
		const kept = list.flatMap((task) => {
			const now = listed.get(task.id);
			if (now !== undefined) return [{ ...task, ...now }];
			const isGone = isOwn(task) && !task.id.startsWith("todo:");

			return isGone ? [] : [task];
		});
		const known = new Set(list.map((task) => task.id));
		const added = [...listed.values()]
			.filter((task) => !known.has(task.id))
			.map((task) => ({ ...task, ...owner }));

		return [...kept, ...added];
	}
	if (tool === "TaskCreate" && isRecord(result) && isRecord(result.task)) {
		const { id, subject } = result.task;
		if (typeof id !== "string" || typeof subject !== "string") return [...list];
		const task: TaskItem = { id, subject, status: "pending", ...owner };

		return [...list.filter((one) => one.id !== id), task];
	}
	const id = input.taskId;
	if (tool === "TaskUpdate" && typeof id === "string") {
		if (isRecord(result) && result.success === false) return [...list];
		if (input.status === "deleted")
			return list.filter((task) => task.id !== id);
		const subject = input.subject;
		const status = statusOf(input.status);

		return list.map((task) =>
			task.id !== id
				? task
				: {
						...task,
						subject: typeof subject === "string" ? subject : task.subject,
						status: status ?? task.status,
					},
		);
	}

	return [...list];
}

/** The changed files after one more change of `path`, the most recent first. */
export function nextFiles(
	list: readonly FileChange[],
	path: string,
	label: string,
): FileChange[] {
	const edits = (list.find((file) => file.path === path)?.edits ?? 0) + 1;

	return [
		{ path, label, edits },
		...list.filter((file) => file.path !== path),
	].slice(0, MAX_FILES);
}

/** One row of the Files list: a folder, or a file under it. */
export type FileRow =
	| { kind: "dir"; dir: string; label: string }
	| { kind: "file"; file: FileChange; name: string };

/**
 * The changed files grouped by folder. A folder row names the folder from
 * its repository root, `./` for the root itself. The folder with the newest
 * change comes first, and in a folder the newest change comes first.
 */
export function fileRowsOf(list: readonly FileChange[]): FileRow[] {
	const groups = new Map<string, { label: string; files: FileChange[] }>();
	for (const file of list) {
		const dir = file.path.slice(0, file.path.lastIndexOf("/") + 1);
		const split = file.label.lastIndexOf("/");
		const label = split < 0 ? "./" : file.label.slice(0, split + 1);
		const group = groups.get(dir) ?? { label, files: [] };
		group.files.push(file);
		groups.set(dir, group);
	}

	return [...groups.entries()].flatMap(([dir, group]): FileRow[] => [
		{ kind: "dir", dir, label: group.label },
		...group.files.map(
			(file): FileRow => ({
				kind: "file",
				file,
				name: file.label.slice(file.label.lastIndexOf("/") + 1),
			}),
		),
	]);
}

/**
 * The file rows that fit in `room` rows, as `fit` keeps them, but a folder
 * row never ends the kept rows. `hidden` counts the files that do not fit.
 */
export function fitFiles(
	rows: readonly FileRow[],
	room: number,
): { kept: readonly FileRow[]; hidden: number } {
	const { kept } = fit(rows, room);
	let end = kept.length;
	while (end > 0 && kept[end - 1]?.kind === "dir") end -= 1;
	const shown = kept.slice(0, end);
	const isFile = (row: FileRow) => row.kind === "file";

	return {
		kept: shown,
		hidden: rows.filter(isFile).length - shown.filter(isFile).length,
	};
}

/** One skill of the session's skill listing. */
export type ListedSkill = { name: string; source: string; pluginName?: string };

/**
 * The listed skill that `name` names, with or without its plugin prefix,
 * or undefined when the listing does not hold it.
 */
export function matchSkill(
	listed: readonly ListedSkill[],
	name: string,
): ListedSkill | undefined {
	return (
		listed.find((one) => one.name === name) ??
		listed.find(
			(one) =>
				one.pluginName !== undefined &&
				one.name === `${one.pluginName}:${name}`,
		)
	);
}

const MAX_SKILLS = 200;

/**
 * The skills after one more use of `used`, the most recent first. A use
 * that knows its source fills in the source of a skill read back on resume.
 */
export function nextSkills(
	list: readonly SkillUse[],
	used: { name: string; source: string; pluginName?: string },
): SkillUse[] {
	const old = list.find((one) => one.name === used.name);
	const pluginName = used.pluginName ?? old?.pluginName;
	const skill: SkillUse = {
		name: used.name,
		source: used.source === "" ? (old?.source ?? "") : used.source,
		uses: (old?.uses ?? 0) + 1,
		...(pluginName === undefined ? {} : { pluginName }),
	};

	return [skill, ...list.filter((one) => one.name !== used.name)].slice(
		0,
		MAX_SKILLS,
	);
}

const MAX_SERVERS = 50;
const MAX_SERVER_TOOLS = 100;

/**
 * The MCP servers after one more call of `tool`, the most recently called
 * server and tool first. A tool that is not an MCP tool changes nothing.
 */
export function nextMcp(
	list: readonly McpServerUse[],
	tool: string,
	isFailed: boolean,
): McpServerUse[] {
	const parts = mcpParts(tool);
	if (parts === undefined) return [...list];
	const server = list.find((one) => one.server === parts.server);
	const old = server?.tools.find((one) => one.name === parts.name);
	const called: McpToolUse = {
		name: parts.name,
		calls: (old?.calls ?? 0) + 1,
		failed: (old?.failed ?? 0) + (isFailed ? 1 : 0),
	};
	const others = (server?.tools ?? []).filter((one) => one.name !== parts.name);

	return [
		{
			server: parts.server,
			tools: [called, ...others].slice(0, MAX_SERVER_TOOLS),
		},
		...list.filter((one) => one.server !== parts.server),
	].slice(0, MAX_SERVERS);
}

/** One row of the MCP list: a server with its totals, or one of its tools. */
export type McpRow =
	| {
			kind: "server";
			server: string;
			calls: number;
			failed: number;
			isOpen: boolean;
	  }
	| { kind: "tool"; server: string; tool: McpToolUse };

/** Each server's row, with its tools under it unless it is in `closed`. */
export function mcpRowsOf(
	list: readonly McpServerUse[],
	closed: readonly string[],
): McpRow[] {
	return list.flatMap((one): McpRow[] => {
		const isOpen = !closed.includes(one.server);
		const sum = (pick: (tool: McpToolUse) => number) =>
			one.tools.reduce((total, tool) => total + pick(tool), 0);
		const head: McpRow = {
			kind: "server",
			server: one.server,
			calls: sum((tool) => tool.calls),
			failed: sum((tool) => tool.failed),
			isOpen,
		};
		if (!isOpen) return [head];

		return [
			head,
			...one.tools.map(
				(tool): McpRow => ({ kind: "tool", server: one.server, tool }),
			),
		];
	});
}

/**
 * Shares `room` rows among parts that need `needs` rows each. Each part
 * first gets one row for its heading, in order, while rows are left. Then
 * the parts that need more get equal shares of the rest, until no part
 * needs more or no row is left.
 */
export function shareRows(needs: readonly number[], room: number): number[] {
	let left = Math.max(0, room);
	const rows = needs.map((need): number => {
		const heading = need > 0 && left > 0 ? 1 : 0;
		left -= heading;

		return heading;
	});
	const wantOf = (index: number) => (needs[index] ?? 0) - (rows[index] ?? 0);
	for (;;) {
		const open = rows.flatMap((_, index) => (wantOf(index) > 0 ? [index] : []));
		if (open.length === 0 || left === 0) break;
		const share = Math.max(1, Math.floor(left / open.length));
		for (const index of open) {
			const give = Math.min(share, wantOf(index), left);
			rows[index] = (rows[index] ?? 0) + give;
			left -= give;
		}
	}

	return rows;
}

/**
 * The items that fit in `room` rows. When some do not fit, the last row
 * goes to a line that counts the others, so `kept` is one shorter.
 */
export function fit<T>(
	items: readonly T[],
	room: number,
): { kept: readonly T[]; hidden: number } {
	if (items.length <= room) return { kept: items, hidden: 0 };
	const kept = items.slice(0, Math.max(0, room - 1));

	return { kept, hidden: items.length - kept.length };
}
