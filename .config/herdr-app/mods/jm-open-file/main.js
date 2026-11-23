// Opens the file named by the focused terminal's selection, see paths.js for what it recognizes:
// cmd-o (mod.open:jm-open-file), the jm-menu right-click item "Open file", and cmd-click on what
// Herdr doesn't detect as a link, like bare filenames: Hammerspoon's apps/herdr.lua touches
// ~/.cache/herdr-cmd-click, double-clicks the word, then presses cmd-o; that run stays quiet.
// Other cmd-clicks go through link.js. The selected word is tried first, then its whole line.

import { View, div } from "gpui-kit";
import { props, run, exec, focused, closeOverlay, home, notify, terminals } from "herdr";
import { candidates, open, resolve, tokenAt } from "./paths.js";

async function copied() {
  run("terminal.copy");
  return (await exec("pbpaste")).stdout;
}

export default class OpenFile extends View {
  init(_props, cx) {
    const f = focused();
    cx.spawn(async () => {
      try {
        const marker = `${home()}/.cache/herdr-cmd-click`;
        const clicked = (await exec("rm", [marker])).code === 0;
        const warn = (body) => clicked || notify({ title: "Open file", body, level: "warning" });
        if (!f?.terminal) return notify({ title: "Open file", body: "No terminal is focused.", level: "warning" });
        const sel = f.selection;
        if (!sel) return warn("Select a path first (triple-click its line).");
        const word = await copied();
        // A word on one row (a double-click): read its whole line too, for line numbers,
        // git prefixes and what's around it.
        let list = candidates(word);
        if (sel.start.row === sel.end.row && !word.includes("\n")) {
          const col = Math.min(sel.start.col, sel.end.col);
          run("terminal.select", { terminal: f.terminal, at: { row: sel.start.row, col }, mode: "line" });
          const line = (await copied()).replace(/\n+$/, "");
          list = [...candidates(tokenAt(line, col)), ...list, ...candidates(line)];
        }
        const address = word.trim().match(/^(?:[\w.-]+\/)?t\d+$/)?.[0];
        if (address && clicked) return;
        if (address && terminals().some((t) => t.address === address)) return run("pane.focus", { terminal: address });
        const hit = await resolve(list, f.cwd, home(), exec);
        if (!hit) return warn(`No file found for: ${word.trim().slice(0, 120)}`);
        const r = await open(hit, home(), exec);
        if (r.code !== 0) notify({ title: "Open file", body: r.stderr.trim() || `Could not open ${hit.path}`, level: "error" });
      } finally {
        closeOverlay(props().overlay);
      }
    });
  }

  render() {
    return div();
  }
}
