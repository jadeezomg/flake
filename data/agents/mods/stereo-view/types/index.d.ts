export type CallStatus = "running" | "done" | "error" | "denied";

/** One tool call in the Activity pane. */
export type ActivityCall = {
	kind: "call";
	id: string;
	tool: string;
	/** One line that names what the call does or works on (a description, a path). */
	summary: string;
	/** The full command, for calls that run one; the expanded row shows it. */
	command?: string;
	/** The loop the call ran in; absent on the main conversation. */
	agentId?: string;
	/** Milliseconds since the epoch; absent for calls read back on resume. */
	startedAt?: number;
	endedAt?: number;
	status: CallStatus;
	/** The result as the model read it, cut to a fixed length. */
	result?: string;
};

/** A divider that marks where the person sent a prompt. */
export type ActivityTurn = {
	kind: "turn";
	id: string;
	text: string;
	/** Milliseconds since the epoch; absent for prompts read back on resume. */
	startedAt?: number;
};

export type ActivityEntry = ActivityCall | ActivityTurn;

/** One category of the context window, as /context lists it. */
export type ContextRow = {
	name: string;
	tokens: number;
	/** The theme color of the category in /context. */
	color: string;
	kind: "used" | "free" | "buffer";
};

/** The context window as the pane last read it. */
export type ContextInfo = {
	/** The model that the breakdown is for. Absent without a breakdown. */
	model?: string;
	/** Input tokens of the last response. Absent before the first response. */
	tokens?: number;
	/** The model's context window, in tokens. */
	window: number;
	/** `tokens` over `window`, 0 to 100. */
	percent?: number;
	/** The window that the rows measure against: the compaction window. */
	rowsWindow?: number;
	/** The window by category, estimated. Empty when there is no breakdown. */
	rows: ContextRow[];
	/**
	 * The token count at which auto-compaction starts. Absent when
	 * auto-compaction is off.
	 */
	compactAt?: number;
	/** What the session has cost so far, in US dollars. */
	usd?: number;
	/**
	 * The share of the last input that came from the prompt cache, 0 to 100.
	 * Absent before the first response.
	 */
	cacheRate?: number;
	/**
	 * Each rate-limit window, such as `five_hour`: how much of it is used,
	 * and when it resets, as an ISO 8601 timestamp.
	 */
	limits: { kind: string; percentUsed: number; resetsAt?: string }[];
};

export type TaskStatus = "pending" | "in_progress" | "completed";

/** One item of a task list. */
export type TaskItem = {
	/** The task id, or `todo:<agent>:<index>` for an item of TodoWrite. */
	id: string;
	subject: string;
	status: TaskStatus;
	/** The subagent that wrote the task; absent for the main conversation. */
	agentId?: string;
};

/** A subagent that wrote tasks, as the Tasks list labels it. */
export type AgentLabel = {
	id: string;
	/** The description that the Agent call gave. */
	label: string;
	/** The agent type, such as `Explore`. */
	type: string;
	isDone: boolean;
};

/** One file that a tool changed in this session. */
export type FileChange = {
	/** The absolute path. */
	path: string;
	/** The path from its repository root, as the Activity rows show it. */
	label: string;
	/** How many successful calls changed the file. */
	edits: number;
};

/** The git state of the folder that the session runs in. */
export type GitState = {
	/** The branch, or `(detached)`. */
	branch: string;
	/** Commits that the upstream does not have. */
	ahead: number;
	/** Commits of the upstream that the branch does not have. */
	behind: number;
	/** Files with changes that are not committed, untracked files included. */
	changed: number;
	/** Of those, the files with staged changes. */
	staged: number;
};

/** The diff of one changed file, as the lower half shows it. */
export type FileDiff = {
	path: string;
	label: string;
	lines: string[];
};

declare module "claude-code" {
	interface PluginState {
		"stereo-view": {
			entries: ActivityEntry[];
			isSplit: boolean;
			expanded: string | null;
			showResults: boolean;
			context: ContextInfo | null;
			/** The newest entry that the list shows. When null, the list follows the newest call. */
			anchor: string | null;
			tasks: TaskItem[];
			agents: AgentLabel[];
			/** The changed files, the most recent first. */
			files: FileChange[];
			/** When true, the context shows one row for each category. */
			showCategories: boolean;
			/** Input tokens after each recent turn, for the turns until compaction. */
			turnTokens: number[];
			git: GitState | null;
			/** The diff that the lower half shows in place of the calls. */
			fileDiff: FileDiff | null;
			/** The first diff line that the lower half shows. */
			diffScroll: number;
			/** When true, the call list shows only failed and denied calls. */
			onlyFailed: boolean;
		};
	}
}
