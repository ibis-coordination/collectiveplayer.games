require "application_system_test_case"

# The app should follow the device's appearance setting: iOS-dark styling
# for dark mode users, iOS-light styling for light mode users.
class ColorSchemeTest < ApplicationSystemTestCase
  test "light scheme users get a light background with dark text" do
    visit root_path
    emulate_color_scheme("light")

    assert_equal "rgb(255, 255, 255)", body_style("backgroundColor")
    assert_equal "rgb(0, 0, 0)", body_style("color")
  end

  test "dark scheme users get a black background with white text" do
    visit root_path
    emulate_color_scheme("dark")

    assert_equal "rgb(0, 0, 0)", body_style("backgroundColor")
    assert_equal "rgb(255, 255, 255)", body_style("color")
  end

  private

  def emulate_color_scheme(scheme)
    page.driver.with_playwright_page do |pw_page|
      pw_page.emulate_media(colorScheme: scheme)
    end
  end

  def body_style(property)
    page.evaluate_script("getComputedStyle(document.body).#{property}")
  end
end
