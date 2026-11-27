// cmd-shift-w (mod.open:jm-close-pane-now): closes the focused pane (e.g. an agent), or its space when it is
// the space's last pane, without asking. cmd-w asks first in ../jm-close-pane.

import { View, div } from "gpui-kit";
import { run, panes, spaces, focused, props, closeOverlay } from "herdr";

export default class ClosePaneNow extends View {
  init() {
    closeOverlay(props().overlay);
    const paneId = focused()?.pane;
    const pane = paneId ? panes().find((p) => p.pane === paneId) : null;
    if (!pane) {
      return;
    }
    const space = spaces().find((s) => s.tabs.some((t) => t.id === pane.tab));
    if (space?.tabs.length === 1 && space.tabs[0].panes === 1) {
      run("space.close", { id: space.id, confirmed: true });
      return;
    }
    run("pane.close", { pane: pane.pane });
  }

  render() {
    return div();
  }
}
