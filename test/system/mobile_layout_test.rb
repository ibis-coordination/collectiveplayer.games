require "application_system_test_case"

# Mobile layout requirements (see CLAUDE.md Design Priorities): the game
# is played primarily on phones, so at a 390px viewport every screen must
# fit without horizontal scrolling and every tap target must be at least
# 44px tall (Apple HIG / Android touch-target minimum).
class MobileLayoutTest < ApplicationSystemTestCase
  MIN_TOUCH_TARGET = 44

  test "home page fits the viewport with touch-friendly controls" do
    visit root_path

    assert_no_horizontal_overflow
    assert_touch_friendly_controls
  end

  test "lobby stacks group columns vertically and fits the viewport" do
    create_session_via_ui

    assert_no_horizontal_overflow
    assert_touch_friendly_controls

    # Side-by-side ~150px columns are unusable on a phone: each group
    # column should take (nearly) the full content width
    viewport_width = page.evaluate_script("window.innerWidth")
    column_widths = page.evaluate_script(
      "Array.from(document.querySelectorAll('.group-column')).map(el => el.getBoundingClientRect().width)"
    )
    assert_equal 2, column_widths.size
    column_widths.each do |width|
      assert width > viewport_width * 0.7,
        "group column is #{width.round}px wide in a #{viewport_width}px viewport; expected stacked (near full-width) columns"
    end
  end

  test "active game word input fits the viewport on one row" do
    create_session_via_ui
    click_on "Create & Join Group", match: :first
    assert_text "You're in this group"

    # Seed the opposing group directly; the UI can't act as two players at once
    game = GameSession.order(:created_at).last
    other_group = game.groups.create!(name: "Opponents")
    game.players.create!(name: "Opponent", group: other_group)

    visit current_path
    click_on "Start Game"
    assert_selector ".game-active"

    # Make it deterministically our turn so the word input renders
    game.reload.update!(current_turn_group: game.players.find_by(token: game.host_token).group)
    refresh

    assert_selector ".word-input input"
    assert_no_horizontal_overflow
    assert_touch_friendly_controls

    # The word field and its add-word button belong on the same row, not
    # wrapped. (The Send Message pill sits on its own row above them.)
    input_top, button_top = page.evaluate_script(<<~JS)
      [document.querySelector('.word-input-row input').getBoundingClientRect().top,
       document.querySelector('.word-input-row button').getBoundingClientRect().top]
    JS
    assert_in_delta input_top, button_top, 1.0,
      "word field (top #{input_top}) and add-word button (top #{button_top}) should share a row"
  end

  private

  def create_session_via_ui
    visit root_path
    fill_in "Your Name", with: "Hostess"
    select "Unlimited", from: "Time per Round"
    click_on "Create Session"
    assert_text "Session Code:"
  end

  def assert_no_horizontal_overflow
    scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
    viewport_width = page.evaluate_script("window.innerWidth")
    assert scroll_width <= viewport_width,
      "page overflows horizontally: #{scroll_width}px of content in a #{viewport_width}px viewport"
  end

  # Every visible interactive control must be at least 44px tall
  def assert_touch_friendly_controls
    controls = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('button, .btn, input, select'))
        .filter(el => el.offsetParent !== null)
        .map(el => {
          const r = el.getBoundingClientRect()
          return { label: (el.textContent || el.placeholder || el.name || el.tagName).trim().slice(0, 30), height: r.height }
        })
    JS
    assert controls.any?, "expected interactive controls on the page"
    too_small = controls.select { |c| c["height"] < MIN_TOUCH_TARGET }
    assert too_small.empty?,
      "touch targets under #{MIN_TOUCH_TARGET}px: " +
        too_small.map { |c| "#{c['label'].inspect} (#{c['height'].round}px)" }.join(", ")
  end
end
