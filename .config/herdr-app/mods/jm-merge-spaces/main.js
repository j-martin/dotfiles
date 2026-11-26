// @ts-check
// cmd-alt-m (mod.open:jm-merge-spaces): merges duplicate spaces. Mods can't import each other,
// so this opens jm-move-tab with { merge: true }, which does it, then closes itself.

import { View, div } from "gpui-kit";
import { checking, closeOverlay, openOverlay, props } from "herdr";

export default class MergeSpaces extends View {
  init() {
    if (checking()) {
      return;
    }
    openOverlay({ mod: "jm-move-tab", kind: "popup", width: 460, height: 0.6, props: { merge: true } });
    closeOverlay(props().overlay);
  }

  render() {
    return div();
  }
}
