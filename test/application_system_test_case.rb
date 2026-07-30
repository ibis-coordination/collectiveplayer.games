require "test_helper"
require "capybara-playwright-driver"

# This game is mobile-first (see CLAUDE.md Design Priorities), so system
# tests emulate an iPhone-class device by default: mobile viewport, touch
# events enabled, 3x device pixel ratio.
Capybara.register_driver(:mobile_playwright) do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: true,
    playwright_cli_executable_path: "npx playwright",
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true
  )
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :mobile_playwright

  # Parallel workers can be slow on first page load (cold asset builds);
  # the default 2s wait is too tight and produces flaky failures
  Capybara.default_max_wait_time = 5
end
