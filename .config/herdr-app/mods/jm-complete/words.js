// @ts-check
// Pure word logic for jm-complete; no Herdr imports, so node can test it.

const SEPARATORS = /[\s"'`()<>\[\]{},;|&]+/;
const EDGE_PUNCTUATION = /^[.:!?=*#$%^]+|[.:!?=*#$%^]+$/g;
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
 * The words of one line: whole shell-ish tokens (paths, flags, URLs), then their
 * `/`, `=`, `:` and `@` separated parts, trimmed of surrounding punctuation.
 * @param {string} line
 * @returns {string[]}
 */
function lineWords(line) {
  const out = [];
  for (const raw of line.split(SEPARATORS)) {
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
 * Unique words of the given screens, nearest first: each screen bottom up, in order.
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
