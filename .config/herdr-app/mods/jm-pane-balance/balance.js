// @ts-check
// Pure split-tree math for jm-pane-balance; no Herdr imports, so node can test it.
// A tab's `root` in herdr-core's "herdr-app" doc is a tree of
// { type: "row" | "column", children } and { type: "block" } (a pane). A child's
// `size` is { weight } (relative, flex-grow); the app omits it for weight 1.

/**
 * @typedef {{ type: string, id?: string, size?: unknown, children?: SplitNode[], [key: string]: unknown }} SplitNode
 * @typedef {{ row: number, column: number }} Span
 * @typedef {{ id?: string, root?: SplitNode, [key: string]: unknown }} DocTab
 * @typedef {{ spaces?: { tabs?: DocTab[] }[], [key: string]: unknown }} AppDoc
 */

const KNOWN = new Set(["row", "column", "block"]);
const EPSILON = 1e-6;

export class UnknownShape extends Error {}

/**
 * Leaf count of a node along each axis: a row sums its children's widths and
 * takes the widest column, a column the other way round.
 * @param {SplitNode} node
 * @returns {Span}
 */
export function span(node) {
  if (!node || !KNOWN.has(node.type)) throw new UnknownShape(`unknown node type ${JSON.stringify(node?.type)}`);
  if (node.type === "block") return { row: 1, column: 1 };
  const kids = node.children;
  if (!Array.isArray(kids) || kids.length === 0) throw new UnknownShape(`${node.type} ${node.id} has no children`);
  const spans = kids.map(span);
  /** @param {keyof Span} axis */
  const sum = (axis) => spans.reduce((total, s) => total + s[axis], 0);
  /** @param {keyof Span} axis */
  const max = (axis) => Math.max(...spans.map((s) => s[axis]));
  return node.type === "row" ? { row: sum("row"), column: max("column") } : { row: max("row"), column: sum("column") };
}

/**
 * A copy of root where every row gives each child a width share equal to its
 * leaf panes along the row, and every column likewise for heights, so all
 * panes end up the same size along both axes (vim's <C-w>=).
 * @param {SplitNode} root
 * @returns {SplitNode}
 */
export function balance(root) {
  span(root);
  /** @type {SplitNode} */
  const tree = JSON.parse(JSON.stringify(root));
  /** @param {SplitNode} node */
  const walk = (node) => {
    if (node.type === "block") return;
    const kids = node.children ?? [];
    kids.forEach(walk);
    const axis = /** @type {keyof Span} */ (node.type);
    const spans = kids.map((k) => span(k)[axis]);
    const total = spans.reduce((a, b) => a + b, 0);
    kids.forEach((kid, i) => {
      const size = kid.size ?? { weight: 1 };
      if (typeof size !== "object" || Object.keys(size).join() !== "weight") {
        throw new UnknownShape(`pane ${kid.id} has size ${JSON.stringify(size)}`);
      }
      kid.size = { weight: spans[i] / total };
    });
  };
  walk(tree);
  return tree;
}

/**
 * Whether two trees differ beyond float noise (the app stores weights as f32).
 * @param {unknown} a
 * @param {unknown} b
 * @returns {boolean}
 */
export function differs(a, b) {
  if (typeof a === "number" && typeof b === "number") return Math.abs(a - b) > EPSILON;
  if (Array.isArray(a) && Array.isArray(b)) return a.length !== b.length || a.some((x, i) => differs(x, b[i]));
  if (a && b && typeof a === "object" && typeof b === "object") {
    const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
    return [...keys].some((k) => differs(/** @type {any} */ (a)[k], /** @type {any} */ (b)[k]));
  }
  return a !== b;
}

/**
 * The app shows a remote tab as "<machine>/<id>"; that machine's own doc stores the bare id.
 * @param {string} tabId
 * @param {string | null | undefined} machine
 * @returns {string}
 */
export function localId(tabId, machine) {
  const prefix = machine ? `${machine}/` : "";
  return prefix && tabId.startsWith(prefix) ? tabId.slice(prefix.length) : tabId;
}

/**
 * @param {AppDoc} doc
 * @param {string} tabId
 * @returns {DocTab}
 */
export function findTab(doc, tabId) {
  for (const space of doc?.spaces ?? []) {
    for (const tab of space.tabs ?? []) if (tab.id === tabId) return tab;
  }
  throw new UnknownShape(`tab ${tabId} not found`);
}
