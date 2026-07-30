require "application_system_test_case"

class MobileSmokeTest < ApplicationSystemTestCase
  test "host creates a session and reaches the lobby" do
    visit root_path

    fill_in "Your Name", with: "Hostess"
    click_on "Create Session"

    assert_text "Session Code:"
    assert_selector ".group-column", count: 2
  end
end
