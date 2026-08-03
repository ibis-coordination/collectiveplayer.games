require "application_system_test_case"

# The active game should feel like a chat app on a phone: the page itself
# never scrolls, the transcript fills the screen and is the only scrolling
# region, the composer stays visible at the bottom, and messages render as
# left/right-aligned bubbles by sender.
class ChatLayoutTest < ApplicationSystemTestCase
  test "active game lays out like a chat screen" do
    start_active_game_with_conversation

    # The page itself must not scroll — only the transcript scrolls
    page_scroll, viewport_h = page.evaluate_script(
      "[document.documentElement.scrollHeight, window.innerHeight]"
    )
    assert page_scroll <= viewport_h + 1,
      "page scrolls vertically (#{page_scroll}px content in #{viewport_h}px viewport); only the transcript should scroll"

    # The transcript should fill the screen, not sit in a small fixed box
    transcript_h = page.evaluate_script(
      "document.querySelector('.chat-transcript').getBoundingClientRect().height"
    )
    assert transcript_h >= viewport_h * 0.45,
      "transcript is only #{transcript_h.round}px tall in a #{viewport_h}px viewport; it should fill the available space"

    # The composer must be visible without scrolling the page
    composer_bottom = page.evaluate_script(
      "document.querySelector('.word-input').getBoundingClientRect().bottom"
    )
    assert composer_bottom <= viewport_h + 1,
      "composer bottom (#{composer_bottom.round}px) is below the #{viewport_h}px viewport"
  end

  test "messages render as chat bubbles aligned by sender" do
    start_active_game_with_conversation

    own, other, transcript = page.evaluate_script(<<~JS)
      ['.chat-message.own-group', '.chat-message.other-group', '.chat-transcript'].map(sel => {
        const r = document.querySelector(sel).getBoundingClientRect()
        return { left: r.left, right: r.right, width: r.width }
      })
    JS

    # Own messages hug the right edge, the other group's hug the left
    assert (transcript["right"] - own["right"]).abs <= 30,
      "own-group bubble should be right-aligned (right edge #{own['right'].round} vs transcript #{transcript['right'].round})"
    assert (other["left"] - transcript["left"]).abs <= 30,
      "other-group bubble should be left-aligned (left edge #{other['left'].round} vs transcript #{transcript['left'].round})"

    # Bubbles are bubbles, not full-width rows: these seeded messages are
    # only a few words, so a fit-content bubble must be well under half
    # the transcript width
    [["own-group", own], ["other-group", other]].each do |label, rect|
      assert rect["width"] <= transcript["width"] * 0.6,
        "#{label} bubble is #{rect['width'].round}px wide in a #{transcript['width'].round}px transcript; expected a fit-content bubble sized to its short message"
    end
  end

  private

  def start_active_game_with_conversation
    visit ggc_path
    fill_in "Your Name", with: "Hostess"
    select "Unlimited", from: "Time per Round"
    click_on "Create Session"
    assert_text "Session Code:"
    click_on "Create & Join Group", match: :first
    assert_text "You're in this group"

    game = GameSession.order(:created_at).last
    other_group = game.groups.create!(name: "Opponents")
    game.players.create!(name: "Opponent", group: other_group)

    visit current_path
    click_on "Start Game"
    assert_selector ".game-active"

    # Deterministic turn + a short seeded conversation, ending with a fresh
    # empty message for our group (as switch_turn! + start_new_message! would)
    game.reload
    host_group = game.players.find_by(token: game.host_token).group
    m1 = game.messages.create!(group: other_group, position: game.messages.count + 1)
    %w[hey how are you].each_with_index { |w, i| m1.words.create!(position: i + 1, text: w) }
    m2 = game.messages.create!(group: host_group, position: game.messages.count + 1)
    %w[great thanks].each_with_index { |w, i| m2.words.create!(position: i + 1, text: w) }
    m3 = game.messages.create!(group: other_group, position: game.messages.count + 1)
    %w[glad to hear it].each_with_index { |w, i| m3.words.create!(position: i + 1, text: w) }
    game.update!(current_turn_group: host_group)
    game.messages.create!(group: host_group, position: game.messages.count + 1)

    refresh
    assert_selector ".word-input input"
  end
end
