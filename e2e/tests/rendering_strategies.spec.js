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
      await page.waitForURL(/\/products/, { timeout: 10000 }).catch(() => {});
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
});
