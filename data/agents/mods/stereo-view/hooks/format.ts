// Keys that the engine adds beside a tool's own arguments.
const RESERVED = new Set([
	"tool",
	"tool_use_id",
	"agentId",
	"requestMeta",
	"consent",
]);

// The argument that best names what a call works on, in order of preference.
const SUMMARY_KEYS = [
	"command",
	"file_path",
	"notebook_path",
	"path",
	"pattern",
	"url",
	"query",
	"description",
	"skill",
	"prompt",
];

export function firstLine(text: string): string {
	const line = text.split("\n").find((one) => one.trim() !== "") ?? "";

	return line.trim();
}

export function cut(text: string, width: number): string {
	if (width <= 0) return "";
	if (text.length <= width) return text;

	return `${text.slice(0, Math.max(0, width - 1))}…`;
}

function relative(path: string, cwd: string): string {
	if (cwd !== "" && path.startsWith(`${cwd}/`))
		return path.slice(cwd.length + 1);

	return path;
}

/** One line that names what a call works on, from its input. */
export function summarize(input: Record<string, unknown>, cwd: string): string {
	const args = Object.fromEntries(
		Object.entries(input).filter(([key]) => !RESERVED.has(key)),
	);

	if (Array.isArray(args.todos)) return `${args.todos.length} todos`;

	for (const key of SUMMARY_KEYS) {
		const value = args[key];
		if (typeof value !== "string" || value === "") continue;
		const line = firstLine(value);
		const named = key.endsWith("path") ? relative(line, cwd) : line;
		if (key === "pattern" && typeof args.path === "string") {
			return `${named} in ${relative(args.path, cwd)}`;
		}

		return named;
	}

	const json = JSON.stringify(args);

	return json === "{}" ? "" : json;
}

function pad(n: number): string {
	return String(n).padStart(2, "0");
}

/** `HH:mm:ss` in local time, or `--:--:--` when the time is unknown. */
export function clockTime(at: number | undefined): string {
	if (at === undefined) return "--:--:--";
	const date = new Date(at);

	return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

/** A short duration such as `850ms`, `4.2s` or `3m10s`. */
export function duration(ms: number): string {
	if (ms < 1000) return `${Math.round(ms)}ms`;
	if (ms < 60_000) return `${(ms / 1000).toFixed(1)}s`;
	const minutes = Math.floor(ms / 60_000);

	return `${minutes}m${pad(Math.round((ms % 60_000) / 1000))}s`;
}
