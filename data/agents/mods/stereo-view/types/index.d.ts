export type CallStatus = "running" | "done" | "error" | "denied";

/** One tool call in the Activity pane. */
export type ActivityCall = {
	kind: "call";
	id: string;
	tool: string;
	/** One line that names what the call works on (a command, a path). */
	summary: string;
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

declare module "claude-code" {
	interface PluginState {
		"stereo-view": {
			entries: ActivityEntry[];
			isSplit: boolean;
			expanded: string | null;
			showResults: boolean;
		};
	}
}
