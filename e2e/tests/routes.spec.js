// @ts-check
const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:8080';

const ROUTES = [
  { path: '/', title: 'MetaMantle Store - Home', heading: 'Fresh Groceries & Farm Essentials' },
  { path: '/about/', title: 'About Us', heading: 'About MetaMantle Store' },
  { path: '/products/', title: 'Product Catalog', heading: 'Featured Grocery Catalog' },
  { path: '/faq/', title: 'Frequently Asked Questions', heading: 'Frequently Asked Questions' },
  { path: '/products/basmati-rice/', title: 'Premium Basmati Rice', heading: 'Premium Basmati Rice' },
  { path: '/products/whole-milk/', title: 'Whole Milk', heading: 'Whole Milk' },
];

test.describe('Initial Server-Generated Content (Before Client JS Hydration)', () => {
  // Disable JavaScript so we inspect pure server-rendered HTML before any client hydration occurs
  test.use({ javaScriptEnabled: false });

  for (const route of ROUTES) {
    test(`Route "${route.path}" delivers pre-rendered content and valid metadata`, async ({ page }) => {
      const failedRequests = [];

      page.on('response', (res) => {
        if (res.status() >= 400 && !res.url().includes('favicon.ico')) {
          failedRequests.push(`${res.status()} ${res.url()}`);
        }
      });

      // 1. Direct Deep-Link Navigation
      const targetUrl = `${BASE_URL}${route.path}`;
      const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(200);

      // 2. Initial Server-Generated Content
      const heading = page.locator('h1, h2[itemprop="name"]').first();
      await expect(heading).toBeVisible();
      await expect(heading).toContainText(route.heading);

      // Verify page title
      await expect(page).toHaveTitle(new RegExp(route.title));

      // 3. Exactly one title and one description in <head>
      const titleCount = await page.locator('head title').count();
      expect(titleCount).toBe(1);

      const descCount = await page.locator('head meta[name="description"]').count();
      expect(descCount).toBe(1);

      // 4. Exactly one canonical link
      const canonicalCount = await page.locator('head link[rel="canonical"]').count();
      expect(canonicalCount).toBe(1);

      // 5. Semantic Navigation with accessible <a> links and aria-current
      const navLinks = page.locator('nav a');
      const count = await navLinks.count();
      expect(count).toBeGreaterThanOrEqual(4);

      // Verify no invalid aria-selected on links
      const invalidAriaSelected = await page.locator('nav a[aria-selected]').count();
      expect(invalidAriaSelected).toBe(0);

      // 6. No missing local assets (no 404s on stylesheets, scripts, local images)
      expect(failedRequests).toEqual([]);
    });
  }

  test('Responsive images scale properly without mobile viewport overflow', async ({ page }) => {
    await page.goto(`${BASE_URL}/`, { waitUntil: 'domcontentloaded' });

    const img = page.locator('img[src*="social-card.png"]').first();
    await expect(img).toBeVisible();

    const alt = await img.getAttribute('alt');
    expect(alt).toBeTruthy();

    const loading = await img.getAttribute('loading');
    expect(loading).toBe('lazy');

    // Check viewport overflow
    const overflow = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });
    expect(overflow).toBe(false);

    // Verify image clientWidth does not exceed viewport width
    const imgWidth = await img.evaluate((el) => el.clientWidth);
    const viewportWidth = await page.evaluate(() => window.innerWidth);
    expect(imgWidth).toBeLessThanOrEqual(viewportWidth);
  });

  test('Direct deep-link reload preserves stable content and metadata', async ({ page }) => {
    await page.goto(`${BASE_URL}/products/basmati-rice/`, { waitUntil: 'domcontentloaded' });
    const heading = page.locator('h1, h2[itemprop="name"]').first();
    await expect(heading).toContainText('Premium Basmati Rice');

    // Perform browser refresh
    await page.reload({ waitUntil: 'domcontentloaded' });

    // Assert content and metadata remain stable after refresh
    await expect(heading).toContainText('Premium Basmati Rice');
    await expect(page).toHaveTitle(/Premium Basmati Rice/);

    const titleCount = await page.locator('head title').count();
    expect(titleCount).toBe(1);
  });

  test('Semantic route navigation works between pages via links', async ({ page }) => {
    await page.goto(`${BASE_URL}/`, { waitUntil: 'domcontentloaded' });

    // Click "Products" nav link
    const productsLink = page.locator('nav a[href="/products"]').first();
    await expect(productsLink).toBeVisible();
    await productsLink.click();

    // Wait for URL to update to /products
    await expect(page).toHaveURL(/\/products/);
    await expect(page.locator('h1')).toContainText('Featured Grocery Catalog');

    // Verify active link on the navigated page has aria-current="page"
    const activeLink = page.locator('nav a[href="/products"]').first();
    await expect(activeLink).toHaveAttribute('aria-current', 'page');
  });
});

test.describe('Client Runtime Hydration and Coordination (With JS)', () => {
  test.use({ javaScriptEnabled: true });

  test('Flutter bootstrap initialization script is present and valid', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto(`${BASE_URL}/`, { waitUntil: 'domcontentloaded' });

    // Script flutter_bootstrap.js is present in DOM
    const bootstrapScript = page.locator('script[src*="flutter_bootstrap.js"]');
    await expect(bootstrapScript).toHaveCount(1);

    // No unhandled critical console errors during startup
    const criticalErrors = consoleErrors.filter(
      (e) => !e.includes('favicon.ico') && !e.includes('Refused to get unsafe header')
    );
    expect(criticalErrors).toEqual([]);
  });
});
