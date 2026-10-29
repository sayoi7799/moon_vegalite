// The demo page: edit a Vega-Lite specification, see this library's SVG next to the official vega-embed rendering.
import { render, version } from './web.js';

const $ = (id) => document.getElementById(id);
const el = {
  example: $('example'), spec: $('spec'), badge: $('badge'), ours: $('ours'), error: $('error'),
  oursStatus: $('ours-status'), source: $('svg-source'), official: $('official'), officialStatus: $('official-status'),
};
const stripAria = (s) => s.replace(/ (role|aria-roledescription|aria-label)="[^"]*"/g, '');
const kb = (n) => (n / 1024).toFixed(1) + ' KB';

$('version').textContent = 'v' + version();
// the same text estimate as the headless reference the tests use, so that both SVGs can be compared
if (window.vega) vega.textMetrics.canvas(false);

let ourUrl = null;
let officialView = null;
let sequence = 0;
let timer = 0;
let examples = [];

function setBadge(kind, text) {
  el.badge.className = 'badge ' + kind;
  el.badge.textContent = text;
}

function showOurs(text) {
  const t0 = performance.now();
  const out = render(text);
  const ms = performance.now() - t0;
  if (ourUrl) { URL.revokeObjectURL(ourUrl); ourUrl = null; }
  el.ours.replaceChildren();
  if (out.startsWith('ERROR: ')) {
    el.error.hidden = false;
    el.error.textContent = out.slice('ERROR: '.length);
    el.oursStatus.textContent = '';
    el.source.textContent = '';
    return { svg: null, error: true };
  }
  el.error.hidden = true;
  ourUrl = URL.createObjectURL(new Blob([out], { type: 'image/svg+xml' }));
  const img = new Image();
  img.src = ourUrl;
  img.alt = 'moon_vegalite 渲染的图表';
  el.ours.append(img); // an <img> cannot run scripts, whatever the specification contains
  el.oursStatus.textContent = `渲染 ${ms.toFixed(1)} ms · SVG ${kb(out.length)}`;
  el.source.textContent = out;
  return { svg: out, error: false };
}

async function showOfficial(text, seq) {
  if (officialView) { officialView.finalize(); officialView = null; }
  el.official.replaceChildren();
  el.officialStatus.textContent = '';
  if (!window.vegaEmbed) {
    el.officialStatus.textContent = '官方库没有加载成功（需要联网访问 jsDelivr）。';
    return { svg: null };
  }
  let spec;
  try {
    spec = JSON.parse(text);
  } catch (e) {
    el.officialStatus.textContent = 'JSON 无效：' + e.message;
    return { svg: null };
  }
  try {
    const t0 = performance.now();
    const result = await vegaEmbed(el.official, spec, { mode: 'vega-lite', renderer: 'svg', actions: false });
    if (seq !== sequence) { result.finalize(); return { stale: true }; }
    officialView = result.view;
    const svg = await result.view.toSVG();
    el.officialStatus.textContent = `渲染 ${(performance.now() - t0).toFixed(1)} ms`;
    return { svg };
  } catch (e) {
    if (seq === sequence) el.officialStatus.textContent = '官方也无法渲染：' + (e && e.message ? e.message : e);
    return { svg: null };
  }
}

async function update() {
  const seq = ++sequence;
  const text = el.spec.value;
  const ours = showOurs(text);
  setBadge('', '正在渲染官方结果…');
  const official = await showOfficial(text, seq);
  if (official.stale || seq !== sequence) return;
  if (ours.error) {
    setBadge(official.svg ? 'warn' : 'bad',
      official.svg ? '本库不支持这个特性（错误路径见中间），官方可以渲染' : '两边都无法渲染这份规格');
  } else if (!official.svg) {
    setBadge('warn', '本库渲染成功，官方没有给出结果');
  } else if (stripAria(ours.svg) === stripAria(official.svg.trimEnd())) {
    setBadge('ok', '与官方 SVG 逐字相同（忽略无障碍属性）');
  } else {
    setBadge('warn', '与官方 SVG 不同（时区、字体或不支持的细节都可能造成差异）');
  }
}

function schedule() {
  clearTimeout(timer);
  timer = setTimeout(update, 250);
}

async function loadExample(id) {
  const entry = examples.find((e) => e.id === id) || examples[0];
  el.example.value = entry.id;
  history.replaceState(null, '', '#' + entry.id);
  el.spec.value = await (await fetch('examples/' + entry.file)).text();
  update();
}

async function main() {
  examples = await (await fetch('examples/index.json')).json();
  const groups = new Map();
  for (const e of examples) {
    if (!groups.has(e.group)) {
      const g = document.createElement('optgroup');
      g.label = e.group;
      groups.set(e.group, g);
      el.example.append(g);
    }
    groups.get(e.group).append(new Option(e.title, e.id));
  }
  el.example.addEventListener('change', () => loadExample(el.example.value));
  el.spec.addEventListener('input', () => { el.example.selectedIndex = -1; schedule(); });
  await loadExample(location.hash.slice(1) || 'layer_bar_line');
}
main();
