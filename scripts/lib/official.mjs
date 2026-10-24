// Running the official pipeline: vega-lite compile, vega headless view, scenegraph export.
import * as vl from 'vega-lite';
import * as vega from 'vega';

const SKIP = new Set(['mark', 'datum', 'exit', 'group', 'context', 'zdirty', 'zitems', 'clip_id', 'index', 'bounds', 'items', 'marktype', 'name', 'role', 'interactive', 'clip', 'zindex', 'aria', 'description']);

function exportMark(m) {
  const out = { marktype: m.marktype };
  if (m.name) out.name = m.name;
  if (m.role) out.role = m.role;
  if (m.interactive === false) out.interactive = false;
  if (m.clip) out.clip = true;
  if (m.zindex) out.zindex = m.zindex;
  if (m.aria === false) out.aria = false;
  out.bounds = bounds(m.bounds);
  out.items = m.items.map((it) => {
    const o = {};
    for (const k of Object.keys(it)) {
      if (SKIP.has(k) && !(k === 'aria' || k === 'description')) continue;
      if (k === 'aria') { if (it.aria === false) o.aria = false; continue; }
      if (k === 'description') continue; // accessibility text is not part of the comparison
      if (k.startsWith('ariaRole')) continue;
      const v = it[k];
      if (v === undefined) continue;
      o[k] = v instanceof Date ? +v : v;
    }
    if (!m.marktype.match(/^(line|area)$/)) o.bounds = bounds(it.bounds);
    if (m.marktype === 'group') o.items = it.items.map(exportMark);
    return o;
  });
  return out;
}

function bounds(b) {
  return b ? { x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2 } : null;
}

export async function runOfficial(vlSpec) {
  const compiled = vl.compile(vlSpec).spec;
  const view = new vega.View(vega.parse(compiled), { renderer: 'none', logLevel: 0 });
  await view.runAsync();
  const scene = exportMark(view.scenegraph().root);
  scene.view = { width: view.width(), height: view.height(), origin: view.origin(), background: compiled.background ?? null };
  const svg = await view.toSVG();
  return { compiled, scene, svg, view };
}
