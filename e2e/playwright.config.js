// @ts-check
const { defineConfig, devices } = require('@playwright/test');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');

module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
  ],
  use: {
    baseURL: 'http://127.0.0.1:8080',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'desktop-chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 720 },
      },
    },
    {
      name: 'mobile-chromium',
      use: {
        ...devices['Pixel 5'],
        isMobile: true,
      },
    },
  ],
  webServer: {
    command: `dart run bin/meta_mantle.dart preview --config example/meta_mantle.config.json --dir example/build/web --port 8080 --no-watch`,
    cwd: rootDir,
    url: 'http://127.0.0.1:8080/',
    reuseExistingServer: true,
    timeout: 60000,
  },
});
