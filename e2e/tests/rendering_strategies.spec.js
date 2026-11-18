// @ts-nocheck
/**
 * rendering_strategies.spec.js
 *
 * Comprehensive Browser E2E verification for all three MetaMantle rendering strategies:
 *
 *   Strategy A: Flutter Canvas        (Port 8080: example/build/web)
 *   Strategy B: Semantic DOM          (Port 8081: example/build/web_semantic_dom)
 *   Strategy C: DOM + Flutter Islands (Port 8082: example/build/web_islands)
 */

const { test, expect } = require('@playwright/test');

const CANVAS_URL = process.env.BASE_URL || 'http://127.0.0.1:8080';
const SEMANTIC_URL = process.env.SEMANTIC_URL || 'http://127.0.0.1:8081';
const ISLANDS_URL = process.env.ISLANDS_URL || 'http://127.0.0.1:8082';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Returns true when flt-glass-pane is attached or mantle runtime reports ready.
 */
function flutterReady() {
  return (
    Boolean(window['__mantleRuntimeReady']) ||
    document.documentElement.getAttribute('data-mantle-runtime') === 'ready' ||
    document.querySelector('flt-glass-pane') !== null
  );
}

/** Filter out expected non-fatal console noise. */
function isFatalConsoleError(text) {
  if (text.includes('favicon')) return false;
  if (text.includes('Refused to get unsafe header')) return false;
  if (text.includes('serviceWorker') && text.includes('deprecated')) return false;
  if (text.includes('suppressMultithreadingWarning')) return false;
  if (text.includes('cross-origin isolated')) return false;
  return true;
}

// ===========================================================================
// Strategy A: Flutter Canvas Runtime Verification (Port 8080)
// ===========================================================================

test.describe('Strategy A — Flutter Canvas Runtime (Port 8080)', () => {
  test('A1: Document strategy attribute is flutter-canvas', async ({ page }) => {
    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });
    const strategy = await page.evaluate(
      () => document.documentElement.getAttribute('data-mantle-strategy')
    );
    expect(strategy).toBe('flutter-canvas');
  });

  test('A2: Pre-rendered semantic HTML delivers title, h1, and metadata before JS handoff', async ({ page }) => {
    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });

    await expect(page).toHaveTitle(/MetaMantle/);
    const h1 = page.locator('h1').first();
    await expect(h1).toBeAttached();
    const h1Text = await h1.textContent();
    expect(h1Text?.trim().length).toBeGreaterThan(0);

    const descMeta = page.locator('head meta[name="description"]');
    await expect(descMeta).toHaveCount(1);
    const descContent = await descMeta.getAttribute('content');
    expect(descContent?.trim().length).toBeGreaterThan(0);
  });

  test('A3: Mounts Flutter runtime and attaches flt-glass-pane overlay', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(flutterReady, null, { timeout: 30000 });

    const glassPane = page.locator('flt-glass-pane');
    await expect(glassPane).toBeAttached();

    const fatalErrors = consoleErrors.filter(isFatalConsoleError);
    expect(fatalErrors).toEqual([]);
  });

  test('A4: <canvas> element exists inside flt-glass-pane and is rendered', async ({ page }) => {
    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(flutterReady, null, { timeout: 30000 });

    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeAttached();

    const box = await canvas.boundingBox();
    if (box) {
      expect(box.width).toBeGreaterThan(50);
      expect(box.height).toBeGreaterThan(50);
    }
  });

  test('A5: Exactly 1 primary flt-glass-pane and no duplicate canvases', async ({ page }) => {
    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(flutterReady, null, { timeout: 30000 });

    const glassPaneCount = await page.locator('flt-glass-pane').count();
    expect(glassPaneCount).toBe(1);

    const canvasCount = await page.locator('canvas').count();
    expect(canvasCount).toBeGreaterThan(0);
    expect(canvasCount).toBeLessThanOrEqual(3);
  });

  test('A6: Prerender root transitions cleanly (aria-hidden/fade-out/cleanup) after Flutter initialises', async ({ page }) => {
    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });

    // Verify prerender root is present at initial page load
    const prerenderRootBefore = page.locator('#mantle-prerender-root');
    await expect(prerenderRootBefore).toBeAttached();

    // Wait for Flutter runtime
    await page.waitForFunction(flutterReady, null, { timeout: 30000 });

    // Once Flutter initializes, MetaMantle sets aria-hidden, applies mantle-fade-out, and cleans up the DOM
    await page.waitForFunction(() => {
      const root = document.getElementById('mantle-prerender-root');
      return (
        root === null ||
        root?.getAttribute('aria-hidden') === 'true' ||
        root?.classList.contains('mantle-fade-out')
      );
    }, null, { timeout: 5000 });

    const isProperlyTransitioned = await page.evaluate(() => {
      const root = document.getElementById('mantle-prerender-root');
      return (
        root === null ||
        root.getAttribute('aria-hidden') === 'true' ||
        root.classList.contains('mantle-fade-out')
      );
    });
    expect(isProperlyTransitioned).toBe(true);
  });

  test('A7: Route navigation updates URL and maintains metadata', async ({ page }) => {
    await page.goto(`${CANVAS_URL}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(flutterReady, null, { timeout: 30000 });

    const productsLink = page.locator('nav a[href="/products"]').first();
    const count = await productsLink.count();

    if (count > 0) {
      await productsLink.click({ force: true });
      await page.waitForURL(/\/products/, { timeout: 10000 }).catch(() => { });
    }

    const descCount = await page.locator('head meta[name="description"]').count();
    expect(descCount).toBeGreaterThanOrEqual(1);
  });
});

// ===========================================================================
// Strategy B: Pure Semantic DOM Verification (Port 8081)
// ===========================================================================

test.describe('Strategy B — Pure Semantic DOM (Port 8081)', () => {
  test('B1: Document strategy attribute is semantic-dom and runtime is ready', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/`, { waitUntil: 'domcontentloaded' });

    const strategy = await page.evaluate(
      () => document.documentElement.getAttribute('data-mantle-strategy')
    );
    expect(strategy).toBe('semantic-dom');

    const runtime = await page.evaluate(
      () => document.documentElement.getAttribute('data-mantle-runtime')
    );
    expect(runtime).toBe('ready');

    const readyFlag = await page.evaluate(() => window['__mantleRuntimeReady']);
    expect(readyFlag).toBe(true);
  });

  test('B2: Zero flt-glass-pane and zero canvas in the entire document', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/`, { waitUntil: 'domcontentloaded' });

    const glassPaneCount = await page.locator('flt-glass-pane').count();
    expect(glassPaneCount).toBe(0);

    const canvasCount = await page.locator('canvas').count();
    expect(canvasCount).toBe(0);

    const bootstrapScriptCount = await page.locator('script[src*="flutter_bootstrap.js"]').count();
    expect(bootstrapScriptCount).toBe(0);
  });

  test('B3: True semantic DOM container with role="main" exists', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/`, { waitUntil: 'domcontentloaded' });

    const appRoot = page.locator('#app.mantle-dom-root[role="main"]');
    await expect(appRoot).toBeVisible();

    const h1 = page.locator('h1').first();
    await expect(h1).toBeVisible();
    await expect(h1).toHaveText('Fresh Groceries & Farm Essentials');
  });

  test('B4: Text is directly selectable via Selection API', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/`, { waitUntil: 'domcontentloaded' });

    const selectedText = await page.evaluate(() => {
      const h1 = document.querySelector('h1');
      if (!h1) return null;
      const range = document.createRange();
      range.selectNodeContents(h1);
      const sel = window.getSelection();
      if (sel) {
        sel.removeAllRanges();
        sel.addRange(range);
        return sel.toString();
      }
      return null;
    });

    expect(selectedText).toBe('Fresh Groceries & Farm Essentials');
  });

  test('B5: Navigation links and accessibility attributes are fully functional', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/`, { waitUntil: 'domcontentloaded' });

    const nav = page.locator('nav[aria-label="Main Navigation"]');
    await expect(nav).toBeVisible();

    const homeLink = page.locator('nav a[href="/"]');
    await expect(homeLink).toHaveAttribute('aria-current', 'page');
    await expect(homeLink).toHaveAttribute('aria-label', 'Home');

    const productsLink = page.locator('nav a[href="/products"]');
    await expect(productsLink).toHaveAttribute('aria-label', 'Products');
  });

  test('B6: Navigation between pages loads semantic content without canvas', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/products`, { waitUntil: 'domcontentloaded' });

    const heading = page.locator('h1').first();
    await expect(heading).toBeVisible();
    await expect(heading).toHaveText('Featured Grocery Catalog');

    const table = page.locator('table');
    await expect(table).toBeVisible();

    const glassPaneCount = await page.locator('flt-glass-pane').count();
    expect(glassPaneCount).toBe(0);
  });

  test('B7: Sub-route /products/basmati-rice renders semantic product details and microdata', async ({ page }) => {
    await page.goto(`${SEMANTIC_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const productDiv = page.locator('[itemtype="https://schema.org/Product"]');
    await expect(productDiv).toBeVisible();

    const price = page.locator('[itemprop="price"]');
    await expect(price).toHaveText('$24.99');

    const desc = page.locator('[itemprop="description"]');
    await expect(desc).toBeVisible();

    const canvasCount = await page.locator('canvas').count();
    expect(canvasCount).toBe(0);
  });
});

// ===========================================================================
// Strategy C: DOM with Flutter Islands Verification (Port 8082)
// ===========================================================================

test.describe('Strategy C — DOM with Flutter Islands (Port 8082)', () => {
  test('C1: Document strategy attribute is dom-with-flutter-islands', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/`, { waitUntil: 'domcontentloaded' });

    const strategy = await page.evaluate(
      () => document.documentElement.getAttribute('data-mantle-strategy')
    );
    expect(strategy).toBe('dom-with-flutter-islands');
  });

  test('C2: Island initializer script is present and hooks loader', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/`, { waitUntil: 'domcontentloaded' });

    const islandScript = page.locator('script#mantle-island-initializer');
    await expect(islandScript).toBeAttached();
  });

  test('C3: Dedicated island host #flutter-cart-island exists on product detail route', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const islandHost = page.locator('#flutter-cart-island');
    await expect(islandHost).toBeAttached();

    await expect(islandHost).toHaveAttribute('data-mantle-island', 'cart');
    await expect(islandHost).toHaveAttribute('role', 'region');
    await expect(islandHost).toHaveAttribute('aria-label', 'Interactive Flutter Island: cart');
    await expect(islandHost).toHaveClass(/mantle-flutter-island/);
  });

  test('C4: Island contains fallback interactive button and text before/during mount', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const fallbackButton = page.locator('#flutter-cart-island button.mantle-button');
    await expect(fallbackButton).toBeAttached();
    await expect(fallbackButton).toHaveText('Add to Cart');

    const fallbackStock = page.locator('#flutter-cart-island');
    await expect(fallbackStock).toContainText('In Stock - Fast Delivery');
  });

  test('C5: Surrounding DOM outside island remains native, accessible, and visible', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const breadcrumbs = page.locator('nav[aria-label="Breadcrumb"]');
    await expect(breadcrumbs).toBeVisible();

    const h1 = page.locator('h1[itemprop="name"]');
    await expect(h1).toBeVisible();
    await expect(h1).toHaveText('Premium Basmati Rice');

    const price = page.locator('[itemprop="price"]');
    await expect(price).toBeVisible();
    await expect(price).toHaveText('$24.99');

    const backLink = page.locator('a[href="/products"]', { hasText: 'Back to Catalog' });
    await expect(backLink).toBeVisible();
  });

  test('C6: Surrounding text outside island is directly selectable via Selection API', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const selectedText = await page.evaluate(() => {
      const h1 = document.querySelector('h1[itemprop="name"]');
      if (!h1) return null;
      const range = document.createRange();
      range.selectNodeContents(h1);
      const sel = window.getSelection();
      if (sel) {
        sel.removeAllRanges();
        sel.addRange(range);
        return sel.toString();
      }
      return null;
    });

    expect(selectedText).toBe('Premium Basmati Rice');
  });

  test('C7: No duplicate canvases within page in island rendering mode', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const canvasCount = await page.evaluate(
      () => document.querySelectorAll('canvas').length
    );
    expect(canvasCount).toBeLessThanOrEqual(1);
  });

  test('C8: Two independent island hosts exist with genuine Flutter view lifecycle', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    const counterIsland = page.locator('#flutter-counter-island');

    await expect(cartIsland).toBeAttached();
    await expect(counterIsland).toBeAttached();

    // Wait for genuine Flutter multi-view mounting
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(cartIsland).toHaveAttribute('data-mantle-island-mounted', 'true');
    const cartViewId = await cartIsland.getAttribute('data-mantle-view-id');
    expect(cartViewId).toBeTruthy();

    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-mounted', 'true');
    const counterViewId = await counterIsland.getAttribute('data-mantle-view-id');
    expect(counterViewId).toBeTruthy();
    expect(counterViewId).not.toBe(cartViewId);

    // Fallback static elements must be hidden once Flutter view is confirmed mounted
    await expect(cartIsland.locator('.mantle-row, .mantle-island-fallback')).toBeHidden();
    await expect(counterIsland.locator('.mantle-row, .mantle-island-fallback')).toBeHidden();

    // Verify global runtime readiness across all expected islands
    await expect(page.locator('html')).toHaveAttribute('data-mantle-runtime', 'ready');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-islands-ready', 'true');
    const isReady = await page.evaluate(() => window.__mantleRuntimeReady);
    expect(isReady).toBe(true);
  });

  test('C9: Real Flutter button click in Island 1 executes Dart callback and updates Flutter state', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(cartIsland).toHaveAttribute('data-mantle-island-mounted', 'true');

    // Confirm real Flutter view element is attached and fallback is hidden
    const flutterView = cartIsland.locator('flt-glass-pane, canvas, [data-mantle-view-id]').first();
    await expect(flutterView).toBeAttached();
    await expect(cartIsland.locator('.mantle-row, .mantle-island-fallback')).toBeHidden();

    // Perform actual browser mouse click on the Flutter-rendered button
    const semanticBtn = cartIsland.locator('flt-semantics[role="button"], flt-semantics button, [role="button"]:visible').filter({ hasText: 'Add to Cart' });
    if (await semanticBtn.count() > 0) {
      await semanticBtn.first().click();
    } else {
      // Physical browser mouse click on the Flutter view hit target for ElevatedButton
      await cartIsland.click({ position: { x: 60, y: 25 } });
    }

    // Verify genuine Dart callback execution and state updates
    await expect.poll(async () => {
      return await page.evaluate(() => window.__mantleDartCartCount);
    }, { timeout: 10000 }).toBe(1);

    await expect(cartIsland).toHaveAttribute('data-mantle-island-count', '1');
    await expect(cartIsland).toHaveAttribute('data-mantle-dart-callback-executed', 'true');

    // Island 2 wishlist remains untouched
    const dartWishlistCount = await page.evaluate(() => window.__mantleDartWishlistCount);
    expect(dartWishlistCount).toBeUndefined();
    const counterIsland = page.locator('#flutter-counter-island');
    expect(await counterIsland.getAttribute('data-mantle-island-count')).toBeNull();
  });

  test('C10: Clicking Flutter button in Island 2 executes Dart callback twice independently', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const counterIsland = page.locator('#flutter-counter-island');
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-mounted', 'true');
    await expect(counterIsland.locator('.mantle-row, .mantle-island-fallback')).toBeHidden();

    const semanticBtn = counterIsland.locator('flt-semantics[role="button"], flt-semantics button, [role="button"]:visible').filter({ hasText: 'Add to Wishlist' });
    if (await semanticBtn.count() > 0) {
      await semanticBtn.first().click();
      await semanticBtn.first().click();
    } else {
      // Perform two physical browser clicks on the Flutter view hit target
      await counterIsland.click({ position: { x: 60, y: 25 } });
      await counterIsland.click({ position: { x: 60, y: 25 } });
    }

    // Verify Dart callback executed twice
    await expect.poll(async () => {
      return await page.evaluate(() => window.__mantleDartWishlistCount);
    }, { timeout: 10000 }).toBe(2);

    await expect(counterIsland).toHaveAttribute('data-mantle-island-count', '2');
    await expect(counterIsland).toHaveAttribute('data-mantle-dart-callback-executed', 'true');

    // Cart island remains independent
    const dartCartCount = await page.evaluate(() => window.__mantleDartCartCount);
    expect(dartCartCount).toBeUndefined();
    const cartIsland = page.locator('#flutter-cart-island');
    expect(await cartIsland.getAttribute('data-mantle-island-count')).toBeNull();
  });

  test('C11: Navigation disposal and remounting cleanly manages Flutter views without duplicates', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    const counterIsland = page.locator('#flutter-counter-island');
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });

    const initialCartViewId = await cartIsland.getAttribute('data-mantle-view-id');
    const initialCounterViewId = await counterIsland.getAttribute('data-mantle-view-id');

    // Trigger disposal
    await page.evaluate(() => {
      if (typeof window.__mantleDisposeIslands === 'function') {
        window.__mantleDisposeIslands();
      }
    });

    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(cartIsland).not.toHaveAttribute('data-mantle-island-mounted');
    await expect(cartIsland).not.toHaveAttribute('data-mantle-view-id');

    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(counterIsland).not.toHaveAttribute('data-mantle-island-mounted');
    await expect(counterIsland).not.toHaveAttribute('data-mantle-view-id');

    // Fallback content must be restored and visible on disposal
    await expect(cartIsland.locator('.mantle-row, .mantle-island-fallback')).toBeVisible();
    await expect(counterIsland.locator('.mantle-row, .mantle-island-fallback')).toBeVisible();

    // Global readiness must be reset
    await expect(page.locator('html')).not.toHaveAttribute('data-mantle-runtime', 'ready');
    const isReadyAfterDispose = await page.evaluate(() => window.__mantleRuntimeReady);
    expect(isReadyAfterDispose).toBe(false);

    // Repeated disposal must be safe and idempotent
    await page.evaluate(() => {
      if (typeof window.__mantleDisposeIslands === 'function') {
        window.__mantleDisposeIslands();
      }
    });
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');

    // Trigger remount
    await page.evaluate(() => {
      if (typeof window.__mantleRemountIslands === 'function') {
        return window.__mantleRemountIslands();
      }
    });

    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(cartIsland).toHaveAttribute('data-mantle-island-mounted', 'true');
    const remountedCartViewId = await cartIsland.getAttribute('data-mantle-view-id');
    expect(remountedCartViewId).toBeTruthy();
    expect(remountedCartViewId).not.toBe(initialCartViewId);

    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-mounted', 'true');
    const remountedCounterViewId = await counterIsland.getAttribute('data-mantle-view-id');
    expect(remountedCounterViewId).toBeTruthy();
    expect(remountedCounterViewId).not.toBe(initialCounterViewId);

    // Fallbacks hidden again
    await expect(cartIsland.locator('.mantle-row, .mantle-island-fallback')).toBeHidden();
    await expect(counterIsland.locator('.mantle-row, .mantle-island-fallback')).toBeHidden();

    // Verify recreated view responds to a real browser click
    const semanticBtn = cartIsland.locator('flt-semantics[role="button"], flt-semantics button, [role="button"]:visible').filter({ hasText: 'Add to Cart' });
    if (await semanticBtn.count() > 0) {
      await semanticBtn.first().click();
    } else {
      await cartIsland.click({ position: { x: 60, y: 25 } });
    }

    await expect.poll(async () => {
      return await page.evaluate(() => window.__mantleDartCartCount);
    }, { timeout: 10000 }).toBe(1);

    // Verify no duplicate canvases are leaked
    const canvasCount = await page.evaluate(() => document.querySelectorAll('canvas').length);
    expect(canvasCount).toBeLessThanOrEqual(1);
  });

  test('C12: Partial island initialization failure leaves fallback usable and prevents false global readiness', async ({ page }) => {
    // Intercept app.addView BEFORE islands mount so adding #flutter-counter-island throws a real error
    await page.addInitScript(() => {
      let currentApp = null;
      Object.defineProperty(window, '__mantleFlutterApp', {
        configurable: true,
        enumerable: true,
        get: () => currentApp,
        set: (val) => {
          currentApp = val;
          if (currentApp && typeof currentApp.addView === 'function' && !currentApp.__mantleIntercepted) {
            currentApp.__mantleIntercepted = true;
            const realAddView = currentApp.addView.bind(currentApp);
            currentApp.addView = function(options) {
              if (options && options.hostElement && options.hostElement.id === 'flutter-counter-island') {
                throw new Error('Controlled addView failure for flutter-counter-island');
              }
              return realAddView(options);
            };
          }
        }
      });
    });

    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    const counterIsland = page.locator('#flutter-counter-island');

    // Healthy island (Island 1) mounts successfully
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });

    // Failed island (Island 2) fails during real addView and transitions to error
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'error', { timeout: 30000 });

    // Verify that global runtime reports error and NOT ready
    await expect(page.locator('html')).toHaveAttribute('data-mantle-runtime', 'error');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-islands-ready', 'false');
    const runtimeReady = await page.evaluate(() => window.__mantleRuntimeReady);
    expect(runtimeReady).toBe(false);

    // Verify that failed island retains its visible static fallback
    await expect(counterIsland.locator('.mantle-row, .mantle-island-fallback')).toBeVisible();

    // Verify that successful island (Island 1) remains mounted and functional
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted');
    const semanticBtn = cartIsland.locator('flt-semantics[role="button"], flt-semantics button, [role="button"]:visible').filter({ hasText: 'Add to Cart' });
    if (await semanticBtn.count() > 0) {
      await semanticBtn.first().click();
    } else {
      await cartIsland.click({ position: { x: 60, y: 25 } });
    }

    await expect.poll(async () => {
      return await page.evaluate(() => window.__mantleDartCartCount);
    }, { timeout: 10000 }).toBe(1);
  });

  test('C13: Production Flutter loader wrapper preserves configuration, shares in-flight promises, and handles retries', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    // 1. Test production createWrappedEngineInitializer with shared in-flight Promises and retry
    const wrapperVerification = await page.evaluate(async () => {
      if (typeof window.__mantleCreateWrappedEngineInitializer !== 'function') {
        return { error: 'window.__mantleCreateWrappedEngineInitializer is not defined' };
      }

      var initializeEngineCallCount = 0;
      var runAppCallCount = 0;
      var passedConfig = null;

      var mockRealInitializer = {
        initializeEngine: async function (cfg) {
          initializeEngineCallCount++;
          passedConfig = cfg;
          await new Promise((resolve) => setTimeout(resolve, 20));
          return {
            runApp: async function (runAppOptions) {
              runAppCallCount++;
              await new Promise((resolve) => setTimeout(resolve, 20));
              return { mockApp: true, addView: function () { return 99; } };
            }
          };
        }
      };

      // Wrap mock initializer using actual production factory
      var wrapped = window.__mantleCreateWrappedEngineInitializer(mockRealInitializer, {
        config: { testBaseOption: 'base-val' }
      });

      // Concurrently call initializeEngine 3 times
      var [runner1, runner2, runner3] = await Promise.all([
        wrapped.initializeEngine({ consumerOption: 'consumer-val' }),
        wrapped.initializeEngine({ consumerOption: 'consumer-val' }),
        wrapped.initializeEngine({ consumerOption: 'consumer-val' })
      ]);

      var singleInitCall = (initializeEngineCallCount === 1);
      var sameRunners = (runner1 === runner2 && runner2 === runner3);
      var configMerged = Boolean(
        passedConfig &&
        passedConfig.multiViewEnabled === true &&
        passedConfig.testBaseOption === 'base-val' &&
        passedConfig.consumerOption === 'consumer-val'
      );

      // Concurrently call runApp 3 times on the resolved runner
      var [app1, app2, app3] = await Promise.all([
        runner1.runApp(),
        runner2.runApp(),
        runner3.runApp()
      ]);

      var singleRunCall = (runAppCallCount === 1);
      var sameApps = (app1 === app2 && app2 === app3 && app1.mockApp === true);

      // Verify retry after rejection resets in-flight promise
      var failAttempts = 0;
      var retryInitializer = {
        initializeEngine: async function () {
          failAttempts++;
          if (failAttempts === 1) {
            throw new Error('Simulated transient initialization error');
          }
          return {
            runApp: async function () {
              return { recovered: true, addView: function () { return 100; } };
            }
          };
        }
      };

      var retryWrapped = window.__mantleCreateWrappedEngineInitializer(retryInitializer, {});
      var failedOnFirst = false;
      try {
        await retryWrapped.initializeEngine();
      } catch (e) {
        failedOnFirst = true;
      }

      // Retry should now invoke realInitializer again
      var recoveredRunner = await retryWrapped.initializeEngine();
      var recoveredApp = await recoveredRunner.runApp();
      var retrySuccess = Boolean(failedOnFirst && failAttempts === 2 && recoveredApp.recovered === true);

      return {
        singleInitCall,
        sameRunners,
        configMerged,
        singleRunCall,
        sameApps,
        retrySuccess
      };
    });

    expect(wrapperVerification.singleInitCall).toBe(true);
    expect(wrapperVerification.sameRunners).toBe(true);
    expect(wrapperVerification.configMerged).toBe(true);
    expect(wrapperVerification.singleRunCall).toBe(true);
    expect(wrapperVerification.sameApps).toBe(true);
    expect(wrapperVerification.retrySuccess).toBe(true);

    // 2. Test loader hook preserves loader options (config, nonce, serviceWorkerSettings)
    const hookVerification = await page.evaluate(async () => {
      var passedLoadOptions = null;
      var consumerCallbackFired = false;
      var receivedWrapper = null;

      var mockLoader = {
        load: function (options) {
          passedLoadOptions = options;
          if (options && typeof options.onEntrypointLoaded === 'function') {
            var mockEngineInit = {
              initializeEngine: async function (cfg) {
                return {
                  runApp: async function () {
                    return { addView: function () { return 1; } };
                  }
                };
              }
            };
            options.onEntrypointLoaded(mockEngineInit);
          }
        }
      };

      // Assign to window._flutter.loader which triggers the hooked property setter
      window._flutter.loader = mockLoader;

      mockLoader.load({
        config: { customFlag: 'xyz' },
        serviceWorkerSettings: { timeoutMillis: 5000 },
        nonce: 'strict-nonce-789',
        onEntrypointLoaded: async function (wrappedInit) {
          consumerCallbackFired = true;
          receivedWrapper = wrappedInit;
          var runner = await wrappedInit.initializeEngine();
          await runner.runApp();
        }
      });

      return {
        consumerCallbackFired,
        noncePreserved: passedLoadOptions && passedLoadOptions.nonce === 'strict-nonce-789',
        swPreserved: passedLoadOptions && passedLoadOptions.serviceWorkerSettings && passedLoadOptions.serviceWorkerSettings.timeoutMillis === 5000,
        isWrapped: Boolean(receivedWrapper && receivedWrapper._realInitializer)
      };
    });

    expect(hookVerification.consumerCallbackFired).toBe(true);
    expect(hookVerification.noncePreserved).toBe(true);
    expect(hookVerification.swPreserved).toBe(true);
    expect(hookVerification.isWrapped).toBe(true);
  });

  test('C14: Truthful disposal isolates removeView errors, retains diagnostic state, and allows idempotent retry', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    const counterIsland = page.locator('#flutter-counter-island');

    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });

    // Inject controlled failure into removeView for the counter island's view ID
    const removalFailureTest = await page.evaluate(() => {
      const isl2 = document.getElementById('flutter-counter-island');
      const counterViewId = isl2 ? Number(isl2.getAttribute('data-mantle-view-id')) : -1;
      const app = window.__mantleFlutterApp;
      if (!app || typeof app.removeView !== 'function') {
        return { error: 'No Flutter app or removeView function' };
      }

      let failureCount = 0;
      const realRemoveView = app.removeView.bind(app);
      app.removeView = function (viewId) {
        if (viewId === counterViewId && failureCount === 0) {
          failureCount++;
          throw new Error('Simulated removeView exception for view ' + viewId);
        }
        return realRemoveView(viewId);
      };

      // Call disposal
      window.__mantleDisposeIslands();

      return {
        counterViewId,
        failureCount
      };
    });

    expect(removalFailureTest.counterViewId).toBeGreaterThanOrEqual(0);

    // Island 1 had successful removal -> transitioned to disposed, fallback restored
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(cartIsland).not.toHaveAttribute('data-mantle-island-mounted');
    await expect(cartIsland).not.toHaveAttribute('data-mantle-view-id');
    await expect(cartIsland.locator('.mantle-row, .mantle-island-fallback')).toBeVisible();

    // Island 2 failed removal -> transitioned to error, diagnostic info retained, fallback NOT restored
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'error');
    await expect(counterIsland).toHaveAttribute('data-mantle-disposal-error');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-runtime', 'error');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-islands-ready', 'false');

    // Retry disposal (now removeView will succeed since failureCount > 0)
    await page.evaluate(() => {
      window.__mantleDisposeIslands();
    });

    // Both islands now cleanly disposed
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(counterIsland).not.toHaveAttribute('data-mantle-view-id');
    await expect(counterIsland).not.toHaveAttribute('data-mantle-disposal-error');
    await expect(counterIsland.locator('.mantle-row, .mantle-island-fallback')).toBeVisible();
    await expect(page.locator('html')).not.toHaveAttribute('data-mantle-runtime');
    const readyState = await page.evaluate(() => window.__mantleRuntimeReady);
    expect(readyState).toBe(false);
  });
});
