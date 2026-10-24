// Fixtures for scene/ and svg/: random scenegraphs; bounds and SVG text come from vega-scenegraph itself.
//   S|<id>|<scene json>           scene (root mark) as accepted by sceneFromJSON
//   O|<id>|w h ox oy bg           output options for the renderer
//   B|<id>|<path>|x1 y1 x2 y2     bounds (hex doubles); path = "" for the root mark, "i" for item i, "i.j" for child mark j of item i
//   V|<id>|<svg>                  SVG with accessibility role/label attributes removed
import * as vega from 'vega';
import { escLine } from '../lib/mbt.mjs';
import { makeRng } from '../lib/prng.mjs';
import { hex16 } from '../lib/prng.mjs';

const rng = makeRng(0x5ce11en);
const rnd = () => Number(rng() % 1000003n) / 1000003;
const pick = (xs) => xs[Math.floor(rnd() * xs.length)];
const r2 = (x) => Math.round(x * 100) / 100;
const num = (lo, hi) => r2(lo + rnd() * (hi - lo));
const maybe = (p, f) => (rnd() < p ? f() : undefined);
const colors = ['#4c78a8', '#f58518', 'red', 'steelblue', '#000', '#ddd', 'rgb(10, 20, 30)', 'transparent', 'none'];
const strokes = ['#888', '#000', 'black', '#e45756', '#ddd'];

function clean(o) {
  for (const k of Object.keys(o)) if (o[k] === undefined) delete o[k];
  return o;
}

function styled(item) {
  item.fill = maybe(0.6, () => pick(colors));
  item.fillOpacity = maybe(0.15, () => pick([0, 0.5, 1]));
  item.stroke = maybe(0.5, () => pick(strokes));
  item.strokeWidth = maybe(0.5, () => pick([0, 0.5, 1, 1.5, 2, 3]));
  item.strokeOpacity = maybe(0.1, () => pick([0, 0.4, 1]));
  item.strokeCap = maybe(0.1, () => pick(['butt', 'round', 'square']));
  item.strokeDash = maybe(0.15, () => pick([[4, 2], [1, 1], [5, 3, 1, 3]]));
  item.strokeDashOffset = maybe(0.05, () => 2);
  item.opacity = maybe(0.2, () => pick([0, 0.3, 1]));
  return item;
}

const rectItem = () => clean(styled({
  x: maybe(0.9, () => num(-10, 200)), y: maybe(0.9, () => num(-10, 200)), width: maybe(0.9, () => num(0, 80)), height: maybe(0.9, () => num(0, 80)),
  cornerRadius: maybe(0.15, () => pick([0, 2, 5, 40])), cornerRadiusTopLeft: maybe(0.05, () => 6), cornerRadiusBottomRight: maybe(0.05, () => 3),
}));
const ruleItem = () => clean(styled({ x: maybe(0.9, () => num(0, 100)), y: maybe(0.9, () => num(0, 100)), x2: maybe(0.6, () => num(0, 200)), y2: maybe(0.6, () => num(0, 200)), stroke: pick(strokes), strokeWidth: pick([1, 2, undefined]) }));
const texts = ['Hello', 'A', '', '0.5', 'Long label text here', '日本語', 12, 'a b  c', '  padded  ', 'x'];
const textItem = () => clean(styled({
  x: num(0, 150), y: num(0, 150), text: pick(texts), align: maybe(0.8, () => pick(['left', 'center', 'right'])),
  baseline: maybe(0.8, () => pick(['top', 'middle', 'bottom', 'alphabetic', 'line-top', 'line-bottom'])), angle: maybe(0.5, () => pick([0, 90, -90, 270, 45, 30, 315, 180])),
  dx: maybe(0.2, () => num(-5, 5)), dy: maybe(0.2, () => num(-5, 5)), fontSize: maybe(0.8, () => pick([9, 10, 11, 13, 20])), font: maybe(0.4, () => pick(['sans-serif', 'Arial'])),
  fontWeight: maybe(0.2, () => 'bold'), fontStyle: maybe(0.05, () => 'italic'), limit: maybe(0.3, () => pick([20, 50, 100])), ellipsis: maybe(0.05, () => '..'), lineHeight: maybe(0.1, () => 14),
  fill: pick(['#000', 'steelblue']), stroke: undefined, strokeWidth: undefined,
}));
const multiText = () => {
  const t = textItem();
  if (rnd() < 0.5) { t.text = ['first line', 'second', 'third one']; } else { t.text = 'one\ntwo\nthree'; t.lineBreak = '\n'; }
  return t;
};
const shapes = ['circle', 'square', 'cross', 'diamond', 'triangle-up', 'triangle-down', 'triangle-left', 'triangle-right', 'triangle', 'arrow', 'wedge', 'stroke'];
const symbolItem = () => clean(styled({ x: num(0, 150), y: num(0, 150), size: maybe(0.8, () => pick([0, 10, 30, 64, 100, 400])), shape: maybe(0.8, () => pick(shapes)), angle: maybe(0.2, () => pick([0, 45, 90, 33])) }));
function lineItems(kind) {
  const n = 2 + Math.floor(rnd() * 8);
  const xs = Array.from({ length: n }, (_, i) => r2(i * 15 + rnd() * 8));
  const first = styled({ stroke: pick(strokes), strokeWidth: pick([1, 2]), interpolate: pick(['linear', 'linear', 'step', 'step-before', 'step-after', 'monotone']), orient: maybe(0.3, () => pick(['horizontal', 'vertical'])) });
  if (kind === 'area') { first.fill = pick(colors); first.strokeWidth = pick([0, 1]); }
  return xs.map((x, i) => clean({
    ...(i === 0 ? first : {}), x, y: num(0, 100), height: kind === 'area' ? num(0, 30) : undefined, width: kind === 'area' ? num(0, 30) : undefined,
    defined: maybe(0.15, () => pick([false, true])),
  }));
}

function simpleMark(type, n) {
  const make = { rect: rectItem, rule: ruleItem, text: () => (rnd() < 0.25 ? multiText() : textItem()), symbol: symbolItem }[type];
  return clean({
    marktype: type, name: maybe(0.3, () => pick(['marks', 'foo'])), role: maybe(0.4, () => pick(['mark', 'axis-tick', 'axis-label'])),
    interactive: maybe(0.2, () => false), clip: undefined, zindex: undefined, items: Array.from({ length: n }, make),
  });
}
function pathMark(type) {
  return clean({ marktype: type, name: maybe(0.3, () => 'marks'), role: maybe(0.3, () => 'mark'), interactive: maybe(0.2, () => false), items: lineItems(type) });
}
function groupItem(depth) {
  const g = clean(styled({
    x: num(0, 50), y: num(0, 50), width: maybe(0.9, () => num(20, 200)), height: maybe(0.9, () => num(20, 200)), cornerRadius: maybe(0.15, () => 5),
    clip: maybe(0.3, () => true), strokeForeground: maybe(0.2, () => true), strokeOffset: maybe(0.05, () => 1), aria: maybe(0.1, () => false),
  }));
  const kids = [];
  const count = 1 + Math.floor(rnd() * 3);
  for (let i = 0; i < count; i++) kids.push(randomMark(depth + 1));
  g.items = kids;
  return g;
}
function randomMark(depth = 0) {
  const t = pick(depth > 1 ? ['rect', 'rule', 'text', 'symbol', 'line', 'area'] : ['rect', 'rule', 'text', 'symbol', 'line', 'area', 'group']);
  if (t === 'line' || t === 'area') return pathMark(t);
  if (t === 'group') {
    return clean({ marktype: 'group', name: maybe(0.3, () => 'g'), role: maybe(0.5, () => pick(['axis', 'legend', 'scope'])), aria: maybe(0.1, () => false), zindex: maybe(0.15, () => pick([0, 1, -1, 2])), items: [groupItem(depth)] });
  }
  return simpleMark(t, 1 + Math.floor(rnd() * 6));
}

function walk(mark, path, out) {
  out.push([path, mark.bounds]);
  if (mark.marktype === 'group') {
    mark.items.forEach((item, i) => {
      out.push([path === '' ? String(i) : `${path}/${i}`, item.bounds]);
      item.items.forEach((m, j) => walk(m, `${path === '' ? i : `${path}/${i}`}.${j}`, out));
    });
  } else if (mark.marktype !== 'line' && mark.marktype !== 'area') {
    mark.items.forEach((item, i) => out.push([path === '' ? String(i) : `${path}/${i}`, item.bounds]));
  }
}

const stripAria = (svg) => svg.replace(/ (?:role|aria-roledescription|aria-label)="[^"]*"/g, '');

export function generate() {
  const lines = [];
  const scenes = [];
  for (const t of ['rect', 'rule', 'text', 'symbol']) for (let i = 0; i < 8; i++) scenes.push(simpleMark(t, 3 + Math.floor(rnd() * 10)));
  for (const t of ['line', 'area']) for (let i = 0; i < 10; i++) scenes.push(pathMark(t));
  for (let i = 0; i < 24; i++) scenes.push(clean({ marktype: 'group', name: 'root', role: 'frame', items: [groupItem(0)] }));
  scenes.forEach((json, n) => {
    const id = `sc${n}`;
    const text = JSON.stringify(json);
    const root = vega.sceneFromJSON(text);
    const w = 240, h = 220, ox = pick([0, 5, 30.5]), oy = pick([0, 5, 12]);
    const bg = rnd() < 0.3 ? pick(['white', '#eee', 'transparent']) : null;
    vega.resetSVGClipId();
    const r = new vega.SVGStringRenderer().initialize(null, w, h, [ox, oy]);
    if (bg) r.background(bg);
    const svg = stripAria(r.render(root).svg());
    lines.push(`S|${id}|${escLine(text)}`);
    lines.push(`O|${id}|${w} ${h} ${ox} ${oy} ${bg ?? '-'}`);
    const bounds = [];
    walk(root, '', bounds);
    for (const [p, b] of bounds) {
      lines.push(`B|${id}|${p}|${b ? [b.x1, b.y1, b.x2, b.y2].map(hex16).join(' ') : '-'}`);
    }
    lines.push(`V|${id}|${escLine(svg)}`);
  });
  return { fixtures: { scenecases: { cases: lines.join(String.fromCharCode(10)) } } };
}
