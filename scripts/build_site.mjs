// Assembles ../_site, the folder published on GitHub Pages: the page from ../site and the js build of the web package.
//   moon build --target js --release && node scripts/build_site.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const built = path.join(root, '_build/js/release/build/web/web.js');
const out = path.join(root, '_site');
if (!fs.existsSync(built)) {
  console.error('missing ' + built + '\nrun: moon build --target js --release');
  process.exit(1);
}
fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(path.join(root, 'site'), out, { recursive: true });
fs.copyFileSync(built, path.join(out, 'web.js'));
fs.writeFileSync(path.join(out, '.nojekyll'), '');
console.log('wrote _site (' + (fs.statSync(path.join(out, 'web.js')).size / 1024).toFixed(0) + ' KB web.js)');
