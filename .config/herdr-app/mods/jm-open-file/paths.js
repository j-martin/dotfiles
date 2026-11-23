// Path logic for jm-open-file; no Herdr imports, so node can test it. Herdr's `exec` is passed in.
// Recognized text, e.g.:
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

/** @typedef {{ path: string, line?: string, col?: string }} Candidate */
/** @typedef {(cmd: string, args?: string[], opts?: { cwd?: string }) => Promise<{ code: number, stdout: string, stderr: string }>} Exec */

/**
 * `path:12:`, `path-12-`, `path:12:3:`, a trailing `path:12[:3]` or `path#L12`, in s.
 * @param {string} s
 * @returns {Candidate[]}
 */
function located(s) {
  const out = [];
  const end = s.match(/:(\d+)(?::(\d+))?$/);
  if (end && end.index > 0) out.push({ path: s.slice(0, end.index), line: end[1], col: end[2] });
  for (const m of s.matchAll(/([:-])(\d+)\1(?:(\d+)\1)?/g))
    if (m.index > 0) out.push({ path: s.slice(0, m.index), line: m[2], col: m[1] === ":" ? m[3] : undefined });
  const anchor = s.match(/#L(\d+)(?:C(\d+))?(?:-L?\d+(?:C\d+)?)?$/);
  if (anchor && anchor.index > 0) out.push({ path: s.slice(0, anchor.index), line: anchor[1], col: anchor[2] });
  return out;
}

/**
 * s without ANSI/OSC escapes, invisible or invalid characters (e.g. a terminal's U+FFFD).
 * @param {string} s
 * @returns {string}
 */
function visible(s) {
  return s
    .replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-9;?]*[A-Za-z]/g, "")
    .replace(/[\uFFFD\p{Cc}\p{Cf}\p{Co}\p{Cs}]/gu, (c) => (c === "\n" || c === "\t" ? c : ""));
}

/**
 * s without escapes and surrounding quotes, brackets and punctuation.
 * @param {string} s
 * @returns {string}
 */
function trimmed(s) {
  return visible(s).replace(/^["'`(<\[]+|["'`)>\],;:.!?]+$/g, "");
}

/**
 * Candidate paths in the first line of text, best first.
 * @param {string} text
 * @returns {Candidate[]}
 */
export function candidates(text) {
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
  /** @type {Candidate[]} */
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

/**
 * The whitespace-separated token of line covering col.
 * @param {string} line
 * @param {number} col
 * @returns {string}
 */
export function tokenAt(line, col) {
  for (const m of line.matchAll(/\S+/g)) if (col >= m.index && col < m.index + m[0].length) return m[0];
  return "";
}

/**
 * The first candidate that exists, with its absolute path: absolute, ~/, git's .../
 * abbreviation, or under the terminal's folder, its git root, then home.
 * @param {Candidate[]} list
 * @param {string | null | undefined} cwd
 * @param {string} home
 * @param {Exec} exec
 * @returns {Promise<Candidate | null>}
 */
export async function resolve(list, cwd, home, exec) {
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
    for (const path of paths) if ((await exec("test", ["-e", path])).code === 0) return { ...c, path };
  }
  return null;
}

/**
 * Opens hit with ~/.bin/editor at its line or for a folder (dired), else with the macOS default app.
 * @param {Candidate} hit
 * @param {string} home
 * @param {Exec} exec
 * @returns {Promise<{ code: number, stdout: string, stderr: string }>}
 */
export async function open(hit, home, exec) {
  const editor = `${home}/.bin/editor`;
  if (hit.line) return exec(editor, [hit.path, hit.line, ...(hit.col ? [hit.col] : [])]);
  if ((await exec("test", ["-d", hit.path])).code === 0) return exec(editor, [hit.path]);
  return exec("open", [hit.path]);
}
