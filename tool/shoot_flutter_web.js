// Screenshot a Flutter *web* app after its engine has actually painted.
//
// The generic html-render skill screenshots on `load`, which for a Flutter web
// build fires long before CanvasKit is fetched, the engine is initialised and
// the first frame is rasterised — producing a blank white PNG.
//
// This waits for the <flt-glass-pane> / <flt-scene-host> element the engine
// injects, then waits for the canvas to stop being uniformly blank, then adds a
// settle delay so entrance animations have finished.
const playwright = require('/home/neelgp/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');

const url = process.argv[2];
const out = process.argv[3];
const width = parseInt(process.argv[4] || '390', 10);
const height = parseInt(process.argv[5] || '844', 10);
const settleMs = parseInt(process.argv[6] || '4500', 10);
const fullPage = process.argv.includes('--full-page');
// Optional: click at x,y before capturing (Flutter web paints into a canvas, so
// text selectors do not exist in the DOM and coordinates are the only handle).
const clickArg = process.argv.find((a) => a.startsWith('--click='));
const scrollArg = process.argv.find((a) => a.startsWith('--scroll='));

(async () => {
  const browser = await playwright.chromium.launch({
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: 2,
    colorScheme: process.argv.includes('--light') ? 'light' : 'dark',
  });

  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('console: ' + m.text());
  });

  await page.goto(url, { waitUntil: 'load', timeout: 60000 });

  // 1. Wait for the Flutter engine to inject its host element.
  try {
    await page.waitForSelector('flt-glass-pane, flt-scene-host, flutter-view', {
      timeout: 45000,
    });
  } catch (e) {
    errors.push('engine host element never appeared');
  }

  // 2. Wait until the rendered surface is no longer uniformly blank.
  try {
    await page.waitForFunction(
      () => {
        const c = document.querySelector('canvas');
        if (!c || !c.width) return false;
        return true;
      },
      { timeout: 45000 }
    );
  } catch (e) {
    errors.push('no canvas with dimensions');
  }

  // 3. Settle: let fonts load and entrance animations finish.
  await page.waitForTimeout(settleMs);

  if (scrollArg) {
    const dy = parseInt(scrollArg.split('=')[1], 10);
    await page.mouse.move(width / 2, height / 2);
    await page.mouse.wheel(0, dy);
    await page.waitForTimeout(1400);
  }

  if (clickArg) {
    const [x, y] = clickArg.split('=')[1].split(',').map(Number);
    await page.mouse.click(x, y);
    await page.waitForTimeout(2200);
  }

  await page.screenshot({ path: out, fullPage });
  await browser.close();

  console.log('CAPTURED ' + out + ' (' + width + 'x' + height + ')');
  if (errors.length) {
    console.log('PAGE_ERRORS(' + errors.length + '):');
    errors.slice(0, 12).forEach((e) => console.log('  ' + e));
  } else {
    console.log('PAGE_ERRORS(0)');
  }
})().catch((e) => {
  console.error('CAPTURE_FAILED: ' + e.message);
  process.exit(1);
});
