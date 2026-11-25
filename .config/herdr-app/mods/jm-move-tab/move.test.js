// node --test mods/jm-move-tab/move.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { baseName, duplicateGroups, folderSpace, freshId, localId, offersNewTab, spaceChoices, tabChoices } from "./move.js";

const tab = (id, name = id) => ({ id, name });
const space = (id, name, tabs, machine = null) => ({ id, name, machine, active: false, tabs });

test("localId: drops a remote machine prefix", () => {
  assert.equal(localId("mac/sp1"), "sp1");
  assert.equal(localId("sp1"), "sp1");
});

test("freshId: a new id each time, shaped like Herdr's", () => {
  const a = freshId("tb");
  assert.match(a, /^tb[0-9a-f]{32}$/);
  assert.notEqual(a, freshId("tb"));
});

test("spaceChoices: a tab's spaces on its machine, its own while it has another tab", () => {
  const src = space("a", "api", [tab("t1"), tab("t2")]);
  const all = [src, space("b", "web", [tab("t3")]), space("mac/c", "remote", [tab("t4")], "mac")];
  assert.deepEqual(spaceChoices(all, src, "t1", "tab", "").map((s) => s.id), ["a", "b"]);
  const alone = space("a", "api", [tab("t1")]);
  assert.deepEqual(spaceChoices([alone, all[1]], alone, "t1", "tab", "").map((s) => s.id), ["b"]);
});

test("spaceChoices: a pane can always stay in its space (to a new tab)", () => {
  const alone = space("a", "api", [tab("t1")]);
  assert.deepEqual(spaceChoices([alone, space("b", "web", [tab("t2")])], alone, "t1", "pane", "").map((s) => s.id), ["a", "b"]);
});

test("spaceChoices: filters by name, any case", () => {
  const src = space("a", "api", [tab("t1")]);
  const all = [src, space("b", "Web", [tab("t2")]), space("d", "docs", [tab("t3")])];
  assert.deepEqual(spaceChoices(all, src, "t1", "tab", " WE ").map((s) => s.id), ["b"]);
});

test("offersNewTab: not for a whole tab in its own space", () => {
  const src = space("a", "api", [tab("t1")]);
  const other = space("b", "web", [tab("t2")]);
  assert.equal(offersNewTab(src, src, "tab"), false);
  assert.equal(offersNewTab(src, src, "pane"), true);
  assert.equal(offersNewTab(other, src, "tab"), true);
});

test("tabChoices: the space's other tabs, filtered by name", () => {
  const s = space("a", "api", [tab("t1", "build"), tab("t2", "Logs"), tab("t3", "shell")]);
  assert.deepEqual(tabChoices(s, "t1", "").map((t) => t.id), ["t2", "t3"]);
  assert.deepEqual(tabChoices(s, "t1", "log").map((t) => t.id), ["t2"]);
});

test("baseName: the last part, trailing slash or not", () => {
  assert.equal(baseName("/src/api/"), "api");
  assert.equal(baseName("/"), "/");
});

test("folderSpace: the space whose first terminal is in the folder", () => {
  const src = space("a", "api", [tab("t1")]);
  const web = space("b", "web", [tab("t2")]);
  const ps = [{ tab: "t1", cwd: "/src/api" }, { tab: "t2", cwd: "/src/web/pkg" }];
  assert.equal(folderSpace([src, web], src, ps, "/src/web")?.id, "b");
  assert.equal(folderSpace([src, web], src, ps, "/src/we"), null);
});

test("folderSpace: else one named after it, on the source's machine only", () => {
  const src = space("a", "api", [tab("t1")]);
  const named = space("b", "web", [tab("t2")]);
  const remote = space("mac/c", "docs", [tab("t3")], "mac");
  const ps = [{ tab: "t3", cwd: "/src/docs" }];
  assert.equal(folderSpace([src, named, remote], src, ps, "/elsewhere/web")?.id, "b");
  assert.equal(folderSpace([src, named, remote], src, ps, "/src/docs"), null);
});

test("duplicateGroups: same name any case, per machine, into the shown one else the first", () => {
  const a = space("a", "infra", [tab("t1")]);
  const b = space("b", "Infra", [tab("t2")]);
  const c = { ...space("c", "infra", [tab("t3")]), active: true };
  const remote = space("mac/d", "infra", [tab("t4")], "mac");
  const lone = space("e", "web", [tab("t5")]);
  const groups = duplicateGroups([a, b, c, remote, lone]);
  assert.deepEqual(groups.map((g) => [g.into.id, g.from.map((s) => s.id)]), [["c", ["a", "b"]]]);
  assert.deepEqual(duplicateGroups([a, lone]), []);
  assert.equal(duplicateGroups([a, b])[0].into.id, "a");
});
