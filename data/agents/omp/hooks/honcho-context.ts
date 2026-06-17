// Honcho shared-memory context injector for oh-my-pi (omp).
//
// Injects synthesized "what we know about the user" context before each agent
// run, joining the same `jadee` Honcho workspace as Claude Code and hermes so
// all agents share one memory. This is the omp-native equivalent of the
// claude-honcho plugin's SessionStart/UserPromptSubmit auto-injection.
//
// Dependency-free on purpose: uses bun's global `fetch` against Honcho's /v3
// REST API directly (the official @honcho-ai/mcp server targets /v2 and is
// incompatible with the self-hosted v3 instance). No node_modules to package.
//
// Fail-open: any error (Honcho unreachable, timeout, non-200) silently skips
// injection so omp is never blocked by the memory layer.
//
// Endpoint/identity default to the mini deployment but can be overridden via
// env (HONCHO_ENDPOINT / HONCHO_WORKSPACE / HONCHO_PEER_NAME).

// Minimal ambient for the bun runtime (avoids a @types/node dependency).
declare const process: { env: Record<string, string | undefined> };

interface HookAPI {
	on(
		event: string,
		handler: (
			event: { prompt?: string },
			ctx: unknown,
		) => Promise<unknown> | unknown,
	): void;
}

const ENDPOINT =
	process.env.HONCHO_ENDPOINT ?? "https://mini.quokka-qilin.ts.net:8100";
const API_KEY = process.env.HONCHO_API_KEY ?? "sk-no-auth";
const WORKSPACE = process.env.HONCHO_WORKSPACE ?? "jadee";
const USER_PEER = process.env.HONCHO_PEER_NAME ?? "jadee";
const TIMEOUT_MS = Number(process.env.HONCHO_TIMEOUT_MS ?? "4000");

// Query Honcho's dialectic endpoint for a synthesized representation of the user.
async function dialectic(query: string): Promise<string | null> {
	const url = `${ENDPOINT}/v3/workspaces/${WORKSPACE}/peers/${USER_PEER}/chat`;
	const ac = new AbortController();
	const timer = setTimeout(() => ac.abort(), TIMEOUT_MS);
	try {
		const res = await fetch(url, {
			method: "POST",
			headers: {
				"content-type": "application/json",
				authorization: `Bearer ${API_KEY}`,
			},
			body: JSON.stringify({ query, reasoning_level: "low" }),
			signal: ac.signal,
		});
		if (!res.ok) return null;
		const data = (await res.json().catch(() => null)) as {
			content?: unknown;
		} | null;
		const content = data?.content;
		return typeof content === "string" && content.trim()
			? content.trim()
			: null;
	} catch {
		return null;
	} finally {
		clearTimeout(timer);
	}
}

export default function hook(pi: HookAPI): void {
	pi.on("before_agent_start", async (event) => {
		const prompt = (event?.prompt ?? "").slice(0, 4000);
		const query = prompt
			? `Given the user's current request, what context about this user is most relevant right now? Prioritize active context over biography. Request: ${prompt}`
			: "Who is this user? Summarize their preferences, goals, and working style for an AI coding assistant.";

		const memory = await dialectic(query);
		if (!memory) return {};

		return {
			message: {
				customType: "honcho-memory",
				content:
					`<memory-context>\n${memory}\n</memory-context>\n` +
					"(Background context from shared Honcho memory about the user — not new user input.)",
				display: false,
				attribution: "agent",
			},
		};
	});
}
