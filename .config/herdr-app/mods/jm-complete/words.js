// @ts-check
// Pure word logic for jm-complete; no Herdr imports, so node can test it.

const SEPARATORS = /[\s"'`()<>\[\]{},;|&]+/;
const EDGE_PUNCTUATION = /^[:!?=*#$%^]+|[.:!?=*#$%^]+$/g;
const MIN_LENGTH = 2;

/**
 * The text without ANSI/OSC escapes and invisible characters.
 * @param {string} s
 * @returns {string}
 */
export function visible(s) {
  return s
    .replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-9;?]*[A-Za-z]/g, "")
    .replace(/[\uFFFD\p{Cc}\p{Cf}\p{Co}\p{Cs}]/gu, (c) => (c === "\n" || c === "\t" ? c : ""));
}

/**
 * The words of one line, last token first: whole shell-ish tokens (paths, flags, URLs), each followed by its
 * `/`, `=`, `:` and `@` separated parts, trimmed of surrounding punctuation.
 * @param {string} line
 * @returns {string[]}
 */
function lineWords(line) {
  const out = [];
  for (const raw of line.split(SEPARATORS).reverse()) {
    const token = raw.replace(EDGE_PUNCTUATION, "");
    if (!token) {
      continue;
    }
    out.push(token);
    for (const part of token.split(/[\/=:@]+/)) {
      const word = part.replace(EDGE_PUNCTUATION, "");
      if (word && word !== token) {
        out.push(word);
      }
    }
  }
  return out;
}

/**
 * Unique words of the given screens, newest first: each screen from its end back to its
 * start (bottom line up, each line right to left), the screens in order.
 * @param {string[]} screens
 * @returns {string[]}
 */
export function words(screens) {
  const seen = new Set();
  const out = [];
  for (const screen of screens) {
    const lines = visible(screen).split("\n").reverse();
    for (const line of lines) {
      for (const word of lineWords(line)) {
        if (word.length >= MIN_LENGTH && !seen.has(word) && /\p{L}/u.test(word)) {
          seen.add(word);
          out.push(word);
        }
      }
    }
  }
  return out;
}

/**
 * The partial word being typed at the end of the text before the cursor.
 * @param {string} beforeCursor
 * @returns {string}
 */
export function prefixOf(beforeCursor) {
  const parts = visible(beforeCursor).split(SEPARATORS);
  return parts[parts.length - 1];
}

/**
 * Words that complete prefix, nearest first.
 * @param {string[]} list
 * @param {string} prefix
 * @returns {string[]}
 */
export function completions(list, prefix) {
  return list.filter((w) => w.length > prefix.length && w.startsWith(prefix));
}

/**
 * The prefix split at its last `/`: the folder part, slash included, and the partial name after it.
 * @param {string} prefix
 * @returns {{ head: string, tail: string }}
 */
export function splitPath(prefix) {
  const at = prefix.lastIndexOf("/") + 1;
  return { head: prefix.slice(0, at), tail: prefix.slice(at) };
}

/**
 * The folder a path head names, `~/` from home and relative ones, or none, from cwd.
 * @param {string} head
 * @param {string} cwd
 * @param {string} home
 * @returns {string}
 */
export function folderOf(head, cwd, home) {
  if (head.startsWith("/")) {
    return head;
  }
  if (head.startsWith("~/")) {
    return `${home}/${head.slice(2)}`;
  }
  return `${cwd.replace(/\/+$/, "")}/${head}`;
}

/**
 * The folder entries (folders ending with `/`) completing the prefix's partial name, each after its head.
 * Hidden entries only when the partial name starts with a dot.
 * @param {string[]} entries
 * @param {string} prefix
 * @returns {string[]}
 */
export function pathCompletions(entries, prefix) {
  const { head, tail } = splitPath(prefix);
  return entries
    .filter((e) => e.startsWith(tail) && (tail.startsWith(".") || !e.startsWith(".")))
    .map((e) => head + e);
}

/**
 * How many folders deep a path is, its trailing slash aside.
 * @param {string} path
 * @returns {number}
 */
function depth(path) {
  return path.replace(/\/+$/, "").split("/").length;
}

/**
 * Everything completing prefix, unique, deepest paths first. At the same depth: the screen words completing it, or
 * completing its partial name after its folder part, newest first, then the folder entries not on screen. A path
 * and the same path with a slash count once, as the folder entry when there is one.
 * @param {string[]} screenWords Newest first.
 * @param {string[]} entries
 * @param {string} prefix
 * @returns {string[]}
 */
export function candidates(screenWords, entries, prefix) {
  const { head, tail } = splitPath(prefix);
  const key = (/** @type {string} */ w) => w.replace(/\/+$/, "");
  const files = pathCompletions(entries, prefix);
  const fileByKey = new Map(files.map((f) => [key(f), f]));
  const onScreen = screenWords.flatMap((w) => {
    const found = completions([w], prefix);
    if (head && tail) {
      found.push(...completions([w], tail).map((t) => head + t));
    }
    return found.map((f) => fileByKey.get(key(f)) ?? f);
  });
  const seen = new Set();
  return [...onScreen, ...files]
    .filter((w) => {
      if (w === prefix || seen.has(key(w))) {
        return false;
      }
      seen.add(key(w));
      return true;
    })
    .sort((a, b) => depth(b) - depth(a));
}

/**
 * How to turn prefix into word at the cursor: the characters to erase before it
 * (none when word extends prefix, all of prefix otherwise) and the text to type.
 * @param {string} word
 * @param {string} prefix
 * @returns {{ erase: number, text: string }}
 */
export function insertion(word, prefix) {
  if (word.startsWith(prefix)) {
    return { erase: 0, text: word.slice(prefix.length) };
  }
  return { erase: [...prefix].length, text: word };
}

/**
 * Whether every character of query appears in text, in order, ignoring case.
 * @param {string} text
 * @param {string} query
 * @returns {boolean}
 */
export function fuzzy(text, query) {
  const t = text.toLowerCase();
  let at = 0;
  for (const c of query.toLowerCase()) {
    at = t.indexOf(c, at) + 1;
    if (at === 0) {
      return false;
    }
  }
  return true;
}
