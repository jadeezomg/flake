import { expect, test } from "claude-code/testing";

import type { TaskItem } from "../types";
import { nextTasks } from "../hooks/work";

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
