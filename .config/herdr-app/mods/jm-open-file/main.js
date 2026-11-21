// Opens the file named by the focused terminal's selection: with ~/.bin/editor at the
// line when the selection has one or for a folder (dired), else with the macOS default app.
// cmd-o (mod.open:jm-open-file), the jm-menu right-click item "Open file", and cmd-click
// (Hammerspoon's apps/herdr.lua double-clicks the word, then presses cmd-o).
// The selected word is tried first, then its whole line, e.g.:
//   diff --git a/.config/mise/conf.d/bootstrap.toml b/.config/mise/conf.d/bootstrap.toml
//   --- a/foo.txt / +++ b/foo.txt      (git diff)
//   foo/bar.lua | 12 +++---            (git log --stat, also with .../ abbreviation)
//   modified:   foo/bar.lua            (git status)
//   foo/bar.lua --- Lua                (difftastic)
//   foo/bar.lua:12:3: error            (compilers; editor at line 12, column 3)
//   AGENTS.md:53:- text                (grep match; editor at line 53)
//   AGENTS.md-51-- text                (grep context; editor at line 51)
//   @~/foo/bar.sh#L136-159             (agent file mention; editor at line 136)
// Paths are tried as given and without an agent's @ or git's a/ b/ (i/ w/ c/ o/) prefixes, against the
// terminal's folder, its git root and home.

import { View, div } from "gpui-kit";
import { props, run, exec, focused, closeOverlay, notify, terminals } from "herdr";

// `path:12:`, `path-12-`, `path:12:3:`, or a trailing `path:12[:3]`, in s.
function located(s) {
  const out = [];
  for (const m of s.matchAll(/([:-])(\d+)\1(?:(\d+)\1)?/g))
    if (m.index > 0) out.push({ path: s.slice(0, m.index), line: m[2], col: m[1] === ":" ? m[3] : undefined });
  const end = s.match(/:(\d+)(?::(\d+))?$/);
  if (end && end.index > 0) out.push({ path: s.slice(0, end.index), line: end[1], col: end[2] });
  const anchor = s.match(/#L(\d+)(?:C(\d+))?(?:-L?\d+(?:C\d+)?)?$/);
  if (anchor && anchor.index > 0) out.push({ path: s.slice(0, anchor.index), line: anchor[1], col: anchor[2] });
  return out;
}

// s without ANSI/OSC escapes, invisible or invalid characters (e.g. a terminal's U+FFFD).
function visible(s) {
  return s
    .replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-9;?]*[A-Za-z]/g, "")
    .replace(/[\uFFFD\p{Cc}\p{Cf}\p{Co}\p{Cs}]/gu, (c) => (c === "\n" || c === "\t" ? c : ""));
}

// s without escapes and surrounding quotes, brackets and punctuation.
function trimmed(s) {
  return visible(s).replace(/^["'`(<\[]+|["'`)>\],;:.!?]+$/g, "");
}

// Candidate {path, line?, col?} in a selection, best first.
function candidates(text) {
  const line = visible(text).trim().split("\n")[0].trim();
  const named = [
    /^diff --git "?\S\/(.+?)"? "?\S\/(.+?)"?$/,
    /^(?:---|\+\+\+) "?(.+?)"?(?:\t.*)?$/,
    /^(?:rename|copy) (?:from|to) (.+)$/,
    /^(?:modified|new file|deleted|renamed|copied|typechange|both modified|both added):\s+(?:.+ -> )?(.+)$/,
    /^(.+?)\s+\|\s+(?:\d+|Bin)/,
    /^(.+?) --- \S/,
  ];
  const found = [...located(line)];
  for (const re of named) {
    const m = line.match(re);
    if (m) found.push(...m.slice(1).reverse().filter(Boolean).map((path) => ({ path })));
  }
  const tokens = line.split(/\s+/).map(trimmed);
  found.push(...tokens.flatMap(located), ...tokens.map((path) => ({ path })));
  const out = [];
  for (const c of found) {
    const p = trimmed(c.path);
    if (!p || p === "/dev/null" || p.startsWith("-") || /^[-+@|]+$/.test(p) || /^[a-z]+:\/\//.test(p)) continue;
    const bare = p.replace(/^@/, "").replace(/^[abciwo]\//, "");
    for (const path of bare === p ? [p] : [bare, p])
      if (!out.some((o) => o.path === path && o.line === c.line)) out.push({ ...c, path });
  }
  return out;
}

async function exists(path) {
  return (await exec("test", ["-e", path])).code === 0;
}

// The first candidate that exists, with its absolute path: absolute, ~/, git's .../
// abbreviation, or under the terminal's folder, its git root, then home.
async function resolve(list, cwd, home) {
  const top = cwd ? (await exec("git", ["rev-parse", "--show-toplevel"], { cwd })).stdout.trim() : "";
  const bases = [cwd, top, home].filter((b, i, all) => b && all.indexOf(b) === i);
  for (const c of list) {
    const p = c.path;
    let paths = [];
    if (p.startsWith("/")) paths = [p];
    else if (p.startsWith("~/")) paths = [home + p.slice(1)];
    else if (p.startsWith(".../")) {
      if (!top) continue;
      const files = (await exec("git", ["ls-files", "--full-name"], { cwd: top })).stdout.split("\n");
      const hit = files.find((f) => ("/" + f).endsWith(p.slice(3)));
      if (hit) paths = [`${top}/${hit}`];
    } else paths = bases.map((b) => `${b}/${p}`);
    for (const path of paths) if (await exists(path)) return { ...c, path };
  }
  return null;
}

async function copied() {
  run("terminal.copy");
  return (await exec("pbpaste")).stdout;
}

// The whitespace-separated token of line covering col.
function tokenAt(line, col) {
  for (const m of line.matchAll(/\S+/g)) if (col >= m.index && col < m.index + m[0].length) return m[0];
  return "";
}

export default class OpenFile extends View {
  init(_props, cx) {
    const f = focused();
    cx.spawn(async () => {
      try {
        if (!f?.terminal) return notify({ title: "Open file", body: "No terminal is focused.", level: "warning" });
        const sel = f.selection;
        if (!sel) return notify({ title: "Open file", body: "Select a path first (triple-click its line).", level: "warning" });
        const word = await copied();
        // A word on one row (a double-click, or Hammerspoon's cmd-click): read its whole line
        // too, for line numbers, git prefixes and what's around it.
        let list = candidates(word);
        if (sel.start.row === sel.end.row && !word.includes("\n")) {
          const col = Math.min(sel.start.col, sel.end.col);
          run("terminal.select", { terminal: f.terminal, at: { row: sel.start.row, col }, mode: "line" });
          const line = (await copied()).replace(/\n+$/, "");
          list = [...candidates(tokenAt(line, col)), ...list, ...candidates(line)];
        }
        // Herdr's own cmd-click: a terminal address.
        const address = word.trim().match(/^(?:[\w.-]+\/)?t\d+$/)?.[0];
        if (address && terminals().some((t) => t.address === address)) return run("pane.focus", { terminal: address });
        const home = (await exec("printenv", ["HOME"])).stdout.trim();
        const hit = await resolve(list, f.cwd, home);
        if (!hit) return notify({ title: "Open file", body: `No file found for: ${word.trim().slice(0, 120)}`, level: "warning" });
        const editor = `${home}/.bin/editor`;
        const r = hit.line
          ? await exec(editor, [hit.path, hit.line, ...(hit.col ? [hit.col] : [])])
          : (await exec("test", ["-d", hit.path])).code === 0
            ? await exec(editor, [hit.path])
            : await exec("open", [hit.path]);
        if (r.code !== 0) notify({ title: "Open file", body: r.stderr.trim() || `Could not open ${hit.path}`, level: "error" });
      } finally {
        closeOverlay(props().overlay);
      }
    });
  }

  render() {
    return div();
  }
}
