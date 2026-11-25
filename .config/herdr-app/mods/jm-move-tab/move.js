// @ts-check
// Pure logic for jm-move-tab; no Herdr imports, so node can test it.

import { randomBytes } from "crypto";

/**
 * @typedef {{ id: string, name: string }} Tab
 * @typedef {{ id: string, name: string, folder?: string, machine: string | null, active: boolean, tabs: Tab[] }} Space
 * @typedef {{ tab: string, cwd: string | null }} Pane
 */

/**
 * An id as the labels on its machine write it: remote ids drop their `machine/` prefix.
 * @param {string} id
 * @returns {string}
 */
export const localId = (id) => id.slice(id.lastIndexOf("/") + 1);

/**
 * A space or tab id Herdr doesn't know yet, so a terminal labelled with it gets a new one.
 * @param {"sp" | "tb"} prefix
 * @returns {string}
 */
export const freshId = (prefix) => `${prefix}${randomBytes(16).toString("hex")}`;

/**
 * Whether the text contains the filter, any case.
 * @param {string} text
 * @param {string} filter
 * @returns {boolean}
 */
export const matches = (text, filter) => text.toLowerCase().includes(filter.trim().toLowerCase());

/**
 * The spaces a tab or pane can move to: those on its space's machine (labels and panes are
 * local), in order, filtered by name. A tab's own space counts only while it has another tab
 * to join; a pane can always go to a new tab of its own space.
 * @param {Space[]} all
 * @param {Space} source
 * @param {string} tab the source tab's id
 * @param {"tab" | "pane"} what
 * @param {string} filter
 * @returns {Space[]}
 */
export const spaceChoices = (all, source, tab, what, filter) =>
  all.filter(
    (s) => (s.machine ?? null) === (source.machine ?? null) && (what === "pane" || s.id !== source.id || s.tabs.some((t) => t.id !== tab)) && matches(s.name, filter),
  );

/**
 * The tabs of a space to join (never the source tab), filtered by name.
 * @param {Space} space
 * @param {string} tab the source tab's id
 * @param {string} filter
 * @returns {Tab[]}
 */
export const tabChoices = (space, tab, filter) => space.tabs.filter((t) => t.id !== tab && matches(t.name, filter));

/**
 * Whether "New tab" makes sense in a space: not for a whole tab already in it.
 * @param {Space} space
 * @param {Space} source
 * @param {"tab" | "pane"} what
 * @returns {boolean}
 */
export const offersNewTab = (space, source, what) => what === "pane" || space.id !== source.id;

/**
 * The last part of a path.
 * @param {string} path
 * @returns {string}
 */
export const baseName = (path) => path.replace(/\/+$/, "").split("/").pop() || path;

/**
 * Where a space is now: its first terminal's live folder, else where it was made.
 * @param {Space} space
 * @param {Pane[]} panes
 * @returns {string}
 */
export const spacePlace = (space, panes) => {
  const tabs = new Set(space.tabs.map((t) => t.id));
  return panes.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || space.folder || "";
};

/**
 * The space on the source's machine for a folder (a repo's root, else a cwd): one that is
 * in it now, else one named after it, else null.
 * @param {Space[]} all
 * @param {Space} source
 * @param {Pane[]} panes those that stay, so what moves doesn't count
 * @param {string} folder
 * @returns {Space | null}
 */
export const folderSpace = (all, source, panes, folder) => {
  const mine = all.filter((s) => (s.machine ?? null) === (source.machine ?? null));
  const root = folder.replace(/\/+$/, "");
  const inside = (/** @type {string} */ p) => p === root || p.startsWith(`${root}/`);
  return mine.find((s) => inside(spacePlace(s, panes))) ?? mine.find((s) => s.name === baseName(root)) ?? null;
};

/**
 * Spaces sharing a name (any case) on one machine, each group as the space its tabs go to (the
 * shown one, else the first) and the others, in order.
 * @param {Space[]} all
 * @returns {{ into: Space, from: Space[] }[]}
 */
export const duplicateGroups = (all) => {
  /** @type {Map<string, Space[]>} */
  const groups = new Map();
  for (const s of all) {
    const key = `${s.machine ?? ""}\n${s.name.toLowerCase()}`;
    groups.set(key, [...(groups.get(key) ?? []), s]);
  }
  return [...groups.values()]
    .filter((g) => g.length > 1)
    .map((g) => {
      const into = g.find((s) => s.active) ?? g[0];
      return { into, from: g.filter((s) => s !== into) };
    });
};
