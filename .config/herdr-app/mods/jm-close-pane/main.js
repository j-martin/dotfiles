// cmd-w (mod.open:jm-close-pane): closes the focused pane, or its space when it is the
// space's last pane, without Herdr's own confirmation. Asks first unless zsh is in the foreground.

import { run, panes, spaces, focused } from "herdr";
import { Ask } from "./ask.js";

export default class ClosePane extends Ask {
  setup() {
    const paneId = focused()?.pane;
    const pane = paneId ? panes().find((p) => p.pane === paneId) : null;
    if (!pane) {
      this.title = "No pane to close";
      return;
    }
    const space = spaces().find((s) => s.tabs.some((t) => t.id === pane.tab));
    const last = space?.tabs.length === 1 && space.tabs[0].panes === 1;
    const close = last ? () => run("space.close", { id: space.id, confirmed: true }) : () => run("pane.close", { pane: pane.pane });
    if (!pane.terminal || pane.program?.name === "zsh") {
      this.close();
      close();
      return;
    }
    const name = pane.program?.name ?? pane.title;
    this.title = `Close "${name}"?`;
    this.detail = `${pane.status ? `It is ${pane.status}; closing` : "It is still running; closing"} the pane ends it.${last ? ` It is the last pane: the space "${space.name}" closes too.` : ""}`;
    this.ok = close;
  }
}
