// @ts-check
// Puts an `@path[:line]` mention in an agent's prompt without submitting it: through the
// clipboard and terminal.paste (hc send always presses Enter). The clipboard is put back.
// Identical copies live in jm-changes, jm-files and jm-agent-pick: mods can't import
// from another mod's folder (not even through a symlink).

import { agents, exec, focused, notify, openOverlay, panes, run } from "herdr";

const TITLE = "Send to agent";

/**
 * The agents a mention can go to: the focused tab's, else the focused space's. The focused
 * agent comes first, then the most recently active.
 * @returns {import("herdr").AgentInfo[]}
 */
export function candidates() {
  const f = focused(), all = agents();
  const mine = [f?.agent, f?.shown, f?.terminal].filter(Boolean);
  const order = (/** @type {import("herdr").AgentInfo[]} */ list) =>
    list.sort((a, b) => Number(mine.includes(b.address)) - Number(mine.includes(a.address)) || b.seq - a.seq);
  const inTab = all.filter((a) => a.tab === f?.tab);
  if (inTab.length) {
    return order(inTab);
  }
  return order(all.filter((a) => a.space === f?.space));
}

/**
 * The path as the agent should see it: relative to its folder when inside it.
 * @param {string} absolute
 * @param {string} terminal
 * @returns {string}
 */
export function agentPath(absolute, terminal) {
  const cwd = panes().find((p) => p.terminal === terminal)?.cwd?.replace(/\/$/, "");
  if (cwd && absolute.startsWith(cwd + "/")) {
    return absolute.slice(cwd.length + 1);
  }
  return absolute;
}

/**
 * Pastes `@<path>[:line]<suffix> ` into that agent's prompt and focuses it.
 * @param {string} terminal
 * @param {{ path: string, line?: number | string | null, suffix?: string }} mention path is absolute
 * @returns {Promise<void>}
 */
export async function pasteMention(terminal, { path, line = null, suffix = "" }) {
  const text = `@${agentPath(path, terminal)}${line ? `:${line}` : ""}${suffix} `;
  const saved = (await exec("pbpaste")).stdout;
  await exec("sh", ["-c", 'printf %s "$1" | pbcopy', "sh", text]);
  run("pane.focus", { terminal });
  run("terminal.paste");
  await exec("sh", ["-c", 'printf %s "$1" | pbcopy', "sh", saved]);
}

/**
 * Mentions a file in the agent of this tab (or space); asks which one when there are several.
 * @param {string} path absolute
 * @param {number | string | null} [line] e.g. 12 or "12-20"
 * @param {string} [suffix] text after the reference, e.g. what a removed line was
 * @returns {Promise<void>}
 */
export async function mentionInAgent(path, line = null, suffix = "") {
  try {
    const list = candidates(), mention = { path, line, suffix };
    if (!list.length) {
      notify({ title: TITLE, body: "No agent in this tab or space.", level: "warning" });
    } else if (list.length === 1) {
      await pasteMention(list[0].address, mention);
    } else {
      openOverlay({ mod: "jm-agent-pick", kind: "popup", width: 380, height: Math.min(420, 52 + list.length * 40), props: { mention } });
    }
  } catch (e) {
    notify({ title: TITLE, body: String(e), level: "error" });
  }
}
