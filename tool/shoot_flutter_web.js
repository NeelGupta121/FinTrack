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

  // Second click, for reaching a screen by tapping the in-app nav rather than
  // by route navigation (which reloads). Used to distinguish genuine rendering
  // defects from artifacts of the reload path.
  const click2Arg = process.argv.find((a) => a.startsWith('--click2='));
  if (click2Arg) {
    const [x2, y2] = click2Arg.split('=')[1].split(',').map(Number);
    await page.mouse.click(x2, y2);
    await page.waitForTimeout(2600);
  }

  // Navigate to a client-side route AFTER onboarding has been dismissed, in the
  // same browser context so the completion flag (IndexedDB) persists. Requires
  // the server to rewrite unknown paths to index.html -- see tool/serve_spa.py.
  const routeArg = process.argv.find((a) => a.startsWith('--route='));
  if (routeArg) {
    const route = routeArg.split('=')[1];
    await page.goto(url.replace(/\/$/, '') + route, {
      waitUntil: 'load',
      timeout: 60000,
    });
    // Hash navigation is same-document, so CanvasKit does not rebuild the whole
    // scene and a previous route's layers (nav pill, FAB) can remain composited
    // in the capture. Reload so the engine boots directly at this route and the
    // frame is unambiguous. The onboarding flag lives in browser storage, so it
    // survives the reload and we do not bounce back to onboarding.
    await page.reload({ waitUntil: 'load', timeout: 60000 });
    try {
      await page.waitForSelector('flt-glass-pane, flt-scene-host, flutter-view', {
        timeout: 45000,
      });
    } catch (e) {
      errors.push('engine host missing after route nav');
    }
    await page.waitForTimeout(settleMs);
  }

  // Force a full-surface repaint before capturing.
  //
  // CanvasKit repaints dirty regions only. After a route change the previous
  // screen's layers (nav pill, FAB) can remain composited in areas the new
  // screen leaves transparent -- invisible on a content-dense screen like the
  // dashboard, but clearly visible as a ghost duplicate on a sparse screen such
  // as an empty list. Nudging the viewport by 1px forces a relayout and a full
  // repaint, so the capture shows only the current frame.
  await page.setViewportSize({ width, height: height + 1 });
  await page.waitForTimeout(600);
  await page.setViewportSize({ width, height });
  await page.waitForTimeout(900);

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
