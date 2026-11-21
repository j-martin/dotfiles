// @ts-check
// cmd-alt-= (mod.open:jm-pane-balance): gives every pane of the focused tab the
// same size along both axes. Herdr has no pane resize command, so this edits the
// tab's split tree in herdr-core's undocumented "herdr-app" doc (doc.get/doc.set
// over `hc connect`), refusing any shape it doesn't know. Opens as a 1x1 popup
// and closes itself once done: closing earlier cancels the pending write.

import { View, div } from "gpui-kit";
import { checking, closeOverlay, exec, focused, notify, props, spaces } from "herdr";
import { balance, differs, findTab, localId } from "./balance.js";

const DOC = "herdr-app";

/**
 * One JSON-RPC call to herdr-core. `exec` has no stdin, so sh pipes the request in.
 * @param {string} method
 * @param {Record<string, unknown>} params
 * @returns {Promise<any>}
 */
async function rpc(method, params) {
  const request = JSON.stringify({ jsonrpc: "2.0", id: 1, method, params });
  const r = await exec("/bin/sh", ["-c", 'printf "%s\\n" "$1" | hc connect --json', "sh", request], { timeout: 10_000 });
  const line = r.stdout.split("\n").find((l) => l.trim());
  if (!line) throw new Error(`hc connect gave no reply: ${r.stderr.trim()}`);
  const reply = JSON.parse(line);
  if (reply.error) throw new Error(`${method}: ${reply.error.message ?? JSON.stringify(reply.error)}`);
  return reply.result;
}

/**
 * @param {string} tabId as the app shows it
 * @param {string | null} machine
 * @returns {Promise<void>}
 */
async function balanceTab(tabId, machine) {
  const on = machine ? { on: machine } : {};
  const id = localId(tabId, machine);
  for (let attempt = 1; ; attempt++) {
    const { value, version } = await rpc("doc.get", { name: DOC, ...on });
    const tab = findTab(value, id);
    if (!tab.root) throw new Error(`tab ${id} has no root`);
    const root = balance(tab.root);
    if (!differs(root, tab.root)) return;
    tab.root = root;
    try {
      await rpc("doc.set", { name: DOC, value, version, ...on });
      return;
    } catch (e) {
      // The app wrote in between: read the new version and retry once.
      if (attempt >= 2) throw e;
    }
  }
}

export default class PaneBalance extends View {
  init() {
    const done = () => {
      const overlay = props()?.overlay;
      if (overlay != null) closeOverlay(overlay);
    };
    const f = focused();
    if (checking() || !f?.tab) return done();
    const machine = spaces().find((s) => s.id === f.space)?.machine ?? null;
    balanceTab(f.tab, machine)
      .catch((e) => notify({ title: "Balance panes failed", body: String(e?.message ?? e), level: "error" }))
      .finally(done);
  }

  render() {
    return div();
  }
}
