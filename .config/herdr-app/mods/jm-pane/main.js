// The shipped `pane` header plus iTerm2-style pane numbers:
//   { "tab": "active", "pane": { "header": { "content": { "mod": "jm-pane" } } } }
// Each header shows its pane's number in the tab; keys.json binds
// "alt-<n>": "jm-pane.<n>", and the header whose number is <n> focuses its pane.

import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { agents, focused, panes, props, run, theme, home, layout, nextCommand, shared, setShared } from "herdr";

// Match the first visible tab frame, including the active child of a stack.
function paneFrame(node) {
  if (!node || node.hidden) return null;
  if (node.content?.tab && node.content.pane) return node.content.pane;
  let children = node.children ?? [];
  if (node.type === "stack") {
    const visible = children.filter(child => !child.hidden);
    children = [visible.find(child => child.id === node.active) ?? visible[0]];
  }
  for (const child of children) {
    const frame = paneFrame(child);
    if (frame) return frame;
  }
  return null;
}

function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

// The session summary agents put in the terminal title, without the agent name or status symbol.
function clean(title) {
  return (title || "").replace(/\s+-\s+GitHub Copilot$/, "").replace(/^[^\p{L}\p{N}\p{P}\s]+\s*/u, "").trim();
}

function summary(p, name) {
  if (!p.program?.agent) return "";
  const text = clean(p.title);
  return text === name ? "" : text;
}

// Every agent's summary by terminal address, persisted in shared.json for other tools (Hammerspoon's agent picker).
const SUMMARIES = "jm-pane.summaries";

function publishSummaries() {
  const summaries = {};
  for (const a of agents()) {
    const text = clean(a.title);
    if (text) summaries[a.address] = text;
  }
  const sorted = (o) => JSON.stringify(Object.entries(o ?? {}).sort());
  if (sorted(shared(SUMMARIES)) !== sorted(summaries)) setShared(SUMMARIES, summaries);
}

// While the shown tab is zoomed over hidden panes, the layout's pane frame turns red and thick.
// The normal look is kept in shared.json so it survives a restart mid-zoom.
const FRAME = "jm-pane.frame";
const ZOOM_WIDTH = 2;
const ZOOM_ALPHA = "80";

function zoomColor(t) {
  return (t.ansi3 ?? "#e5c07b").slice(0, 7);
}
const NORMAL_LOOK = { border: { width: 1, color: "border" }, focus: { width: 1, color: "accent" } };
let frameWanted = null;

function isZoomLook(look) {
  return look?.width === ZOOM_WIDTH && /^#[0-9a-f]{6}/i.test(look?.color ?? "") && look.color.endsWith(ZOOM_ALPHA);
}

function syncFrame() {
  const tab = focused()?.tab;
  const inTab = panes().filter((p) => p.tab === tab);
  const zoomed = inTab.length > 1 && inTab.some((p) => p.zoomed);
  const tree = JSON.parse(JSON.stringify(layout()));
  const frame = paneFrame(tree);
  if (!frame) return;
  const showing = isZoomLook(frame.focus);
  if (showing === zoomed) {
    frameWanted = null;
    return;
  }
  if (frameWanted === zoomed) return;
  frameWanted = zoomed;
  if (zoomed) {
    setShared(FRAME, { border: frame.border, focus: frame.focus });
    const look = { width: ZOOM_WIDTH, color: zoomColor(theme()) + ZOOM_ALPHA };
    frame.border = { ...look };
    frame.focus = { ...look };
  } else {
    const normal = shared(FRAME) ?? NORMAL_LOOK;
    frame.border = normal.border ?? NORMAL_LOOK.border;
    frame.focus = normal.focus ?? NORMAL_LOOK.focus;
  }
  run("layout.set", { layout: tree });
}

function folder(cwd) {
  if (!cwd) return "";
  const h = home();
  return cwd === h ? "~" : cwd.startsWith(h + "/") ? "~" + cwd.slice(h.length) : cwd;
}

export default class Pane extends View {
  init(_props, cx) {
    this.hovered = false;
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        const pane = props()?.pane;
        if (pane && c === String(this.number(pane))) run("pane.focus", { pane });
        cx.notify();
      }
    });
  }

  me() {
    return panes().find((p) => p.pane === props()?.pane);
  }

  // 1-based position of the pane among its tab's panes.
  number(pane) {
    const all = panes();
    const tab = all.find((p) => p.pane === pane)?.tab;
    return all.filter((p) => p.tab === tab).findIndex((p) => p.pane === pane) + 1;
  }

  button(t, id, icon, command, args) {
    return div()
      .id(id)
      .p(3)
      .rounded(4)
      .text_color(t.dim)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => {
        cx.stop_propagation();
        run(command, args);
      })
      .child(svg(`mods/pane/${icon}.svg`).size(14));
  }

  // Pill shown on a zoomed pane that hides others in its tab; clicking it unzooms.
  zoomedBadge(t, pane, hidden) {
    const urgent = zoomColor(t);
    return h_flex()
      .id(`ph-zoomed-${pane}`)
      .flex_none()
      .gap(4)
      .px(6)
      .h(18)
      .items_center()
      .rounded(5)
      .bg(urgent + "26")
      .border_1()
      .border_color(urgent + "66")
      .text_size(10.5)
      .font_semibold()
      .text_color(urgent)
      .cursor_pointer()
      .hover((s) => s.bg(urgent + "40"))
      .tooltip("Zoomed: other panes in this tab are hidden. Click to unzoom.")
      .on_click((_e, cx) => {
        cx.stop_propagation();
        run("pane.zoom", { pane });
      })
      .child(svg("mods/pane/zoom.svg").size(11).flex_none())
      .child(`ZOOMED · ${hidden.length} hidden`);
  }

  render(cx) {
    const t = theme();
    const p = this.me();
    if (!p) return div();
    const name = ((p.program?.agent || p.program?.shell) && p.program.name) || p.title || p.program?.name || "shell";
    const about = summary(p, name);
    publishSummaries();
    syncFrame();
    const pic = icon(p.program, 14, t.dim);
    const st = p.status;
    const pane = p.pane;
    const bottom = paneFrame(layout())?.header?.position === "bottom";
    const hidden = p.zoomed ? panes().filter((o) => o.tab === p.tab && o.pane !== pane) : [];
    const zoomed = hidden.length > 0;
    return h_flex()
      .id(`pane-head-${pane}`)
      .size_full()
      .px(10)
      .gap(8)
      .items_center()
      .bg(zoomed ? zoomColor(t) + "0d" : t.background)
      .when(bottom, el => el.border_t(1))
      .when(!bottom, el => el.border_b(1))
      .border_color(zoomed ? zoomColor(t) + ZOOM_ALPHA : t.border)
      .text_size(12)
      .on_hover((hovered, cx) => { this.hovered = hovered; cx.notify(); })
      .on_click(() => run("pane.focus", { pane }))
      .child(div().flex_none().text_color(p.focused ? t.accent : t.dim).font_semibold().child(`⌥${this.number(pane)}`))
      .when(Boolean(pic), (el) => el.child(pic))
      .child(div().flex_none().truncate().max_w(260).font_medium().text_color(t.foreground).child(name))
      .when(Boolean(about), el => el.child(div().flex_shrink(1).min_w(0).truncate().text_color(t.foreground).child(about)))
      .child(div().flex_1().truncate().text_color(t.dim).child(folder(p.cwd)))
      .when(zoomed, el => el.child(this.zoomedBadge(t, pane, hidden)))
      .when(st === "working", el => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
      .when(st === "blocked", el => el.child(div().flex_none().px(6).h(18).flex().items_center().rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).child("Needs you")))
      .when(st === "done", el => el.child(div().size(7).flex_none().rounded(4).bg(t.done)))
      .when(this.hovered, el => el
        .child(this.button(t, `ph-r-${pane}`, "split-right", "pane.split", { direction: "right", pane }))
        .child(this.button(t, `ph-d-${pane}`, "split-down", "pane.split", { direction: "down", pane }))
        .child(this.button(t, `ph-z-${pane}`, p.zoomed ? "unzoom" : "zoom", "pane.zoom", { pane }))
        .child(this.button(t, `ph-x-${pane}`, "close", "pane.close", { pane })));
  }
}
