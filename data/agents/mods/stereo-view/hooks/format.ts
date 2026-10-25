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

/** Cuts text from the start, so the end of a path stays: `…/hooks/a.ts`. */
export function cutStart(text: string, width: number): string {
	if (width <= 0) return "";
	if (text.length <= width) return text;

	return `…${text.slice(text.length - Math.max(0, width - 1))}`;
}

// The arguments that hold a path, which a row names from its repository root.
const PATH_KEYS = ["file_path", "notebook_path", "path"];

function relative(path: string, roots: readonly string[]): string {
	// The deepest root wins, so a nested repository names its own files.
	const root = roots
		.filter((one) => path.startsWith(`${one}/`))
		.reduce((best, one) => (one.length > best.length ? one : best), "");

	return root === "" ? path : path.slice(root.length + 1);
}

function toolArgs(input: Record<string, unknown>): Record<string, unknown> {
	return Object.fromEntries(
		Object.entries(input).filter(([key]) => !RESERVED.has(key)),
	);
}

/** The absolute paths that a call's input names. */
export function pathsOf(input: Record<string, unknown>): string[] {
	const args = toolArgs(input);

	return PATH_KEYS.map((key) => args[key]).filter(
		(value): value is string =>
			typeof value === "string" && value.startsWith("/"),
	);
}

/**
 * One line that names what a call works on, from its input. A path shows
 * from the repository root that holds it, one of `roots`.
 */
export function summarize(
	input: Record<string, unknown>,
	roots: readonly string[],
): string {
	const args = toolArgs(input);

	if (Array.isArray(args.todos)) return `${args.todos.length} todos`;

	// A command's own description says what it is for, in fewer words.
	if (
		typeof args.command === "string" &&
		typeof args.description === "string"
	) {
		const line = firstLine(args.description);
		if (line !== "") return line;
	}

	for (const key of SUMMARY_KEYS) {
		const value = args[key];
		if (typeof value !== "string" || value === "") continue;
		const line = firstLine(value);
		const named = key.endsWith("path") ? relative(line, roots) : line;
		if (key === "pattern" && typeof args.path === "string") {
			return `${named} in ${relative(args.path, roots)}`;
		}

		return named;
	}

	const json = JSON.stringify(args);

	return json === "{}" ? "" : json;
}

/**
 * A short name for a tool: `mcp__linear__save_issue` reads `linear:save_issue`,
 * and a claude.ai connector's `mcp__claude_ai_Notion__notion-search` reads
 * `Notion:search`. Other tools keep their name.
 */
export function toolLabel(tool: string): string {
	if (!tool.startsWith("mcp__")) return tool;
	const rest = tool.slice("mcp__".length);
	const split = rest.indexOf("__");
	if (split < 0) return tool;
	const server = rest.slice(0, split).replace(/^claude_ai_/, "");
	let name = rest.slice(split + 2);
	// A tool that repeats its server's name drops it.
	const own = server.toLowerCase();
	const prefix = name.slice(0, own.length + 1).toLowerCase();
	if (prefix === `${own}-` || prefix === `${own}_`)
		name = name.slice(own.length + 1);

	return `${server}:${name}`;
}

/** The full command of a call, for its expanded row. */
export function commandOf(input: Record<string, unknown>): string | undefined {
	const { command } = toolArgs(input);

	return typeof command === "string" && command.trim() !== ""
		? command
		: undefined;
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

/** A short token count such as `850`, `3.1k`, `128k` or `1M`. */
export function tokenCount(n: number): string {
	if (n < 1000) return String(Math.round(n));
	if (n < 100_000) return `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k`;
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;

	return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
}

/** The short name of a rate-limit window: `five_hour` reads `5h`. */
export function limitLabel(kind: string): string {
	if (kind === "five_hour") return "5h";
	if (kind === "seven_day") return "7d";
	if (kind === "spend_limit") return "spend";

	return kind;
}

const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/**
 * When a rate-limit window resets, in local time: `18:00` within a day,
 * else `Fri 09:00`. Empty when the timestamp does not parse.
 */
export function resetLabel(iso: string, now: number): string {
	const at = Date.parse(iso);
	if (Number.isNaN(at)) return "";
	const date = new Date(at);
	const time = `${pad(date.getHours())}:${pad(date.getMinutes())}`;

	return at - now < 86_400_000 ? time : `${DAYS[date.getDay()]} ${time}`;
}

/**
 * How many more turns fit before auto-compaction at `compactAt`, from the
 * mean growth over the recent turns. Undefined when the context did not
 * grow or when there are fewer than two turns.
 */
export function turnsLeft(
	samples: readonly number[],
	compactAt: number,
): number | undefined {
	const first = samples[0];
	const last = samples.at(-1);
	if (samples.length < 2 || first === undefined || last === undefined)
		return undefined;
	const growth = (last - first) / (samples.length - 1);
	if (growth <= 0) return undefined;

	return Math.max(0, Math.floor((compactAt - last) / growth));
}

/**
 * The cells of a bar `width` wide that each part takes of `total`. Edges
 * round once, so the cells add up to the bar's filled width.
 */
export function barCells(
	parts: readonly number[],
	total: number,
	width: number,
): number[] {
	let sum = 0;
	let drawn = 0;

	return parts.map((part) => {
		if (total <= 0) return 0;
		sum += part;
		const edge = Math.min(width, Math.round((sum / total) * width));
		const cells = Math.max(0, edge - drawn);
		drawn += cells;

		return cells;
	});
}

/**
 * Splits text into lines of at most `width` characters, so each line takes
 * one row of the terminal. A tab counts as two spaces.
 */
export function hardWrap(text: string, width: number): string[] {
	const size = Math.max(1, width);

	return text
		.replaceAll("\t", "  ")
		.split("\n")
		.flatMap((line) => {
			if (line.length <= size) return [line];
			const parts: string[] = [];
			for (let at = 0; at < line.length; at += size)
				parts.push(line.slice(at, at + size));

			return parts;
		});
}
