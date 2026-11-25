// @ts-check
// cmd-shift-m (mod.open:jm-move-tab): moves the focused pane, or the whole shown tab, still
// running, to a tab of a space on its machine, a new tab there, or a new space. First pick what
// to move (skipped when there is nothing to pick between), then a space, then a tab; type to
// filter, ↑/↓ and Enter to choose, Esc to go back, then leave. The first space offered is
// the one for what moves' repo root (else its cwd), or a new one there.
// Herdr has no command for it, so each terminal is parked (no pane, its herdr.space/herdr.tab
// labels dropped), then given a pane where it goes: `terminal.keep` below the focused pane
// (focus follows the new pane, so they stack at the bottom in their order), as a new tab of
// the shown space, or, for a new space, labelled with ids Herdr adopts. A moved tab keeps its
// name when it becomes a new tab; mod panes stay behind.
// "Merge duplicate spaces" (also props { merge: true }, opened by jm-merge-spaces) moves every
// tab of spaces sharing a name on one machine, as new tabs, into one of them, then closes the rest.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { closeOverlay, exec, focused, hc, home, notify, panes, props, run, spaces, theme } from "herdr";
import { baseName, duplicateGroups, folderSpace, freshId, matches, offersNewTab, spaceChoices, tabChoices } from "./move.js";

const TITLE = "Move";
const MAX_ROWS = 12;
const ROW_HEIGHT = 28;
const WAIT_MS = 5000;

/**
 * @typedef {{ kind: "tab", tab: any } | { kind: "new-tab", space: any } | { kind: "new-space", folder?: string }} Target
 * @typedef {{ kind: "what", what: "tab" | "pane" } | { kind: "merge" } | { kind: "space", space: any, folder?: string } | Target} Row
 */

/**
 * Polls `check` until it returns something truthy.
 * @template T
 * @param {any} cx
 * @param {() => T | Promise<T>} check
 * @param {string} what what is awaited, for the error
 * @returns {Promise<T>}
 */
const until = async (cx, check, what) => {
  for (let waited = 0; waited < WAIT_MS; waited += 100) {
    const v = await check();
    if (v) {
      return v;
    }
    await cx.sleep(100);
  }
  throw new Error(`Timed out waiting for ${what}.`);
};

/**
 * A folder's repo root, else the folder itself.
 * @param {string} cwd
 * @param {string | null} machine
 * @returns {Promise<string>}
 */
const rootOf = async (cwd, machine) => {
  const r = await exec("git", ["rev-parse", "--path-format=absolute", "--show-toplevel"], { cwd, on: machine });
  return r.code === 0 ? r.stdout.replace(/\n$/, "") : cwd;
};

/**
 * A terminal's labels.
 * @param {string} terminal
 * @returns {Promise<Record<string, string>>}
 */
const labels = async (terminal) => {
  const r = await hc(["get", terminal, "--json"]);
  if (r.code !== 0) {
    throw new Error(`hc get ${terminal}: ${r.stderr.trim()}`);
  }
  return JSON.parse(r.stdout).labels ?? {};
};

/**
 * The tab a terminal's pane is in, once Herdr shows it.
 * @param {any} cx
 * @param {string} terminal
 * @returns {Promise<string>}
 */
const shownTab = (cx, terminal) => until(cx, () => panes().find((p) => p.terminal === terminal)?.tab, `${terminal} to show`);

/**
 * Moves terminals to a target, stacked down in their order, and shows them there.
 * Returns the tab they're in.
 * @param {any} cx
 * @param {string[]} terminals
 * @param {Target} target
 * @returns {Promise<string>}
 */
const moveTerminals = async (cx, terminals, target) => {
  for (const terminal of terminals) {
    run("terminal.park", { terminal });
  }
  // Parking drops the labels once the core replies; placing earlier would be undone.
  for (const terminal of terminals) {
    await until(cx, async () => !(await labels(terminal))["herdr.space"], `${terminal} to park`);
  }
  let rest = terminals;
  if (target.kind === "tab") {
    run("tab.select", { id: target.tab.id });
    const last = panes()
      .filter((p) => p.tab === target.tab.id)
      .at(-1);
    if (last) {
      run("pane.focus", { pane: last.pane });
    }
  } else {
    const [first] = terminals;
    rest = terminals.slice(1);
    if (target.kind === "new-tab") {
      run("space.select", { id: target.space.id });
      run("terminal.keep", { terminal: first });
    } else {
      const r = await hc(["label", first, `herdr.space=${freshId("sp")}`, `herdr.tab=${freshId("tb")}`]);
      if (r.code !== 0) {
        throw new Error(`hc label ${first}: ${r.stderr.trim()}`);
      }
    }
    run("tab.select", { id: await shownTab(cx, first) });
    run("pane.focus", { terminal: first });
  }
  for (const terminal of rest) {
    run("terminal.keep", { terminal, place: "down" });
    await shownTab(cx, terminal);
  }
  return shownTab(cx, terminals[0]);
};

/**
 * Moves every tab of each duplicate space, as new tabs keeping their names, into its group's
 * space, then closes the emptied spaces and shows the space that was shown (or its group's).
 * Returns the merged spaces' names.
 * @param {any} cx
 * @returns {Promise<string[]>}
 */
const mergeDuplicates = async (cx) => {
  const shown = spaces().find((s) => s.active);
  const groups = duplicateGroups(spaces());
  for (const { into, from } of groups) {
    for (const space of from) {
      for (const tab of space.tabs) {
        const terminals = panes()
          .filter((p) => p.tab === tab.id && p.terminal)
          .map((p) => /** @type {string} */ (p.terminal));
        if (terminals.length) {
          const moved = await moveTerminals(cx, terminals, { kind: "new-tab", space: into });
          run("tab.rename", { id: moved, name: tab.named ? tab.name : "" });
        }
      }
      if (spaces().some((s) => s.id === space.id)) {
        run("space.close", { id: space.id });
      }
    }
  }
  const back = groups.find((g) => g.from.some((s) => s.id === shown?.id))?.into ?? shown;
  if (back) {
    run("space.select", { id: back.id });
  }
  return groups.map((g) => g.into.name);
};

export default class Move extends View {
  init(_props, cx) {
    const f = focused();
    this.source = spaces().find((s) => s.active);
    this.tab = this.source?.tabs.find((t) => t.active);
    const own = panes().filter((p) => p.tab === this.tab?.id);
    this.tabTerminals = own.filter((p) => p.terminal).map((p) => /** @type {string} */ (p.terminal));
    this.modPanes = own.length - this.tabTerminals.length;
    this.pane = own.find((p) => p.terminal && p.terminal === f?.terminal);
    this.duplicates = duplicateGroups(spaces());
    this.picksWhat = Boolean(this.pane || this.duplicates.length);
    /** @type {"tab" | "pane" | null} */
    this.what = this.picksWhat ? null : "tab";
    this.space = null;
    this.moving = false;
    this.filter = "";
    this.at = 0;
    this.input = InputState.new({ placeholder: "Filter…" });
    this.input.on("change", (_e, cx) => {
      this.filter = this.input.value();
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_e, cx) => this.choose(this.rows()[this.at], cx));
    this.input.focus();
    /** @type {{ tab?: string, pane?: string }} what moves' repo root, else cwd */
    this.roots = {};
    const cwdOf = (/** @type {string | undefined} */ t) => own.find((p) => p.terminal === t)?.cwd;
    for (const [what, cwd] of /** @type {const} */ ([
      ["tab", cwdOf(this.tabTerminals[0])],
      ["pane", this.pane?.cwd],
    ])) {
      if (cwd) {
        cx.spawn(async (cx) => {
          this.roots[what] = await rootOf(cwd, this.source?.machine ?? null);
          cx.notify();
        });
      }
    }
    cx.timer.after(600, () => this.input.focus());
    if (props()?.merge) {
      cx.timer.after(0, () => this.choose({ kind: "merge" }, cx));
    } else if (!this.tabTerminals.length && !this.duplicates.length) {
      cx.timer.after(0, () => {
        notify({ title: TITLE, body: "The shown tab has no terminal to move.", level: "warning" });
        this.close();
      });
    }
  }

  close() {
    closeOverlay(props().overlay);
  }

  /**
   * The terminals that move.
   * @returns {string[]}
   */
  terminals() {
    return this.what === "pane" ? [this.pane.terminal] : this.tabTerminals;
  }

  /**
   * Starts a step over: the space list (space null) or that space's tabs.
   * @param {any} space
   */
  step(space) {
    this.space = space;
    this.filter = "";
    this.at = 0;
    this.input.set_value("");
  }

  /**
   * The current step's choices, filtered: what to move, spaces then a new one, or tabs then a new one.
   * @returns {Row[]}
   */
  rows() {
    if (!this.source) {
      return [];
    }
    if (!this.what) {
      return /** @type {Row[]} */ ([
        ...(this.pane ? [{ kind: "what", what: "pane" }] : []),
        ...(this.tabTerminals.length ? [{ kind: "what", what: "tab" }] : []),
        ...(this.duplicates.length ? [{ kind: "merge" }] : []),
      ]).filter((r) => matches(r.kind === "what" ? r.what : "merge duplicate spaces", this.filter));
    }
    if (!this.space) {
      const all = spaces();
      const choices = spaceChoices(all, this.source, this.tab.id, this.what, this.filter);
      const folder = this.roots[this.what];
      if (!folder) {
        return [...choices.map((space) => /** @type {Row} */ ({ kind: "space", space })), { kind: "new-space" }];
      }
      const moving = new Set(this.terminals());
      const there = folderSpace(all, this.source, panes().filter((p) => !moving.has(p.terminal)), folder);
      const shown = matches(baseName(folder), this.filter) || (there && matches(there.name, this.filter));
      if (there) {
        const allowed = spaceChoices(all, this.source, this.tab.id, this.what, "").some((s) => s.id === there.id);
        return [
          ...(allowed && shown ? [/** @type {Row} */ ({ kind: "space", space: there, folder })] : []),
          ...choices.filter((s) => s.id !== there.id).map((space) => /** @type {Row} */ ({ kind: "space", space })),
          { kind: "new-space" },
        ];
      }
      return [...(shown ? [/** @type {Row} */ ({ kind: "new-space", folder })] : []), ...choices.map((space) => /** @type {Row} */ ({ kind: "space", space })), ...(shown ? [] : [/** @type {Row} */ ({ kind: "new-space" })])];
    }
    const space = spaces().find((s) => s.id === this.space.id) ?? this.space;
    return [
      ...tabChoices(space, this.tab.id, this.filter).map((tab) => /** @type {Row} */ ({ kind: "tab", tab })),
      ...(offersNewTab(space, this.source, this.what) ? [/** @type {Row} */ ({ kind: "new-tab", space })] : []),
    ];
  }

  /**
   * Picks what to move, goes into a space, or moves to the chosen target, shows it, then closes. The overlay
   * stays open meanwhile: closing a mod cancels its pending calls.
   * @param {Row | undefined} row
   * @param {any} cx
   */
  choose(row, cx) {
    if (!row || this.moving) {
      return;
    }
    if (row.kind === "what") {
      this.what = row.what;
      this.step(null);
      cx.notify();
      return;
    }
    if (row.kind === "space") {
      this.step(row.space);
      cx.notify();
      return;
    }
    this.moving = true;
    cx.notify();
    if (row.kind === "merge") {
      cx.spawn(async (cx) => {
        try {
          const merged = await mergeDuplicates(cx);
          notify({
            title: TITLE,
            body: merged.length ? `Merged duplicate spaces into ${merged.map((n) => `"${n}"`).join(", ")}.` : "No duplicate spaces to merge.",
            level: merged.length ? "success" : "info",
          });
        } catch (e) {
          notify({ title: TITLE, body: `${e instanceof Error ? e.message : String(e)} Parked terminals still run: peek and keep them.`, level: "error" });
        } finally {
          this.close();
        }
      });
      return;
    }
    // terminal.keep names a new tab after its terminal ("t67"); "" gives it its number back.
    const name = row.kind === "tab" ? null : this.what === "tab" && this.tab.named ? this.tab.name : "";
    cx.spawn(async (cx) => {
      try {
        const tab = await moveTerminals(cx, this.terminals(), row);
        if (name !== null) {
          run("tab.rename", { id: tab, name });
        }
        if (this.what === "tab" && this.modPanes) {
          notify({ title: TITLE, body: `${this.modPanes} mod pane(s) stayed in "${this.source.name}".`, level: "info" });
        }
      } catch (e) {
        notify({ title: TITLE, body: `${e instanceof Error ? e.message : String(e)} Parked terminals still run: peek and keep them.`, level: "error" });
      } finally {
        this.close();
      }
    });
  }

  render() {
    const t = theme();
    const list = this.rows();
    this.at = Math.max(0, Math.min(this.at, list.length - 1));
    const first = Math.max(0, Math.min(this.at - MAX_ROWS + 1, list.length - MAX_ROWS));
    const shown = list.slice(first, first + MAX_ROWS);
    const paneName = this.pane ? this.pane.name || this.pane.title : "";
    const shortPath = (/** @type {string} */ f) => (!this.source?.machine && (f === home() || f.startsWith(`${home()}/`)) ? `~${f.slice(home().length)}` : f);

    /** @param {Row} r */
    const label = (r) => {
      switch (r.kind) {
        case "what":
          return r.what === "pane" ? ["Current pane", paneName] : ["Current tab", `${this.tab?.name ?? ""} · ${this.tabTerminals.length} pane(s)`];
        case "merge":
          return ["Merge duplicate spaces", this.duplicates.map((g) => `${g.into.name} ×${g.from.length + 1}`).join(", ")];
        case "space":
          if (r.folder) {
            return [r.space.name, shortPath(r.folder)];
          }
          return [r.space.name, r.space.id === this.source.id ? "this space" : `${r.space.tabs.length} tab(s)`];
        case "tab":
          return [r.tab.name, `${r.tab.panes} pane(s)`];
        case "new-tab":
          return ["New tab", ""];
        default:
          return r.folder ? [`New space "${baseName(r.folder)}"`, shortPath(r.folder)] : ["New space", ""];
      }
    };

    const row = (/** @type {Row} */ r, /** @type {number} */ i) => {
      const [name, hint] = label(r);
      const isNew = r.kind === "new-tab" || r.kind === "new-space";
      return h_flex()
        .id(`jmt-${i}`)
        .mx(4)
        .px(10)
        .h(ROW_HEIGHT)
        .flex_none()
        .rounded(6)
        .items_center()
        .gap(8)
        .cursor_pointer()
        .when(i === this.at, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => this.choose(r, cx))
        .child(
          div()
            .flex_1()
            .truncate()
            .text_color(isNew ? t.dim : t.foreground)
            .when(!isNew, (el) => el.font_semibold())
            .child(name),
        )
        .child(div().text_size(11).text_color(t.dim).child(hint));
    };

    return v_flex()
      .id("jm-move-tab")
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
          if (this.space) {
            this.step(null);
          } else if (this.what && this.picksWhat) {
            this.what = null;
            this.step(null);
          } else {
            return this.close();
          }
        } else if (k === "down" || (k === "n" && e.modifiers.control)) {
          this.at = (this.at + 1) % n;
        } else if (k === "up" || (k === "p" && e.modifiers.control)) {
          this.at = (this.at + n - 1) % n;
        } else {
          return;
        }
        cx.stop_propagation();
        cx.notify();
      })
      .child(div().px(4).truncate().font_semibold().child(this.what === "pane" ? `Pane "${paneName}"` : this.what === "tab" ? `Tab "${this.tab?.name ?? ""}"` : "Move…"))
      .child(
        div()
          .px(4)
          .truncate()
          .text_color(t.dim)
          .child(!this.what ? "What to move?" : this.space ? `To a tab in "${this.space.name}"…` : `From "${this.source?.name ?? ""}" to a space…`),
      )
      .child(
        h_flex()
          .h(32)
          .flex_none()
          .px(10)
          .items_center()
          .rounded(8)
          .border_1()
          .border_color(t.accent)
          .bg(t.background)
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
      )
      .child(this.moving ? div().px(10).text_color(t.dim).child(this.what ? "Moving…" : "Merging…") : v_flex().flex_none().children(shown.map((r, i) => row(r, first + i))));
  }
}
