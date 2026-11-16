// Renders the logo overlay as transparent 1920x1080 PNG frames.
// Usage: node renderer/render_frames.js <first> <end> [effect=drake]
// Effects in the page: drake (the chosen rotation), breathe, colorsync, neon, beat, glint, morph.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const [a, z] = [parseInt(process.argv[2]), parseInt(process.argv[3])], fx = process.argv[4] || 'drake', fps = 30;
  const root = path.join(__dirname, '..', 'work');
  const dir = path.join(root, 'frames_' + fx); fs.mkdirSync(dir, { recursive: true });
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1.5 });
  await p.goto('file://' + path.join(root, 'page', 'index.html'));
  for (let i = a; i < z; i++) {
    await p.evaluate(([fx, t, i]) => window.frame(fx, t, i), [fx, i / fps, i]);
    await p.waitForTimeout(i === a ? 200 : 0);
    await p.screenshot({ path: `${dir}/${String(i).padStart(4, '0')}.png`, omitBackground: true });
  }
  await b.close();
})();
