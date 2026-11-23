// Ctrl/Cmd-click on a link in a terminal. File paths in a local terminal open like cmd-o (see paths.js),
// at their line with ~/.bin/editor; URLs, remote terminals and paths it can't find pass to Herdr's opener.
// Every click touches ~/.cache/herdr-link-handled, for Hammerspoon's fallback on what Herdr doesn't
// detect, like bare filenames (apps/herdr.lua).

import { exec, home, notify } from "herdr";
import { candidates, open, resolve } from "./paths.js";

/** @type {import("herdr").HandleLink} */
export async function handleLink({ link, source }) {
  await exec("touch", [`${home()}/.cache/herdr-link-handled`]);
  if (link.kind !== "file" || source.machine) return "pass";
  const list = [...candidates(link.raw), ...(link.path ? [{ path: link.path }] : [])];
  const hit = await resolve(list, source.cwd, home(), exec);
  if (!hit) return "pass";
  const r = await open(hit, home(), exec);
  if (r.code !== 0) notify({ title: "Open file", body: r.stderr.trim() || `Could not open ${hit.path}`, level: "error" });
  return "handled";
}
