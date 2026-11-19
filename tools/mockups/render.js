// Render tools/mockups/restora_mockups.html to docs/mockups/*.png (Playwright).
// Usage: node tools/mockups/render.js
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const root = path.resolve(__dirname, '..', '..');
  const out = path.join(root, 'docs', 'mockups');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1370, height: 900 }, deviceScaleFactor: 2 });
  await page.goto('file://' + path.join(__dirname, 'restora_mockups.html'));
  await page.waitForFunction(() => document.body.dataset.ready === '1');
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out, 'restora-ui-mockups.png'), fullPage: true });
  const canvases = await page.$$('canvas');
  for (let i = 0; i < canvases.length; i++) {
    await canvases[i].screenshot({ path: path.join(out, 'screen-' + String(i + 1).padStart(2, '0') + '.png') });
  }
  await browser.close();
  console.log('rendered', canvases.length, 'screens');
})();
