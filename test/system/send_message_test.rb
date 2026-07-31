require "application_system_test_case"

# The composer has two distinct actions: a round "add word" button that
# submits the typed word, and a "Send Message" button that submits END
# (finishing the current message). Sending an empty message would end
# the game, so it asks for confirmation.
class SendMessageTest < ApplicationSystemTestCase
  test "composer shows both add word and send message buttons on our turn" do
    start_active_game_with_words(%w[hello there])

    assert_selector ".word-input .btn-send", text: /↑|Send/  # add-word button
    assert_selector ".word-input .btn-send-message", text: /Send Message/i
  end

  test "tapping Send Message submits END and completes the current message" do
    game = start_active_game_with_words(%w[hello there])
    host_group = game.players.find_by(token: game.host_token).group

    click_on "Send Message"
    # Server processes END → message completes → turn switches. Waiting on
    # this UI change also ensures the ActionCable round-trip is done.
    assert_text "Watch the other group"
    refute_equal host_group.id, game.reload.current_turn_group_id,
      "turn should have switched to the other group after Send Message"
  end

  test "tapping Send Message on an empty message asks to confirm" do
    game = start_active_game_with_words([])

    dismiss_confirm do
      click_on "Send Message"
    end
    # Nothing was submitted; the composer is still in its initial state
    assert_selector ".btn-send-message"
    assert_no_selector ".submitted-message"

    accept_confirm do
      click_on "Send Message"
    end
    # END as the first word of a message ends the whole game;
    # the client reloads to the completion screen once it happens.
    assert_text "Conversation Complete!"
    assert game.reload.complete?
  end

  private

  # Set up a game where it's our (host's) turn to compose. `word_texts`
  # seeds the current in-progress message so we can test both the empty
  # and mid-message paths.
  def start_active_game_with_words(word_texts)
    visit root_path
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

    host_group = game.players.find_by(token: game.host_token).group
    game.reload.update!(current_turn_group: host_group)
    message = game.current_message!
    word_texts.each_with_index { |w, i| message.words.create!(position: i + 1, text: w) }

    refresh
    assert_selector ".word-input"
    game
  end
end
