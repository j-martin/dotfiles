// @ts-check
// cmd-; (mod.open:jm-complete): like iTerm2's autocomplete. Offers the words on screen in
// the focused tab's panes (the focused one first, newest output first) that complete
// the word before the cursor, and the files of the terminal's live cwd, or of the folder a
// word like `../` or `.claude/sk` names. Deeper paths first, then the newest on screen.
// Type to fuzzy filter, ↑/↓ and Enter to insert, Esc to leave.
// The word before the cursor comes from selecting it (terminal.select at the cursor,
// then to the line start) and copying; the completion is pasted. Both go through the
// clipboard, which is put back afterwards (text only). A completion that doesn't extend
// the prefix replaces it: the prefix is erased with backspaces first.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { closeOverlay, exec, focused, hc, home, notify, panes, props, run, terminals, theme } from "herdr";
import { candidates, folderOf, fuzzy, insertion, prefixOf, splitPath, words } from "./words.js";

const TITLE = "Complete";
const MAX_ROWS = 12;
const ROW_HEIGHT = 28;
const WAIT_MS = 20;
const WAIT_TRIES = 25;
const SENTINEL = "jm-complete: waiting for copy";
// Without a UTF-8 locale pbpaste and pbcopy turn non-ASCII text, e.g. the `❯` prompt, into `?`.
const UTF8 = "LANG=en_US.UTF-8";

/**
 * The clipboard's text.
 * @returns {Promise<string>}
 */
async function clipboard() {
  return (await exec("sh", ["-c", `${UTF8} pbpaste`])).stdout;
}

/**
 * Replaces the clipboard with text. `exec` has no stdin, so sh pipes it in.
 * @param {string} text
 * @returns {Promise<void>}
 */
async function setClipboard(text) {
  await exec("sh", ["-c", `printf %s "$1" | ${UTF8} pbcopy`, "sh", text]);
}

/**
 * Polls check until it gives something truthy; selections and copies land asynchronously.
 * @template T
 * @param {any} cx
 * @param {() => T | Promise<T>} check
 * @returns {Promise<T | null>}
 */
async function waitFor(cx, check) {
  for (let i = 0; i < WAIT_TRIES; i++) {
    const value = await check();
    if (value) {
      return value;
    }
    await cx.sleep(WAIT_MS);
  }
  return null;
}

/**
 * The terminal's current selection.
 * @param {string} terminal
 * @returns {{ start: { row: number, col: number }, end: { row: number, col: number } } | null}
 */
function selection(terminal) {
  return terminals().find((t) => t.address === terminal)?.selection ?? null;
}

/**
 * The text between the start of the cursor's line and the cursor in the focused terminal.
 * Leaves the terminal without a selection and the clipboard with that text.
 * @param {string} terminal
 * @param {any} cx
 * @returns {Promise<string>}
 */
async function beforeCursor(terminal, cx) {
  run("terminal.clear_selection", { terminal });
  run("terminal.select", { terminal, at: "cursor" });
  const cursor = (await waitFor(cx, () => {
    const s = selection(terminal);
    return s && s.start.row === s.end.row && s.start.col === s.end.col ? s : null;
  }))?.start;
  if (!cursor || cursor.col === 0) {
    run("terminal.clear_selection", { terminal });
    return "";
  }
  const last = { row: cursor.row, col: cursor.col - 1 };
  run("terminal.select", { terminal, at: last });
  await waitFor(cx, () => selection(terminal)?.start.col === last.col);
  run("terminal.adjust_selection", { terminal, direction: "line_start" });
  await waitFor(cx, () => selection(terminal)?.end.col === 0);
  await setClipboard(SENTINEL);
  run("terminal.copy");
  const text = await waitFor(cx, async () => {
    const copied = await clipboard();
    return copied === SENTINEL ? null : copied;
  });
  run("terminal.clear_selection", { terminal });
  return (text ?? "").replace(/\n+$/, "");
}

/**
 * The screens of the focused tab's terminals, the focused one first.
 * @param {string} terminal
 * @param {string} tab
 * @returns {Promise<string[]>}
 */
async function screens(terminal, tab) {
  const others = panes()
    .filter((p) => p.tab === tab && p.terminal && p.terminal !== terminal)
    .map((p) => p.terminal);
  const reads = await Promise.all(
    [terminal, ...others].map(async (t) => {
      const r = await hc(["read", t, "--json"]);
      if (r.code !== 0) {
        return "";
      }
      try {
        return JSON.parse(r.stdout).text ?? "";
      } catch {
        return "";
      }
    }),
  );
  return reads;
}

/**
 * The live working directory of the terminal's foreground process, e.g. its shell's after a `cd`, else where it started.
 * @param {string} terminal
 * @param {string | null} fallback
 * @returns {Promise<string | null>}
 */
async function liveCwd(terminal, fallback) {
  const r = await hc(["get", terminal, "--json"]);
  if (r.code !== 0) {
    return fallback;
  }
  try {
    const details = JSON.parse(r.stdout);
    return details.foreground?.cwd || details.cwd || fallback;
  } catch {
    return fallback;
  }
}

/**
 * The entries of the folder the prefix's head names, else of the cwd, folders ending with `/`; none without a cwd.
 * @param {string} prefix
 * @param {string} terminal
 * @param {string | null} cwd
 * @returns {Promise<string[]>}
 */
async function entries(prefix, terminal, cwd) {
  const live = await liveCwd(terminal, cwd);
  if (!live) {
    return [];
  }
  const folder = folderOf(splitPath(prefix).head, live, home());
  try {
    const r = await exec("ls", ["-1", "-A", "-p", folder]);
    return r.code === 0 ? r.stdout.split("\n").filter(Boolean) : [];
  } catch {
    return [];
  }
}

export default class Complete extends View {
  init(_props, cx) {
    /** @type {string[] | null} */
    this.list = null;
    this.prefix = "";
    this.saved = "";
    this.filter = "";
    this.at = 0;
    this.f = focused();
    this.input = InputState.new({ placeholder: "Filter…" });
    this.input.on("change", (_e, cx) => {
      this.filter = this.input.value();
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_e, cx) => this.choose(this.matches()[this.at], cx));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    cx.spawn(async (cx) => {
      const f = this.f;
      if (!f?.terminal) {
        notify({ title: TITLE, body: "No terminal is focused.", level: "warning" });
        return this.close();
      }
      this.saved = await clipboard();
      const before = await beforeCursor(f.terminal, cx);
      await setClipboard(this.saved);
      this.prefix = prefixOf(before);
      const [onScreen, files] = await Promise.all([screens(f.terminal, f.tab), entries(this.prefix, f.terminal, f.cwd)]);
      this.list = candidates(words(onScreen), files, this.prefix);
      if (!this.list.length) {
        notify({ title: TITLE, body: this.prefix ? `Nothing on screen or in its folder starts with “${this.prefix}”.` : "No words on screen.", level: "info" });
        return this.close();
      }
      cx.notify();
    });
  }

  close() {
    closeOverlay(props().overlay);
  }

  /**
   * The completions left by the filter.
   * @returns {string[]}
   */
  matches() {
    const rest = (this.list ?? []).map((w) => insertion(w, this.prefix).text);
    return (this.list ?? []).filter((_w, i) => fuzzy(rest[i], this.filter));
  }

  /**
   * Puts word in place of the prefix in the terminal, then closes.
   * @param {string | undefined} word
   * @param {any} cx
   */
  choose(word, cx) {
    if (!word) {
      return;
    }
    cx.spawn(async () => {
      try {
        const { erase, text } = insertion(word, this.prefix);
        if (erase > 0 && this.f?.terminal) {
          await hc(["keys", this.f.terminal, ...Array(erase).fill("backspace")]);
        }
        await setClipboard(text);
        run("terminal.paste");
        await setClipboard(this.saved);
      } finally {
        this.close();
      }
    });
  }

  render() {
    const t = theme();
    const list = this.matches();
    this.at = Math.max(0, Math.min(this.at, list.length - 1));
    const first = Math.max(0, Math.min(this.at - MAX_ROWS + 1, list.length - MAX_ROWS));
    const shown = list.slice(first, first + MAX_ROWS);

    const row = (/** @type {string} */ word, /** @type {number} */ i) => {
      const { erase, text } = insertion(word, this.prefix);
      return h_flex()
        .id(`jc-${i}`)
        .mx(4)
        .px(10)
        .h(ROW_HEIGHT)
        .flex_none()
        .rounded(6)
        .items_center()
        .cursor_pointer()
        .when(i === this.at, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => this.choose(word, cx))
        .when(erase === 0, (el) => el.child(div().text_color(t.dim).child(this.prefix)))
        .child(div().flex_1().truncate().text_color(t.foreground).font_semibold().child(text));
    };

    return v_flex()
      .id("jm-complete")
      .w_full()
      .min_h(0)
      .p(12)
      .gap(8)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        const k = e.key;
        const n = list.length || 1;
        if (k === "escape") {
          return this.close();
        }
        if (k === "down" || (k === "n" && e.modifiers.control)) {
          this.at = (this.at + 1) % n;
        } else if (k === "up" || (k === "p" && e.modifiers.control)) {
          this.at = (this.at + n - 1) % n;
        } else if (k === "tab") {
          this.choose(list[this.at], cx);
        } else {
          return;
        }
        cx.stop_propagation();
        cx.notify();
      })
      .child(
        h_flex()
          .h(32)
          .flex_none()
          .px(10)
          .gap(8)
          .items_center()
          .rounded(8)
          .border_1()
          .border_color(t.accent)
          .bg(t.background)
          .child(div().text_color(t.dim).child(this.prefix || "…"))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
      )
      .child(
        this.list === null
          ? div().px(10).text_color(t.dim).child("Reading panes…")
          : list.length === 0
            ? div().px(10).text_color(t.dim).child("No match")
            : v_flex().flex_none().children(shown.map((w, i) => row(w, first + i))),
      );
  }
}
