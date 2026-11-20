// cmd-w (mod.open:customization-pane): closes the focused pane at once,
// but asks first when an agent runs in it.

import { run, panes, focused } from "herdr";
import { Ask } from "./ask.js";

export default class ClosePane extends Ask {
  setup() {
    const paneId = focused()?.pane;
    const pane = paneId ? panes().find((p) => p.pane === paneId) : null;
    if (!pane) {
      this.title = "No pane to close";
      return;
    }
    const close = () => run("pane.close", { pane: pane.pane });
    if (!(pane.status || pane.program?.agent)) {
      this.close();
      close();
      return;
    }
    this.title = `Close agent "${pane.program?.name ?? pane.title}"?`;
    this.detail = `It is ${pane.status ?? "running"}; closing the pane ends it.`;
    this.ok = close;
  }
}
