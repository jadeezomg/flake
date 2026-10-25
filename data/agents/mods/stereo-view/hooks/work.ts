import type { FileChange, TaskItem, TaskStatus } from "../types";

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
