const fs = require('fs');
const src = fs.readFileSync('C:/Users/ALBIREO/.local/share/opencode/tool-output/tool_1732eec08001KopqLX9bDjl1xO', 'utf8');
const mi = src.indexOf('"openapi":"3.0.1"');
const startTag = "JSON.parse('";
const start = src.lastIndexOf(startTag, mi) + startTag.length - 1; // include opening quote
let i = start + 1;
while (i < src.length) {
  if (src[i] === '\\') { i += 2; continue; }
  if (src[i] === "'") break;
  i++;
}
const literal = src.slice(start, i + 1);
const value = new Function('return ' + literal)();
const spec = JSON.parse(value);
fs.writeFileSync('C:/Users/ALBIREO/AppData/Local/Temp/opencode/garmin-openapi-clean.json', JSON.stringify(spec, null, 2));
console.log('title:', spec.info.title, '| paths:', Object.keys(spec.paths).length);
console.log('--- TAGS ---');
for (const t of spec.tags || []) console.log(t.name + ': ' + (t.description || ''));
console.log('--- PATHS ---');
for (const p of Object.keys(spec.paths).sort()) {
  const methods = Object.keys(spec.paths[p]).filter(m => ['get','post','put','delete','patch'].includes(m));
  console.log(p + '  [' + methods.join(',') + ']');
}
