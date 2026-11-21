// node --test mods/jm-pane-balance/balance.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { balance, differs, findTab, localId, UnknownShape } from "./balance.js";

const pane = (id, weight) => ({ type: "block", id, content: { terminal: id }, ...(weight ? { size: { weight } } : {}) });
const weights = (node) => node.children.map((k) => k.size.weight);

test("row with a nested row: every pane gets the same width", () => {
  const root = { type: "row", id: "r", children: [pane("a", 0.5), { type: "row", id: "n", size: { weight: 0.5 }, children: [pane("b"), pane("c")] }] };
  const out = balance(root);
  assert.deepEqual(weights(out), [1 / 3, 2 / 3]);
  assert.deepEqual(weights(out.children[1]), [0.5, 0.5]);
  assert.equal(root.children[0].size.weight, 0.5, "input is not mutated");
});

test("evens both axes at once in a mixed tree", () => {
  // A | (B over C over D): A takes 1/2 width, B/C/D 1/3 height each.
  const right = { type: "column", id: "col", size: { weight: 0.8 }, children: [pane("b", 0.7), pane("c", 0.2), pane("d", 0.1)] };
  const out = balance({ type: "row", id: "r", children: [pane("a", 0.2), right] });
  assert.deepEqual(weights(out), [0.5, 0.5]);
  assert.deepEqual(weights(out.children[1]), [1 / 3, 1 / 3, 1 / 3]);
});

test("a balanced tree does not differ beyond f32 noise", () => {
  const root = { type: "column", id: "c", children: [pane("a", 0.3333333432674408), pane("b", 0.3333333432674408), pane("c", 0.3333333432674408)] };
  assert.equal(differs(balance(root), root), false);
  assert.equal(differs(root, { ...root, children: [pane("a", 0.6), ...root.children.slice(1)] }), true);
});

test("refuses shapes it doesn't know", () => {
  assert.throws(() => balance({ type: "stack", children: [pane("a")] }), UnknownShape);
  assert.throws(() => balance({ type: "row", children: [] }), UnknownShape);
  assert.throws(() => balance({ type: "row", children: [{ ...pane("a"), size: { px: 200 } }, pane("b")] }), UnknownShape);
});

test("finds remote tabs by their bare id", () => {
  assert.equal(localId("box/t1", "box"), "t1");
  assert.equal(localId("t1", null), "t1");
  const doc = { spaces: [{ tabs: [{ id: "t0" }] }, { tabs: [{ id: "t1", root: pane("a") }] }] };
  assert.equal(findTab(doc, "t1").root.id, "a");
  assert.throws(() => findTab(doc, "nope"), UnknownShape);
});
