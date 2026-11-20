// A confirmation dialog (kept in sync with ../jm-close-pane/ask.js; mods cannot import across folders): subclasses set
// this.title, this.detail and this.ok (null: nothing to do) in setup().
// Enter confirms, Esc cancels.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { props, closeOverlay, theme } from "herdr";

export class Ask extends View {
  init(_props, cx) {
    this.title = "";
    this.detail = "";
    this.ok = null;
    this.setup();
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  setup() {}

  close() {
    closeOverlay(props().overlay);
  }

  yes() {
    this.close();
    this.ok?.();
  }

  render(cx) {
    const t = theme();
    const button = (id, label, bg, fg, onClick) =>
      h_flex().id(id).h(32).px(14).items_center().rounded(8).border_1().border_color(id === "no" ? t.input : bg).bg(bg).text_color(fg).cursor_pointer().hover((s) => s.opacity(0.88)).on_click(onClick).child(label);
    return v_flex()
      .id("ask")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (e.key === "enter") this.yes();
        else if (e.key === "escape") this.close();
        else return;
        cx.stop_propagation();
      })
      .size_full()
      .min_h(0)
      .p(18)
      .gap(12)
      .rounded(8)
      .bg(t.popover)
      .text_size(13)
      .child(h_flex().items_center().gap(8).child(div().flex_1().min_w(0).truncate().text_size(15).font_semibold().text_color(t.foreground).child(this.title)).child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(div().flex_1().min_h(0).text_color(t.muted).child(this.detail))
      .child(
        h_flex()
          .justify_end()
          .gap(8)
          .text_size(12)
          .child(button("no", "Cancel", t.raised, t.foreground, () => this.close()))
          .when(Boolean(this.ok), (el) => el.child(button("yes", "Close", t.solid, t.solid_foreground, () => this.yes()))),
      );
  }
}
