// Usage: TZ=UTC node dev/dump_scene.mjs <spec.vl.json> [--json] [--vega]
// Prints the official scenegraph as an indented outline (or full JSON), to see what moon_vegalite must reproduce.
import { loadSpec } from '../lib/spec.mjs';
import { runOfficial } from '../lib/official.mjs';

const [file, ...flags] = process.argv.slice(2);
const { scene, compiled } = await runOfficial(loadSpec(file));
if (flags.includes('--vega')) { console.log(JSON.stringify(compiled, null, 1)); process.exit(0); }
if (flags.includes('--json')) { console.log(JSON.stringify(scene, null, 1)); process.exit(0); }
const fmt = (o) => JSON.stringify(o, (k, v) => (k === 'items' || k === 'bounds' ? undefined : v));
const b = (x) => (x ? `[${x.x1},${x.y1},${x.x2},${x.y2}]` : '');
function show(m, ind) {
  console.log(`${ind}${m.marktype}${m.role ? '/' + m.role : ''}${m.name ? '/' + m.name : ''} n=${m.items.length} ${b(m.bounds)}`);
  m.items.slice(0, m.marktype === 'group' ? 99 : 3).forEach((it, i) => {
    console.log(`${ind}  [${i}] ${fmt(it)} ${b(it.bounds)}`);
    if (m.marktype === 'group') it.items.forEach((c) => show(c, ind + '    '));
  });
  if (m.marktype !== 'group' && m.items.length > 3) console.log(`${ind}  ... ${m.items.length - 3} more`);
}
console.log('view', JSON.stringify(scene.view));
show(scene, '');
