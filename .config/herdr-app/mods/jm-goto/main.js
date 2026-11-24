// @ts-check
// cmd-p (mod.open:jm-goto): every space, tab and pane, to go to one. Panes show their agent and
// session title, or their executable, title and folder. Type to filter (every word, in the row or
// its space and tab), ↑/↓ (or ctrl-n/p) and Enter to go, Esc to leave.

import { View, div, svg, image } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, ScrollHandle } from "gpui-base";
import { closeOverlay, home, panes, props, run, spaces, theme } from "herdr";
import { buildRows, filterRows } from "./goto.js";

/** @typedef {import("./goto.js").Row} Row */

const LIST_HEIGHT = 480;
const INDENT = 18;

/**
 * A row's height in px.
 * @param {Row} r
 * @returns {number}
 */
const rowHeight = (r) => (r.kind === "space" ? 30 : 26);

/**
 * The program's icon, tinted or in full color.
 * @param {any} program
 * @param {string} color
 */
const icon = (program, color) => {
  if (!program?.icon) {
    return div().w(14).flex_none();
  }
  return program.tint ? svg(program.icon).size(14).flex_none().text_color(color) : image(program.icon).w(14).h(14).flex_none();
};

export default class Goto extends View {
  init(_props, cx) {
    this.filter = "";
    /** @type {string | null} */
    this.selected = null;
    this.scroll = ScrollHandle.new();
    this.input = InputState.new({ placeholder: "Go to a space, tab or pane…" });
    this.input.on("change", (_e, cx) => {
      this.filter = this.input.value();
      const shown = this.rows();
      this.selected = (shown.find((r) => r.kind === "pane") ?? shown[0])?.id ?? null;
      this.reveal(shown);
      cx.notify();
    });
    this.input.on("submit", () => this.go(this.rows().find((r) => r.id === this.selected)));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    const all = this.rows();
    this.selected = (all.find((r) => r.kind === "pane" && r.active) ?? all.find((r) => r.active) ?? all[0])?.id ?? null;
    this.reveal(all);
  }

  close() {
    closeOverlay(props().overlay);
  }

  /**
   * The shown rows.
   * @returns {Row[]}
   */
  rows() {
    return filterRows(buildRows(spaces(), panes(), home()), this.filter);
  }

  /**
   * Scrolls the selected row into view.
   * @param {Row[]} shown
   */
  reveal(shown) {
    const i = shown.findIndex((r) => r.id === this.selected);
    if (i >= 0) {
      this.scroll.scroll_to_item(i);
    }
  }

  /**
   * Shows the row's space, tab or pane, then closes.
   * @param {Row | undefined} r
   */
  go(r) {
    if (!r) {
      return;
    }
    this.close();
    if (r.kind === "space") {
      run("space.select", { id: r.id });
    } else if (r.kind === "tab") {
      run("tab.select", { id: r.id });
    } else {
      run("tab.select", { id: r.tab });
      run("pane.focus", { pane: r.id });
    }
  }

  /**
   * A status mark: a spinner while working, else a dot in the status color.
   * @param {Record<string, string>} t
   * @param {string | null} st
   */
  mark(t, st) {
    if (st === "working") {
      return svg("mods/workspace-chrome/spinner.svg").size(10).flex_none().text_color(t.working).spin(900);
    }
    return div()
      .w(10)
      .flex_none()
      .text_size(10)
      .text_color(st ? (t[st] ?? t.dim) : t.dim)
      .child(st && st !== "idle" ? "●" : "");
  }

  render() {
    const t = theme();
    const shown = this.rows();
    if (!shown.some((r) => r.id === this.selected)) {
      this.selected = shown[0]?.id ?? null;
    }
    const at = shown.findIndex((r) => r.id === this.selected);

    const row = (/** @type {Row} */ r) => {
      const on = r.id === this.selected;
      const base = h_flex()
        .id(`jmg-${r.id}`)
        .mx(4)
        .pl(10 + r.depth * INDENT)
        .pr(10)
        .h(rowHeight(r))
        .flex_none()
        .rounded(6)
        .gap(8)
        .items_center()
        .cursor_pointer()
        .when(on, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click(() => this.go(r))
        .child(this.mark(t, r.status));
      if (r.kind === "space") {
        return base
          .child(div().flex_none().font_bold().text_color(t.foreground).when(r.active, (d) => d.text_color(t.accent)).child(r.label))
          .child(div().flex_1().truncate().text_size(11).text_color(t.dim).child(r.detail));
      }
      if (r.kind === "tab") {
        return base
          .child(div().flex_none().font_semibold().text_color(r.active ? t.accent : t.foreground).child(`Tab ${r.label}`))
          .child(div().flex_1().truncate().text_size(11).text_color(t.dim).child(r.detail));
      }
      return base
        .child(icon(r.program, t.dim))
        .child(div().flex_none().max_w(200).truncate().font_medium().text_color(r.active ? t.accent : t.foreground).child(r.label))
        .child(div().flex_shrink(1).min_w(0).truncate().text_color(t.muted).child(r.title))
        .child(div().flex_1().min_w(40).truncate().text_size(11).text_color(t.dim).child(r.detail));
    };

    return v_flex()
      .id("jm-goto")
      .w_full()
      .min_h(0)
      .p(12)
      .gap(8)
      .bg(t.popover)
      .text_size(12.5)
      .on_key_down((e, cx) => {
        const k = e.key;
        const n = shown.length || 1;
        if (k === "escape") {
          return this.close();
        }
        if (k === "down" || (k === "n" && e.modifiers.control)) {
          this.selected = shown[(at + 1) % n]?.id ?? null;
        } else if (k === "up" || (k === "p" && e.modifiers.control)) {
          this.selected = shown[(at + n - 1) % n]?.id ?? null;
        } else {
          return;
        }
        this.reveal(shown);
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
          .child(svg("mods/workspace-chrome/search.svg").size(14).text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
      )
      .child(
        shown.length
          ? v_flex()
              .id("jmg-list")
              .h(Math.min(LIST_HEIGHT, shown.reduce((sum, r) => sum + rowHeight(r), 0)))
              .min_h(0).overflow_y_scrollbar().track_scroll(this.scroll).children(shown.map(row))
          : div().px(10).py(6).text_color(t.dim).child("Nothing matches."),
      );
  }
}
