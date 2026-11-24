// node --test mods/jm-goto/goto.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildRows, describePane, filterRows } from "./goto.js";

const HOME = "/Users/me";
const claude = { name: "Claude Code", agent: true };
const zsh = { name: "zsh", agent: false, shell: true };
const pane = (pane, tab, program, extra = {}) => ({ pane, tab, terminal: `t-${pane}`, program, title: "", name: null, cwd: null, branch: null, focused: false, status: null, ...extra });
const spaces = [
  { id: "s1", name: "api", machine: null, branch: "main", active: true, status: null, tabs: [{ id: "t1", name: "1", active: true, status: null }] },
  { id: "s2", name: "web", machine: null, branch: null, active: false, status: null, tabs: [{ id: "t2", name: "logs", active: true, status: null }] },
];
const panes = [
  pane("p1", "t1", claude, { title: "✳ Fix the login bug", cwd: `${HOME}/src/api`, branch: "main", focused: true }),
  pane("p2", "t1", zsh, { title: "zsh", cwd: HOME }),
  pane("p3", "t2", { name: "nvim", agent: false }, { title: "README.md", cwd: `${HOME}/src/web` }),
];

test("describePane: an agent shows its session title without its status symbol", () => {
  assert.deepEqual(describePane(panes[0], HOME), { label: "Claude Code", title: "Fix the login bug", detail: "~/src/api (main)" });
});

test("describePane: a program shows its executable, title and folder", () => {
  assert.deepEqual(describePane(panes[2], HOME), { label: "nvim", title: "README.md", detail: "~/src/web" });
  assert.deepEqual(describePane(panes[1], HOME), { label: "zsh", title: "", detail: "~" });
  assert.equal(describePane({ ...panes[1], title: "me@box:~/src", cwd: `${HOME}/src` }, HOME).title, "");
});

test("describePane: a renamed pane keeps its program; a mod pane shows its mod", () => {
  assert.equal(describePane({ ...panes[1], name: "server" }, HOME).label, "server · zsh");
  assert.equal(describePane({ pane: "p9", tab: "t1", terminal: null, mod: "files", title: "files" }, HOME).label, "files");
});

test("describePane: a shell shows its last command instead of its title", () => {
  assert.equal(describePane(panes[1], HOME, "git status").title, "$ git status");
  assert.equal(describePane(panes[2], HOME, "ignored").title, "README.md");
});

test("buildRows: shells' last commands come from their terminal's label, and match the filter", () => {
  const rows = buildRows(spaces, panes, HOME, [{ address: "t-p2", labels: { "jm.last-command": "make deploy" } }]);
  assert.equal(rows.find((r) => r.id === "p2").title, "$ make deploy");
  assert.deepEqual(filterRows(rows, "deploy").map((r) => r.id), ["s1", "t1", "p2"]);
});

test("buildRows: spaces, then their tabs, then the tabs' panes", () => {
  const rows = buildRows(spaces, panes, HOME);
  assert.deepEqual(rows.map((r) => r.id), ["s1", "t1", "p1", "p2", "s2", "t2", "p3"]);
  assert.equal(rows.find((r) => r.id === "p1").active, true);
  assert.equal(rows.find((r) => r.id === "t1").detail, "2 panes");
});

test("filterRows: keeps the matches with their space and tab", () => {
  const rows = buildRows(spaces, panes, HOME);
  assert.deepEqual(filterRows(rows, "LOGIN").map((r) => r.id), ["s1", "t1", "p1"]);
  assert.deepEqual(filterRows(rows, "web nvim").map((r) => r.id), ["s2", "t2", "p3"]);
  assert.deepEqual(filterRows(rows, "api login nope").map((r) => r.id), []);
});

test("filterRows: a matching space shows everything in it", () => {
  const rows = buildRows(spaces, panes, HOME);
  assert.deepEqual(filterRows(rows, "web").map((r) => r.id), ["s2", "t2", "p3"]);
});
