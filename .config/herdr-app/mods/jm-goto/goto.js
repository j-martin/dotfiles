// @ts-check
// The rows of the jm-goto picker: every space, its tabs and their panes, and the filter over them.

/**
 * @typedef {{ kind: "space", id: string, depth: 0, label: string, detail: string, status: string | null, active: boolean, text: string }} SpaceRow
 * @typedef {{ kind: "tab", id: string, space: string, depth: 1, label: string, detail: string, status: string | null, active: boolean, text: string }} TabRow
 * @typedef {{ kind: "pane", id: string, space: string, tab: string, depth: 2, label: string, title: string, detail: string, status: string | null, active: boolean, program: any, text: string }} PaneRow
 * @typedef {SpaceRow | TabRow | PaneRow} Row
 */

/**
 * The session summary agents put in the terminal title, without the agent name or status symbol.
 * @param {string | null | undefined} title
 * @returns {string}
 */
export const cleanTitle = (title) =>
  (title || "")
    .replace(/\s+-\s+GitHub Copilot$/, "")
    .replace(/^[^\p{L}\p{N}\p{P}\s]+\s*/u, "")
    .trim();

/**
 * A folder with the home folder shown as `~`.
 * @param {string | null | undefined} cwd
 * @param {string} home
 * @returns {string}
 */
export const shortPath = (cwd, home) => {
  if (!cwd) {
    return "";
  }
  if (cwd === home) {
    return "~";
  }
  return cwd.startsWith(home + "/") ? "~" + cwd.slice(home.length) : cwd;
};

/** The label the zsh `preexec` hook (`~/.config/shell/functions/herdr`) sets on its terminal. */
export const LAST_COMMAND = "jm.last-command";

/**
 * What a pane shows: its agent (or executable, or mod), its session title (or a shell's last
 * command), and where it runs.
 * @param {any} p a `panes()` entry
 * @param {string} home
 * @param {string} [lastCommand] the command its shell last ran
 * @returns {{ label: string, title: string, detail: string }}
 */
export const describePane = (p, home, lastCommand = "") => {
  if (!p.terminal) {
    return { label: p.name || p.mod || p.title || "mod", title: "", detail: "mod" };
  }
  const program = p.program?.name || "shell";
  const label = p.name ? `${p.name} · ${program}` : program;
  const raw = p.program?.agent ? cleanTitle(p.title) : (p.title || "").trim();
  const where = shortPath(p.cwd, home);
  const repeats = raw === program || raw === p.name || (where && !p.program?.agent && (raw.endsWith(where) || raw.endsWith(p.cwd ?? "")));
  const title = p.program?.shell && lastCommand ? `$ ${lastCommand}` : repeats ? "" : raw;
  const detail = p.branch ? `${where} (${p.branch})` : where;
  return { label, title, detail };
};

/**
 * Every space, then each of its tabs, then each tab's panes, in order.
 * @param {any[]} spaces `spaces()`
 * @param {any[]} panes `panes()`
 * @param {string} home
 * @param {any[]} [terminals] `terminals()`, for the shells' last commands
 * @returns {Row[]}
 */
export const buildRows = (spaces, panes, home, terminals = []) => {
  const last = new Map(terminals.map((t) => [t.address, t.labels?.[LAST_COMMAND] ?? ""]));
  /** @type {Row[]} */
  const rows = [];
  for (const s of spaces) {
    const where = [s.machine, s.branch].filter(Boolean).join(" · ");
    const spaceText = [s.name, where].join(" ");
    rows.push({ kind: "space", id: s.id, depth: 0, label: s.name, detail: where, status: s.status, active: s.active, text: spaceText });
    for (const t of s.tabs) {
      const own = panes.filter((p) => p.tab === t.id);
      const agents = [...new Set(own.filter((p) => p.program?.agent).map((p) => p.program.name))];
      rows.push({
        kind: "tab",
        id: t.id,
        space: s.id,
        depth: 1,
        label: t.name,
        detail: `${own.length} pane${own.length === 1 ? "" : "s"}`,
        status: t.status,
        active: s.active && t.active,
        text: [spaceText, t.name, ...agents].join(" "),
      });
      for (const p of own) {
        const d = describePane(p, home, last.get(p.terminal));
        rows.push({
          kind: "pane",
          id: p.pane,
          space: s.id,
          tab: t.id,
          depth: 2,
          ...d,
          status: p.status,
          active: s.active && t.active && p.focused,
          program: p.program,
          text: [spaceText, t.name, d.label, d.title, d.detail].join(" "),
        });
      }
    }
  }
  return rows;
};

/**
 * The rows matching every word of the query (in their own text, which includes their space's and
 * tab's), each with the space and tab it's in.
 * @param {Row[]} rows
 * @param {string} query
 * @returns {Row[]}
 */
export const filterRows = (rows, query) => {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length) {
    return rows;
  }
  const keep = new Set();
  for (const r of rows) {
    const text = r.text.toLowerCase();
    if (!words.every((w) => text.includes(w))) {
      continue;
    }
    keep.add(r.id);
    if (r.kind !== "space") {
      keep.add(r.space);
    }
    if (r.kind === "pane") {
      keep.add(r.tab);
    }
  }
  return rows.filter((r) => keep.has(r.id));
};
