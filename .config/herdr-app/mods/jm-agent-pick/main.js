// @ts-check
// Opened by jm-changes and jm-files when a mention could go to several agents (the focused
// tab's, else the focused space's): ↑/↓ or ctrl-n/p and Enter, a digit, or a click picks
// one; Esc leaves. props().mention: { path, line?, suffix? } (see agent.js).

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { closeOverlay, props, theme } from "herdr";
import { candidates, pasteMention } from "./agent.js";

const ROW_HEIGHT = 40;

export default class AgentPick extends View {
  init(_props, cx) {
    this.list = candidates();
    this.at = 0;
    this.handle = cx.focus_handle();
    this.handle.focus();
    cx.timer.after(100, () => this.handle.focus());
  }

  close() {
    closeOverlay(props().overlay);
  }

  /**
   * Sends the mention to that agent, then closes.
   * @param {import("herdr").AgentInfo | undefined} agent
   * @param {any} cx
   */
  choose(agent, cx) {
    if (!agent) {
      return;
    }
    const mention = props().mention;
    this.close();
    cx.spawn(() => pasteMention(agent.address, mention));
  }

  render() {
    const t = theme();
    const list = this.list;
    const dot = { working: t.ansi3, blocked: t.blocked, done: t.ansi2, idle: t.dim };
    const row = (/** @type {import("herdr").AgentInfo} */ a, /** @type {number} */ i) =>
      h_flex()
        .id(`jap-${i}`)
        .h(ROW_HEIGHT)
        .flex_none()
        .px(10)
        .gap(10)
        .items_center()
        .rounded(6)
        .cursor_pointer()
        .when(i === this.at, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => this.choose(a, cx))
        .child(div().w(14).flex_none().text_size(11).text_color(t.dim).child(i < 9 ? String(i + 1) : ""))
        .child(div().size(8).flex_none().rounded(4).bg(dot[a.status] ?? t.dim))
        .child(
          v_flex()
            .flex_1()
            .min_w(0)
            .child(div().truncate().text_color(t.foreground).child(a.pane_name || a.title || a.address))
            .child(div().truncate().text_size(11).text_color(t.dim).child([a.tab_name, a.app ?? a.program?.name, a.status].filter(Boolean).join(" · "))),
        );

    return v_flex()
      .id("jm-agent-pick")
      .w_full()
      .min_h(0)
      .p(8)
      .gap(4)
      .bg(t.popover)
      .text_size(13)
      .track_focus(this.handle)
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
        } else if (k === "enter") {
          this.choose(list[this.at], cx);
        } else if (/^[1-9]$/.test(k)) {
          this.choose(list[Number(k) - 1], cx);
        } else {
          return;
        }
        cx.stop_propagation();
        cx.notify();
      })
      .child(div().px(10).py(4).text_size(11).text_color(t.dim).child("Send to agent"))
      .child(list.length ? v_flex().children(list.map(row)) : div().px(10).text_color(t.dim).child("No agent in this tab or space"));
  }
}
