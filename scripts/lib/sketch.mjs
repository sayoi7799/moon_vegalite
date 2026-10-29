// The hand-drawn SVG that the official packages give for a specification: the expected output of
// moon_vegalite's sketch mode. It is built from
//   * the scenegraph and SVG that vega-lite 5.23.0 + vega 5.33.1 produce (lib/official.mjs), and
//   * rough.js 4.6.6, using its own RoughSVG.draw (on a minimal DOM that serialises the elements).
// Every graphic shape of the SVG (rect, rule, symbol, line, area, group frame) is replaced by rough.js'
// drawing of the same shape, text is left alone. The rules (which shapes, the seed of each, the style
// mapping) are written down here independently of the MoonBit implementation they check.
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const roughModule = require('roughjs/bundled/rough.cjs.js');
const rough = roughModule.default ?? roughModule;

// ---- the seed of a shape: a hash of the base seed and the position of the shape in the scenegraph ----
const M32 = 0xffffffffn;
function mix(x) {
  let h = x & M32;
  h = ((h ^ (h >> 16n)) * 0x45d9f3bn) & M32;
  h = ((h ^ (h >> 16n)) * 0x45d9f3bn) & M32;
  return h ^ (h >> 16n);
}
export function shapeSeed(base, position) {
  let h = mix(BigInt.asIntN(64, BigInt(base)));
  for (const i of position) h = mix(h * 31n + BigInt(i) + 1n);
  return Number(h % 2147483646n) + 1;
}

// ---- a DOM that is just enough for RoughSVG.draw, with serialisation ----
const escapeAttr = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
class El {
  constructor(tag) { this.tag = tag; this.attrs = []; this.children = []; }
  setAttribute(k, v) { this.attrs.push([k, String(v)]); }
  appendChild(c) { this.children.push(c); }
  toString() {
    const a = this.attrs.map(([k, v]) => ` ${k}="${escapeAttr(v)}"`).join('');
    return this.children.length ? `<${this.tag}${a}>${this.children.join('')}</${this.tag}>` : `<${this.tag}${a}/>`;
  }
}
const doc = { createElementNS: (_ns, tag) => new El(tag) };
const fakeSvg = { ownerDocument: doc };

// ---- the shapes of the scenegraph, in the order the SVG renderer writes them ----
const paint = (item, key) => {
  const v = item[key];
  if (v === undefined || v === null || v === 'none' || v === 'transparent') return { kind: 'none' };
  if (typeof v === 'object') return { kind: 'gradient' };
  return { kind: 'color', color: String(v) };
};

function groupOffset(item) {
  const sw = item.strokeWidth ?? 1;
  if (item.strokeOffset !== undefined && item.strokeOffset !== null) return item.strokeOffset;
  return item.stroke && sw > 0.5 && sw < 1.5 ? 0.5 - Math.abs(sw - 1) : 0;
}

/** The marks of a group in rendering order: those without a zindex first, then the others by zindex. */
function orderedMarks(item) {
  const marks = item.items ?? [];
  const plain = marks.filter((m) => !m.zindex);
  const z = marks.map((m, i) => ({ m, i })).filter(({ m }) => m.zindex).sort((a, b) => a.m.zindex - b.m.zindex || a.i - b.i);
  return [...plain, ...z.map(({ m }) => m)];
}

function collect(mark, position, out) {
  switch (mark.marktype) {
    case 'group':
      mark.items.forEach((item, i) => {
        const pos = [...position, i];
        const off = groupOffset(item);
        const foreground = item.strokeForeground && item.stroke;
        const bg = foreground ? { ...item, stroke: undefined } : item;
        out.push({ kind: 'background', item: bg, pos, box: [off, off, item.width ?? 0, item.height ?? 0] });
        orderedMarks(item).forEach((child, j) => collect(child, [...pos, j], out));
        if (foreground) {
          out.push({ kind: 'foreground', item: item.fill ? { ...item, fill: undefined } : item, pos, box: [off, off, item.width ?? 0, item.height ?? 0] });
        }
      });
      break;
    case 'rect':
      mark.items.forEach((item, i) => out.push({ kind: 'rect', item, pos: [...position, i], box: [item.x ?? 0, item.y ?? 0, item.width ?? 0, item.height ?? 0] }));
      break;
    case 'rule':
      mark.items.forEach((item, i) => {
        const x = item.x ?? 0;
        const y = item.y ?? 0;
        out.push({ kind: 'rule', item, pos: [...position, i], segment: [x, y, item.x2 ?? x, item.y2 ?? y] });
      });
      break;
    case 'symbol':
      mark.items.forEach((item, i) => out.push({ kind: 'symbol', item, pos: [...position, i] }));
      break;
    case 'line':
    case 'area':
      if (mark.items.length > 0) out.push({ kind: mark.marktype, item: mark.items[0], pos: [...position, 0] });
      break;
    default:
      break; // text
  }
}

// ---- the elements of the official SVG that are shapes ----
/** [start, end, tag, attrs] of every <path> and <line> outside <defs> (and not an empty foreground path). */
function svgShapes(svg) {
  const out = [];
  const re = /<(\/?)([a-zA-Z]+)([^>]*?)(\/?)>/g;
  let m;
  let defs = 0;
  const stack = [];
  while ((m = re.exec(svg))) {
    const [all, closing, tag, rest, selfClosing] = m;
    if (closing) {
      stack.pop();
      if (tag === 'defs') defs -= 1;
      continue;
    }
    if (tag === 'defs') defs += 1;
    if (!selfClosing) stack.push(tag);
    if (defs > 0 || (tag !== 'path' && tag !== 'line')) continue;
    const attrs = Object.fromEntries([...rest.matchAll(/ ([a-zA-Z:-]+)="([^"]*)"/g)].map((a) => [a[1], a[2]]));
    if (/class="foreground"/.test(rest) && attrs.d === '') continue;
    out.push({ start: m.index, end: m.index + all.length, tag, attrs });
  }
  return out;
}

const FILL_NAMES = new Set(['hachure', 'solid', 'zigzag', 'cross-hatch', 'dots', 'dashed', 'zigzag-line']);
const num = (x) => String(x);

function drawShape(shape, element, o) {
  const { item } = shape;
  const fill = paint(item, 'fill');
  const stroke = paint(item, 'stroke');
  if (fill.kind === 'gradient' || stroke.kind === 'gradient') return null; // keep the original element
  let strokeColor = 'none';
  let strokeWidth = 0;
  let fillOnly = false;
  if (stroke.kind === 'color') {
    strokeColor = stroke.color;
    strokeWidth = item.strokeWidth ?? 1;
  } else if (fill.kind === 'color') {
    strokeColor = fill.color;
    strokeWidth = 1;
    fillOnly = true;
  }
  const fillColor = fill.kind === 'color' ? fill.color : undefined;
  if (strokeColor === 'none' && fillColor === undefined) return '';
  const seed = shapeSeed(o.seed, shape.pos);
  const options = { seed, roughness: o.roughness, bowing: o.bowing, stroke: strokeColor, strokeWidth, fillStyle: o.fillStyle };
  if (fillColor !== undefined) options.fill = fillColor;
  if (o.hachureGap !== undefined) options.hachureGap = o.hachureGap;
  if (o.fillWeight !== undefined) options.fillWeight = o.fillWeight;
  if (o.fixedDecimals !== undefined) options.fixedDecimalPlaceDigits = o.fixedDecimals;
  if (Array.isArray(item.strokeDash) && item.strokeDash.length > 0) options.strokeLineDash = item.strokeDash.map(Number);
  const svg = rough.svg(fakeSvg);
  let g;
  const finite = (xs) => xs.every((x) => Number.isFinite(x));
  if (shape.box) {
    let [x, y, w, h] = shape.box;
    if (!finite([x, y, w, h])) return '';
    if (w < 0) x += w;
    if (h < 0) y += h;
    g = svg.rectangle(x, y, Math.abs(w), Math.abs(h), options);
  } else if (shape.segment) {
    if (!finite(shape.segment)) return '';
    g = svg.line(...shape.segment, options);
  } else {
    const d = element.attrs.d;
    if (!d) return '';
    g = svg.path(d, options);
  }
  let wrapper = '';
  if (shape.kind === 'symbol') wrapper += ` transform="${escapeAttr(element.attrs.transform)}"`;
  let opacity = item.opacity;
  if (fillOnly && item.fillOpacity !== undefined && item.fillOpacity !== null) opacity = (opacity ?? 1) * item.fillOpacity;
  if (opacity !== undefined && opacity !== null) wrapper += ` opacity="${num(opacity)}"`;
  return wrapper ? `<g${wrapper}>${g}</g>` : String(g);
}

/**
 * The hand-drawn SVG of a specification, given what the official packages produced for it.
 * @param scene the exported vega scenegraph (lib/official.mjs), svg the official SVG (accessibility attributes stripped)
 * @param opts  { seed, roughness, bowing, fillStyle, hachureGap?, fillWeight?, fixedDecimals? }
 */
export function sketchify(scene, svg, opts) {
  const o = { seed: 1, roughness: 1, bowing: 1, fillStyle: 'hachure', ...opts };
  if (!FILL_NAMES.has(o.fillStyle)) throw new Error('unknown fill style ' + o.fillStyle);
  const shapes = [];
  collect(scene, [], shapes);
  const elements = svgShapes(svg);
  if (shapes.length !== elements.length) {
    throw new Error(`scenegraph has ${shapes.length} shapes, the SVG ${elements.length}`);
  }
  let out = '';
  let last = 0;
  shapes.forEach((shape, i) => {
    const el = elements[i];
    out += svg.slice(last, el.start);
    const drawn = drawShape(shape, el, o);
    out += drawn === null ? svg.slice(el.start, el.end) : drawn;
    last = el.end;
  });
  return out + svg.slice(last);
}
