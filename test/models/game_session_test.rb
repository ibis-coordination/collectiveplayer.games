require "test_helper"

class GameSessionTest < ActiveSupport::TestCase
  test "generates unique 6-character code on create" do
    session = GameSession.create!

    assert_not_nil session.code
    assert_equal 6, session.code.length
    assert_match /\A[A-Z2-9]+\z/, session.code
  end

  test "generates host_token on create" do
    session = GameSession.create!

    assert_not_nil session.host_token
    assert session.host_token.length > 20
  end

  test "defaults to waiting status" do
    session = GameSession.create!

    assert session.waiting?
  end

  test "defaults to no current turn group" do
    session = GameSession.create!

    assert_nil session.current_turn_group
  end

  test "conversation returns messages with group info" do
    session = GameSession.create!
    group1 = session.groups.create!(name: "Team A")
    group2 = session.groups.create!(name: "Team B")

    msg1 = session.messages.create!(group: group1, position: 1)
    msg1.words.create!(position: 1, text: "hello")
    msg1.words.create!(position: 2, text: "world")

    msg2 = session.messages.create!(group: group2, position: 2)
    msg2.words.create!(position: 1, text: "hi")

    conversation = session.conversation
    assert_equal 2, conversation.length
    assert_equal "hello world", conversation[0][:text]
    assert_equal group1, conversation[0][:group]
    assert_equal "hi", conversation[1][:text]
    assert_equal group2, conversation[1][:group]
  end

  test "conversation returns empty array when no messages" do
    session = GameSession.create!

    assert_equal [], session.conversation
  end

  test "all_group_players_submitted? returns true when all group players have submitted" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player1 = session.players.create!(name: "Player 1", group: group)
    player2 = session.players.create!(name: "Player 2", group: group)
    session.update!(current_turn_group: group)

    message = session.current_message
    message.submissions.create!(player: player1, word: "hello")
    message.submissions.create!(player: player2, word: "world")

    assert session.all_group_players_submitted?
  end

  test "all_group_players_submitted? returns false when not all group players have submitted" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player1 = session.players.create!(name: "Player 1", group: group)
    player2 = session.players.create!(name: "Player 2", group: group)
    session.update!(current_turn_group: group)

    message = session.current_message
    message.submissions.create!(player: player1, word: "hello")

    assert_not session.all_group_players_submitted?
  end

  test "player_submitted? returns true for player who submitted current message" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player 1", group: group)
    session.update!(current_turn_group: group)

    message = session.current_message
    message.submissions.create!(player: player, word: "hello")

    assert session.player_submitted?(player)
  end

  test "player_submitted? returns false for player who has not submitted current message" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player 1", group: group)
    session.update!(current_turn_group: group)
    session.current_message # Ensure message is created

    assert_not session.player_submitted?(player)
  end

  test "player_submitted? checks current message not previous messages" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player 1", group: group)
    session.update!(current_turn_group: group)

    # Submit for first message
    first_message = session.current_message
    first_message.submissions.create!(player: player, word: "hello")

    # Create new message (simulating turn switch and return)
    session.start_new_message!

    # Player has not submitted for new message yet
    assert_not session.player_submitted?(player)
  end

  test "determine_winner returns word with most votes (case-insensitive)" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player1 = session.players.create!(name: "Player 1", group: group)
    player2 = session.players.create!(name: "Player 2", group: group)
    player3 = session.players.create!(name: "Player 3", group: group)
    session.update!(current_turn_group: group)

    message = session.current_message
    message.submissions.create!(player: player1, word: "Hello")
    message.submissions.create!(player: player2, word: "hello")
    message.submissions.create!(player: player3, word: "world")

    # "hello" has 2 votes, "world" has 1
    assert_equal "hello", session.determine_winner
  end

  test "determine_winner breaks ties randomly" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player1 = session.players.create!(name: "Player 1", group: group)
    player2 = session.players.create!(name: "Player 2", group: group)
    session.update!(current_turn_group: group)

    message = session.current_message
    message.submissions.create!(player: player1, word: "hello")
    message.submissions.create!(player: player2, word: "world")

    # Both have 1 vote, should return one of them
    winner = session.determine_winner
    assert_includes ["hello", "world"], winner
  end

  test "add_winning_word! creates word on current message" do
    session = GameSession.create!(round_started_at: Time.current)
    group = session.groups.create!(name: "Team A")
    session.update!(current_turn_group: group)

    session.add_winning_word!("hello")

    message = session.current_message
    assert_equal 1, message.words.count
    assert_equal "hello", message.words.first.text
    assert_equal 1, message.words.first.position
  end

  test "add_winning_word! sets correct position for subsequent words" do
    session = GameSession.create!(round_started_at: Time.current)
    group = session.groups.create!(name: "Team A")
    session.update!(current_turn_group: group)

    session.add_winning_word!("hello")
    session.add_winning_word!("world")

    message = session.current_message
    assert_equal 2, message.words.count
    assert_equal 2, message.words.find_by(text: "world").position
  end

  test "switch_turn! changes to the other group" do
    session = GameSession.create!
    group1 = session.groups.create!(name: "Team A")
    group2 = session.groups.create!(name: "Team B")
    session.update!(current_turn_group: group1, round_started_at: Time.current)

    session.switch_turn!

    assert_equal group2, session.current_turn_group
  end

  test "start_new_message! creates a new message for current group" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    session.update!(current_turn_group: group, round_started_at: Time.current)

    # Create first message
    session.current_message

    # Create second message
    session.start_new_message!

    assert_equal 2, session.messages.count
    assert_equal 2, session.messages.last.position
  end

  # ============= COMPLETE_ROUND! =============
  # Round processing must be self-guarding: it only acts when the round is
  # actually complete, and a repeated/concurrent call is a no-op. This
  # prevents two simultaneous submits from double-processing a round.

  def build_active_session(players_in_group1: 2)
    session = GameSession.create!
    group1 = session.groups.create!(name: "Team A")
    group2 = session.groups.create!(name: "Team B")
    players_in_group1.times { |i| session.players.create!(name: "P#{i + 1}", group: group1) }
    session.players.create!(name: "Other", group: group2)
    session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)
    [session, group1, group2]
  end

  test "complete_round! adds the winning word and clears submissions" do
    session, group1, = build_active_session
    message = session.current_message
    group1.players.each { |p| message.submissions.create!(player: p, word: "hello") }

    events = session.complete_round!

    assert_equal "hello", message.reload.text
    assert_equal 0, message.submissions.count
    assert_equal "word_revealed", events.first[:type]
  end

  test "complete_round! does nothing until all players have submitted" do
    session, group1, = build_active_session
    message = session.current_message
    message.submissions.create!(player: group1.players.first, word: "hello")

    events = session.complete_round!

    assert_nil events
    assert_equal "", message.reload.text
    assert_equal 1, message.submissions.count
  end

  test "complete_round! is a no-op when called again after processing" do
    session, group1, = build_active_session
    message = session.current_message
    group1.players.each { |p| message.submissions.create!(player: p, word: "hello") }

    session.complete_round!
    events = session.complete_round!

    assert_nil events
    assert_equal "hello", message.reload.text
    assert_equal 1, message.words.count
  end

  test "complete_round! completes the message and switches turn on END" do
    session, group1, group2 = build_active_session
    message = session.current_message
    session.add_winning_word!("hello")
    group1.players.each { |p| message.submissions.create!(player: p, word: "END") }

    events = session.complete_round!

    assert_equal group2, session.reload.current_turn_group
    assert_equal %w[message_completed turn_switched], events.map { |e| e[:type] }
    assert_equal "hello", events.first[:message_text]
  end

  test "complete_round! ends the game when END is the first word" do
    session, group1, = build_active_session
    message = session.current_message
    group1.players.each { |p| message.submissions.create!(player: p, word: "END") }

    events = session.complete_round!

    assert session.reload.complete?
    assert_equal "game_ended", events.first[:type]
  end
end
