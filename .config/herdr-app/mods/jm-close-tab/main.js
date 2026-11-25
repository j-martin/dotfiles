// Opened as a dialog by cmd-shift-w
// (mod.open:jm-close-tab): asks before closing the shown tab.
// cmd-w closes a pane (or its space) in ../jm-close-pane.

import { run, spaces } from "herdr";
import { Ask } from "./ask.js";

export default class CloseTab extends Ask {
  setup() {
    const space = spaces().find((s) => s.active);
    const tab = space?.tabs.find((t) => t.active);
    if (!tab) {
      this.title = "No tab to close";
      return;
    }
    this.title = `Close tab "${tab.name}"?`;
    this.detail = space.tabs.length === 1 ? `It is the last tab: the space "${space.name}" closes too.` : `Its ${tab.panes} pane(s) and their programs end.`;
    this.ok = () => run("tab.close", { id: tab.id, confirmed: true });
  }
}
