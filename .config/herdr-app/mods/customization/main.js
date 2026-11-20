// Personal customizations. Opened as a dialog (cmd-shift-w via
// mod.open:customization), it asks before closing the shown tab.
// Enter confirms, Esc cancels.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, theme, spaces } from "herdr";

export default class Customization extends View {
  init(_props, cx) {
    const space = spaces().find((s) => s.active);
    this.space = space;
    this.tab = space?.tabs.find((t) => t.active);
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  close() {
    closeOverlay(props().overlay);
  }

  yes() {
    this.close();
    if (this.tab) run("tab.close", { id: this.tab.id, confirmed: true });
  }

  render(cx) {
    const t = theme();
    const tab = this.tab;
    const last = this.space && this.space.tabs.length === 1;
    const title = tab ? `Close tab "${tab.name}"?` : "No tab to close";
    const detail = !tab ? "" : last ? `It is the last tab: the space "${this.space.name}" closes too.` : `Its ${tab.panes} pane(s) and their programs end.`;
    const button = (id, label, bg, fg, onClick) =>
      h_flex().id(id).h(32).px(14).items_center().rounded(8).border_1().border_color(id === "no" ? t.input : bg).bg(bg).text_color(fg).cursor_pointer().hover((s) => s.opacity(0.88)).on_click(onClick).child(label);
    return v_flex()
      .id("customization")
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
      .child(h_flex().items_center().gap(8).child(div().flex_1().min_w(0).truncate().text_size(15).font_semibold().text_color(t.foreground).child(title)).child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(div().flex_1().min_h(0).text_color(t.muted).child(detail))
      .child(
        h_flex()
          .justify_end()
          .gap(8)
          .text_size(12)
          .child(button("no", "Cancel", t.raised, t.foreground, () => this.close()))
          .when(Boolean(tab), (el) => el.child(button("yes", "Close", t.solid, t.solid_foreground, () => this.yes()))),
      );
  }
}
