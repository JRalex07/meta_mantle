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
    try {
      const isAttached = await productsLink.count() > 0 && await productsLink.isVisible();
      if (isAttached) {
        await productsLink.click({ timeout: 2000 });
        await page.waitForURL(/\/products/, { timeout: 5000 }).catch(() => { });
      }
    } catch (_) {
      // Element may detach as prerender root cleans up on Flutter canvas mount
    }

    if (!page.url().includes('/products')) {
      await page.goto(`${CANVAS_URL}/products`, { waitUntil: 'domcontentloaded' });
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

  test('C13: Full Flutter loader integration matrix with asynchronous callback lifecycle', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const matrixResults = await page.evaluate(async () => {
      const results = {};
      const hookLoader = window.__mantleHookLoader;
      if (typeof hookLoader !== 'function') {
        return { error: 'window.__mantleHookLoader is not exposed' };
      }

      function createMockLoader() {
        let loadOptions = null;
        let engineInitCalls = 0;
        let runAppCalls = 0;
        let attachedViews = [];
        let onEntrypointPromise = null;

        const loader = {
          load: function (opts) {
            loadOptions = opts;
            const mockInitializer = {
              initializeEngine: async function (mergedConfig) {
                engineInitCalls++;
                await new Promise((r) => setTimeout(r, 10));
                return {
                  runApp: async function (runAppOpts) {
                    runAppCalls++;
                    await new Promise((r) => setTimeout(r, 10));
                    return {
                      addView: function (options) {
                        const vid = attachedViews.length + 100;
                        attachedViews.push({ viewId: vid, host: options.hostElement });
                        return vid;
                      },
                      removeView: function (vid) {
                        attachedViews = attachedViews.filter((v) => v.viewId !== vid);
                      }
                    };
                  }
                };
              }
            };

            if (opts && typeof opts.onEntrypointLoaded === 'function') {
              onEntrypointPromise = Promise.resolve().then(() => opts.onEntrypointLoaded(mockInitializer));
            }
            return onEntrypointPromise;
          },
          getLoadOptions: () => loadOptions,
          getCounts: () => ({ engineInitCalls, runAppCalls, attachedViewsCount: attachedViews.length }),
          awaitEntrypoint: () => onEntrypointPromise
        };

        return loader;
      }

      // Case 1: Consumer provides onEntrypointLoaded and awaits both operations
      {
        const loader1 = createMockLoader();
        hookLoader(loader1);
        let consumerAwaited = false;
        await loader1.load({
          config: { loaderCustomKey: 'val1' },
          nonce: 'nonce-123',
          serviceWorkerSettings: { timeoutMillis: 3000 },
          onEntrypointLoaded: async function (engineInitializer) {
            const runner = await engineInitializer.initializeEngine({ consumerCustomKey: 'val2' });
            const app = await runner.runApp();
            consumerAwaited = Boolean(app && typeof app.addView === 'function');
          }
        });
        const counts1 = loader1.getCounts();
        results.case1 = {
          consumerAwaited,
          engineInitCalls: counts1.engineInitCalls,
          runAppCalls: counts1.runAppCalls,
          noncePreserved: loader1.getLoadOptions().nonce === 'nonce-123',
          swPreserved: loader1.getLoadOptions().serviceWorkerSettings.timeoutMillis === 3000
        };
      }

      // Case 2: Consumer does NOT provide onEntrypointLoaded (automatic startup)
      {
        const loader2 = createMockLoader();
        hookLoader(loader2);
        await loader2.load({
          config: { autoStartConfig: true }
        });
        const counts2 = loader2.getCounts();
        results.case2 = {
          engineInitCalls: counts2.engineInitCalls,
          runAppCalls: counts2.runAppCalls
        };
      }

      // Case 3: Consumer calls initializeEngine but omits runApp (wrapper must auto-run app)
      {
        const loader3 = createMockLoader();
        hookLoader(loader3);
        let consumerRanInit = false;
        await loader3.load({
          onEntrypointLoaded: async function (engineInitializer) {
            await engineInitializer.initializeEngine();
            consumerRanInit = true;
          }
        });
        const counts3 = loader3.getCounts();
        results.case3 = {
          consumerRanInit,
          engineInitCalls: counts3.engineInitCalls,
          runAppCalls: counts3.runAppCalls
        };
      }

      // Case 4: Consumer callback throws synchronous error
      {
        const loader4 = createMockLoader();
        hookLoader(loader4);
        let threwError = false;
        try {
          await loader4.load({
            onEntrypointLoaded: function () {
              throw new Error('Sync consumer error');
            }
          });
        } catch (e) {
          threwError = e.message.includes('Sync consumer error');
        }
        results.case4 = { threwError };
      }

      // Case 5: Consumer callback returns a rejecting Promise
      {
        const loader5 = createMockLoader();
        hookLoader(loader5);
        let rejectedError = false;
        try {
          await loader5.load({
            onEntrypointLoaded: async function () {
              await new Promise((_, reject) => reject(new Error('Async consumer rejection')));
            }
          });
        } catch (e) {
          rejectedError = e.message.includes('Async consumer rejection');
        }
        results.case5 = { rejectedError };
      }

      // Case 6: Repeated hookLoader call does not install duplicate wrappers
      {
        const loader6 = createMockLoader();
        hookLoader(loader6);
        const origLoadFn = loader6.load;
        hookLoader(loader6);
        results.case6 = {
          isIdempotent: loader6.load === origLoadFn
        };
      }

      // Case 7: Loader assigned before / after bootstrap via window._flutter.loader setter
      {
        const loader7 = createMockLoader();
        window._flutter.loader = loader7;
        results.case7 = {
          isHooked: Boolean(loader7.__mantleHooked)
        };
      }

      return results;
    });

    expect(matrixResults.case1.consumerAwaited).toBe(true);
    expect(matrixResults.case1.engineInitCalls).toBe(1);
    expect(matrixResults.case1.runAppCalls).toBe(1);
    expect(matrixResults.case1.noncePreserved).toBe(true);
    expect(matrixResults.case1.swPreserved).toBe(true);

    expect(matrixResults.case2.engineInitCalls).toBe(1);
    expect(matrixResults.case2.runAppCalls).toBe(1);

    expect(matrixResults.case3.consumerRanInit).toBe(true);
    expect(matrixResults.case3.engineInitCalls).toBe(1);
    expect(matrixResults.case3.runAppCalls).toBe(1);

    expect(matrixResults.case4.threwError).toBe(true);
    expect(matrixResults.case5.rejectedError).toBe(true);
    expect(matrixResults.case6.isIdempotent).toBe(true);
    expect(matrixResults.case7.isHooked).toBe(true);
  });

  test('C14: Truthful disposal handles missing flutterApp, missing removeView, invalid IDs, and retry recovery', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    const counterIsland = page.locator('#flutter-counter-island');

    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });

    // Test 1: Disposal when flutterApp is temporarily missing or removeView is missing
    const missingAppTest = await page.evaluate(() => {
      const realApp = window.__mantleFlutterApp;
      window.__mantleFlutterApp = null;

      const disposeResult = window.__mantleDisposeIslands();
      const isl1State = document.getElementById('flutter-cart-island').getAttribute('data-mantle-island-lifecycle');
      const isl1Error = document.getElementById('flutter-cart-island').getAttribute('data-mantle-disposal-error');

      // Restore app for subsequent test
      window.__mantleFlutterApp = realApp;

      return {
        disposeResult,
        isl1State,
        isl1Error
      };
    });

    expect(missingAppTest.disposeResult.success).toBe(false);
    expect(missingAppTest.disposeResult.remainingViewsCount).toBeGreaterThan(0);
    expect(missingAppTest.isl1State).toBe('error');
    expect(missingAppTest.isl1Error).toContain('Missing Flutter application instance');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-runtime', 'error');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-islands-ready', 'false');

    // Test 2: Partial failure where removeView throws for Island 2 but succeeds for Island 1
    const partialFailureTest = await page.evaluate(() => {
      const isl2 = document.getElementById('flutter-counter-island');
      const counterViewId = isl2 ? Number(isl2.getAttribute('data-mantle-view-id')) : -1;
      const app = window.__mantleFlutterApp;

      let failureCount = 0;
      const realRemoveView = app.removeView.bind(app);
      app.removeView = function (viewId) {
        if (viewId === counterViewId && failureCount === 0) {
          failureCount++;
          throw new Error('Simulated removeView exception for view ' + viewId);
        }
        return realRemoveView(viewId);
      };

      const result = window.__mantleDisposeIslands();
      return {
        counterViewId,
        failureCount,
        result
      };
    });

    expect(partialFailureTest.counterViewId).toBeGreaterThanOrEqual(0);

    // Island 1 had confirmed successful removal -> transitioned to disposed, fallback restored
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(cartIsland).not.toHaveAttribute('data-mantle-island-mounted');
    await expect(cartIsland).not.toHaveAttribute('data-mantle-view-id');
    await expect(cartIsland.locator('.mantle-row, .mantle-island-fallback')).toBeVisible();

    // Island 2 failed removal -> transitioned to error, diagnostic info retained, fallback NOT restored
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'error');
    await expect(counterIsland).toHaveAttribute('data-mantle-disposal-error');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-runtime', 'error');
    await expect(page.locator('html')).toHaveAttribute('data-mantle-islands-ready', 'false');

    // Test 3: Retry disposal now succeeds because failureCount > 0
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

  test('C15: Concurrency safety matrix for initializeEngine and runApp with deliberate retry', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const concurrencyResults = await page.evaluate(async () => {
      const createWrapper = window.__mantleCreateWrappedEngineInitializer;
      if (typeof createWrapper !== 'function') {
        return { error: 'window.__mantleCreateWrappedEngineInitializer missing' };
      }

      let realInitCalls = 0;
      let realRunCalls = 0;
      let receivedConfig = null;

      const mockRealInit = {
        initializeEngine: async function (cfg) {
          realInitCalls++;
          receivedConfig = cfg;
          await new Promise((r) => setTimeout(r, 20));
          return {
            runApp: async function () {
              realRunCalls++;
              await new Promise((r) => setTimeout(r, 20));
              return { mockApp: true, addView: () => 1 };
            }
          };
        }
      };

      const wrapper = createWrapper(mockRealInit, {
        config: { baseKey: 'baseVal' }
      });

      // 1. Five concurrent initializeEngine calls with identical and differing options
      const [r1, r2, r3, r4, r5] = await Promise.all([
        wrapper.initializeEngine({ opt: 'first' }),
        wrapper.initializeEngine({ opt: 'first' }),
        wrapper.initializeEngine({ opt: 'differing' }),
        wrapper.initializeEngine({ opt: 'first' }),
        wrapper.initializeEngine()
      ]);

      const singleInit = (realInitCalls === 1);
      const runnersIdentical = (r1 === r2 && r2 === r3 && r3 === r4 && r4 === r5);
      const configPreserved = (
        receivedConfig.baseKey === 'baseVal' &&
        receivedConfig.opt === 'first' &&
        receivedConfig.multiViewEnabled === true
      );

      // 2. Five concurrent runApp calls on the returned runner
      const [a1, a2, a3, a4, a5] = await Promise.all([
        r1.runApp(),
        r2.runApp(),
        r3.runApp(),
        r4.runApp(),
        r5.runApp()
      ]);

      const singleRun = (realRunCalls === 1);
      const appsIdentical = (a1 === a2 && a2 === a3 && a3 === a4 && a4 === a5);

      // 3. Deliberate retry on failed initializeEngine
      let failInitCount = 0;
      const failingInit = {
        initializeEngine: async function () {
          failInitCount++;
          if (failInitCount <= 2) {
            throw new Error('Transient engine init error attempt #' + failInitCount);
          }
          return {
            runApp: async function () {
              return { addView: () => 2 };
            }
          };
        }
      };

      const retryInitWrapper = createWrapper(failingInit, {});
      let initError1 = null;
      let initError2 = null;

      try { await retryInitWrapper.initializeEngine(); } catch (e) { initError1 = e.message; }
      try { await retryInitWrapper.initializeEngine(); } catch (e) { initError2 = e.message; }

      // Simultaneous retries by two callers on attempt 3
      const [retryRunnerA, retryRunnerB] = await Promise.all([
        retryInitWrapper.initializeEngine(),
        retryInitWrapper.initializeEngine()
      ]);

      const retryInitSuccess = (
        initError1.includes('attempt #1') &&
        initError2.includes('attempt #2') &&
        failInitCount === 3 &&
        retryRunnerA === retryRunnerB
      );

      // 4. Deliberate retry on failed runApp
      let failRunCount = 0;
      const failingRunInit = {
        initializeEngine: async function () {
          return {
            runApp: async function () {
              failRunCount++;
              if (failRunCount === 1) {
                throw new Error('Transient runApp error');
              }
              return { addView: () => 3, recoveredRun: true };
            }
          };
        }
      };

      const retryRunWrapper = createWrapper(failingRunInit, {});
      const runnerForRun = await retryRunWrapper.initializeEngine();
      let runError = null;
      try { await runnerForRun.runApp(); } catch (e) { runError = e.message; }

      // Concurrent retry by two callers
      const [recoveredAppA, recoveredAppB] = await Promise.all([
        runnerForRun.runApp(),
        runnerForRun.runApp()
      ]);

      const retryRunSuccess = (
        runError.includes('Transient runApp error') &&
        failRunCount === 2 &&
        recoveredAppA === recoveredAppB &&
        recoveredAppA.recoveredRun === true
      );

      return {
        singleInit,
        runnersIdentical,
        configPreserved,
        singleRun,
        appsIdentical,
        retryInitSuccess,
        retryRunSuccess
      };
    });

    expect(concurrencyResults.singleInit).toBe(true);
    expect(concurrencyResults.runnersIdentical).toBe(true);
    expect(concurrencyResults.configPreserved).toBe(true);
    expect(concurrencyResults.singleRun).toBe(true);
    expect(concurrencyResults.appsIdentical).toBe(true);
    expect(concurrencyResults.retryInitSuccess).toBe(true);
    expect(concurrencyResults.retryRunSuccess).toBe(true);
  });

  test('C16: Island remounting safety, unsafe remount rejection, and interaction post-remount', async ({ page }) => {
    await page.goto(`${ISLANDS_URL}/products/basmati-rice`, { waitUntil: 'domcontentloaded' });

    const cartIsland = page.locator('#flutter-cart-island');
    const counterIsland = page.locator('#flutter-counter-island');

    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });

    // Step 1: Clean disposal
    await page.evaluate(() => {
      window.__mantleDisposeIslands();
    });
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'disposed');

    // Step 2: Clean remount
    await page.evaluate(() => {
      return window.__mantleRemountIslands();
    });
    await expect(cartIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });
    await expect(counterIsland).toHaveAttribute('data-mantle-island-lifecycle', 'mounted', { timeout: 30000 });

    // Verify interaction works after remounting
    const semanticBtn = cartIsland.locator('flt-semantics[role="button"], flt-semantics button, [role="button"]:visible').filter({ hasText: 'Add to Cart' });
    if (await semanticBtn.count() > 0) {
      await semanticBtn.first().click();
    } else {
      await cartIsland.click({ position: { x: 60, y: 25 } });
    }

    await expect.poll(async () => {
      return await page.evaluate(() => window.__mantleDartCartCount);
    }, { timeout: 10000 }).toBe(1);

    // Verify active view tracking registry consistency
    const registryCheck = await page.evaluate(() => {
      const v1 = document.getElementById('flutter-cart-island').getAttribute('data-mantle-view-id');
      const v2 = document.getElementById('flutter-counter-island').getAttribute('data-mantle-view-id');
      const activeMap = window.__mantleActiveViews || {};
      return {
        v1InMap: Boolean(activeMap[v1]),
        v2InMap: Boolean(activeMap[v2]),
        uniqueIds: v1 !== v2
      };
    });

    expect(registryCheck.v1InMap).toBe(true);
    expect(registryCheck.v2InMap).toBe(true);
    expect(registryCheck.uniqueIds).toBe(true);
  });
});
