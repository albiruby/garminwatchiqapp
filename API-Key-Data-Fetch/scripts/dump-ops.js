const fs = require('fs');
const spec = JSON.parse(fs.readFileSync('C:/Users/ALBIREO/AppData/Local/Temp/opencode/garmin-openapi-clean.json', 'utf8'));
for (const [p, item] of Object.entries(spec.paths)) {
  for (const [m, op] of Object.entries(item)) {
    if (!['get','post'].includes(m)) continue;
    console.log('\n### ' + m.toUpperCase() + ' ' + p);
    if (op.summary) console.log('summary: ' + op.summary);
    if (op.description) console.log('desc: ' + op.description.replace(/\s+/g, ' ').slice(0, 300));
    for (const prm of op.parameters || []) {
      console.log('  - ' + prm.name + ' [' + prm.in + ']' + (prm.required ? ' REQUIRED' : ''));
      if (prm.description) console.log('      ' + prm.description.replace(/\s+/g, ' ').slice(0, 220));
      const sc = prm.schema || {};
      if (sc.type || sc.format || sc.default !== undefined || sc.enum) {
        console.log('      type=' + (sc.type||'') + ' format=' + (sc.format||'') + (sc.default!==undefined?' default='+JSON.stringify(sc.default):'') + (sc.enum?' enum='+JSON.stringify(sc.enum):''));
      }
    }
    const ok = (op.responses && (op.responses['200'] || op.responses['201'])) || null;
    if (ok) {
      const content = ok.content || {};
      for (const [ct, cv] of Object.entries(content)) {
        console.log('  response ' + ct + ' -> ' + JSON.stringify(cv.schema && (cv.schema.$ref || cv.schema.type || cv.schema)));
      }
    }
  }
}
