// Helpers for emitting MoonBit source from the fixture generators.
import fs from 'node:fs';
import path from 'node:path';

export const HEADER =
  '// GENERATED FILE. DO NOT EDIT.\n' +
  '// Regenerate with: cd scripts && npm ci && npm run fixtures\n' +
  '// Expected values come from the official vega-lite / vega packages pinned in scripts/package-lock.json.\n\n';

/** Replace every non-ASCII character with a JSON \uXXXX escape (valid inside JSON strings). */
export function asciiJson(text) {
  return text.replace(/[\u007f-￿]/g, (ch) => '\\u' + ch.charCodeAt(0).toString(16).padStart(4, '0'));
}

/**
 * Render text as a MoonBit multi-line string literal (`#|` lines, joined with "\n").
 * Content must be printable ASCII per line so that no escaping is needed.
 */
export function mbtMultiline(text) {
  const lines = text.split('\n');
  for (const line of lines) {
    if (!/^[\x20-\x7e]*$/.test(line)) {
      throw new Error('fixture line is not printable ASCII: ' + JSON.stringify(line.slice(0, 80)));
    }
  }
  return lines.map((l) => '  #|' + l).join('\n');
}

/**
 * Write a MoonBit package containing `pub let <name> : String` constants.
 * `constants` maps constant name -> string content (lines separated by "\n").
 */
export function writeFixturePackage(root, area, constants) {
  const dir = path.join(root, 'fixtures', area);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'moon.pkg'), '// Generated fixtures; see scripts/gen_fixtures.mjs\n');
  let src = HEADER;
  // The compiler warns when one multi-line string segment gets too long, so split big constants.
  const CHUNK = 8000;
  for (const [name, text] of Object.entries(constants)) {
    const lines = text.split('\n');
    if (lines.length <= CHUNK) {
      src += `///|\npub let ${name} : String =\n${mbtMultiline(text)}\n\n`;
      continue;
    }
    const parts = [];
    for (let i = 0; i < lines.length; i += CHUNK) {
      const partName = `${name}_part${parts.length}`;
      parts.push(partName);
      src += `///|\nlet ${partName} : String =\n${mbtMultiline(lines.slice(i, i + CHUNK).join('\n'))}\n\n`;
    }
    src += `///|\npub let ${name} : String = ${parts.join(' + "\\n" + ')}\n\n`;
  }
  fs.writeFileSync(path.join(dir, 'data.mbt'), src.replace(/\n+$/, '\n'));
  return dir;
}
