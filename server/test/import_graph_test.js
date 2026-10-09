// Import-graph guard: catches broken relative paths after a module
// split. `node --check` does NOT resolve imports, so a bad path boots
// fine and crashes at runtime — this is what bit the routes/lib/auth.js
// typo. Importing every module here proves the graph links at load time.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const srcDir = resolve(here, '..', 'src');

function jsFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = join(dir, e.name);
    if (e.isDirectory()) return jsFiles(p);
    return e.name.endsWith('.js') ? [p] : [];
  });
}

// The entrypoint has a side effect (app.listen) — it is boot-tested by
// the API suite, not here.
const importableFiles = () => jsFiles(srcDir).filter((f) => !f.endsWith('index.js'));

const relativeSpecifiers = [];
for (const file of jsFiles(srcDir)) {
  const src = await import('node:fs').then((fs) =>
    fs.readFileSync(file, 'utf8'),
  );
  for (const m of src.matchAll(/from\s+'(\.[^']+)'/g)) {
    relativeSpecifiers.push({ file, spec: m[1] });
  }
}

describe('import graph', () => {
  it('every relative import resolves to a real file', () => {
    assert.ok(
      relativeSpecifiers.length > 0,
      'expected modules with relative imports',
    );
    const broken = relativeSpecifiers.filter(
      ({ file, spec }) => !existsSync(join(dirname(file), spec)),
    );
    assert.deepEqual(
      broken.map(({ file, spec }) => `${file} -> ${spec}`),
      [],
      'these relative import paths do not exist',
    );
  });

  it('every server module links without a bad path', async () => {
    // Dynamic import actually resolves the graph (unlike static parse).
    const failures = [];
    for (const file of importableFiles()) {
      try {
        await import(`file://${file.replace(/\\/g, '/')}`);
      } catch (e) {
        failures.push(`${e.message}`);
      }
    }
    assert.deepEqual(
      failures.filter((m) => /Cannot find module|ERR_MODULE_NOT_FOUND/.test(m)),
      [],
      'module graph failed to link',
    );
  });
});
