import { loadSpec } from '../lib/spec.mjs';
import { runOfficial } from '../lib/official.mjs';
const { svg, view } = await runOfficial(loadSpec(process.argv[2]));
console.log(svg.slice(0, 700));
console.log('padding', JSON.stringify(view.padding()), 'origin', view.origin(), 'w/h', view.width(), view.height());
