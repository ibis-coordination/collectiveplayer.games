require "test_helper"

class GameFlowTest < ActionDispatch::IntegrationTest
  # Helper: Create game session and join as host (properly authenticated)
  def create_game_as_host(host_name: "Host")
    post game_sessions_path, params: { host_name: host_name }
    GameSession.last
  end

  test "host can create game and start when conditions are met" do
    # Create game as host
    game_session = create_game_as_host(host_name: "Alice")
    host = game_session.players.first

    assert game_session.waiting?
    assert_equal "Alice", host.name
    assert host.host?

    # Host creates and joins first group
    post join_group_game_session_path(game_session.code), params: { group_id: "new" }
    group1 = game_session.groups.last
    host.reload
    assert_equal group1, host.group

    # Create second group and add a player (directly in DB for test simplicity)
    group2 = game_session.groups.create!(name: "Team B")
    game_session.players.create!(name: "Player 2", group: group2)

    # Host starts the game
    post start_game_session_path(game_session.code)
    game_session.reload

    assert game_session.active?
    assert_includes [group1, group2], game_session.current_turn_group
    assert_not_nil game_session.round_started_at
  end

  test "host can end active game" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1)

    post end_game_game_session_path(game_session.code)
    game_session.reload

    assert game_session.complete?
  end

  test "host in active group can submit word" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    # Second player in group1 keeps the round open, so the submission persists
    game_session.players.create!(name: "Teammate", group: group1)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    assert_difference "Submission.count", 1 do
      post submit_word_game_session_path(game_session.code), params: { word: "hello" }
    end
    assert_response :ok

    submission = game_session.current_message.submissions.last
    assert_equal "hello", submission.word
    assert_equal host, submission.player
  end

  test "host in non-active group cannot submit word" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group2)  # Host is in group2
    game_session.players.create!(name: "Player 1", group: group1)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    assert_no_difference "Submission.count" do
      post submit_word_game_session_path(game_session.code), params: { word: "sneaky" }
    end
    assert_response :forbidden
  end

  test "host can update their group name" do
    game_session = create_game_as_host
    group = game_session.groups.create!(name: "Team A")
    host = game_session.players.first
    host.update!(group: group)

    post update_group_name_game_session_path(game_session.code), params: {
      group_id: group.id, name: "The Champions"
    }
    assert_response :ok

    group.reload
    assert_equal "The Champions", group.name
  end

  test "host cannot update name of group they are not in" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)

    # Try to rename group2 while in group1
    post update_group_name_game_session_path(game_session.code), params: {
      group_id: group2.id, name: "Hacked"
    }
    assert_response :forbidden

    group2.reload
    assert_equal "Team B", group2.name
  end

  test "turn switching works correctly" do
    game_session = GameSession.create!
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    game_session.players.create!(name: "Player 1", group: group1, token: game_session.host_token)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1)

    # Add a word to the message first
    message = game_session.current_message
    message.words.create!(position: 1, text: "hello")

    # Switch turn
    game_session.switch_turn!
    game_session.reload

    assert_equal group2, game_session.current_turn_group
  end

  test "conversation returns messages in position order" do
    game_session = GameSession.create!
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    game_session.update!(status: :active, current_turn_group: group1)

    # Create messages out of order
    msg2 = game_session.messages.create!(group: group2, position: 2)
    msg2.words.create!(position: 1, text: "Hi")
    msg2.words.create!(position: 2, text: "back")

    msg1 = game_session.messages.create!(group: group1, position: 1)
    msg1.words.create!(position: 1, text: "Hello")
    msg1.words.create!(position: 2, text: "there")

    conversation = game_session.conversation

    assert_equal 2, conversation.length
    assert_equal group1, conversation[0][:group]
    assert_equal "Hello there", conversation[0][:text]
    assert_equal group2, conversation[1][:group]
    assert_equal "Hi back", conversation[1][:text]
  end

  test "start game requires exactly 2 groups" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    host = game_session.players.first
    host.update!(group: group1)
    # Only 1 group exists

    post start_game_session_path(game_session.code)
    assert_redirected_to game_session_path(game_session.code)
    follow_redirect!
    assert_select ".alert", /need 2 groups/i

    game_session.reload
    assert game_session.waiting?
  end

  test "start game requires each group to have players" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    # group2 has no players

    post start_game_session_path(game_session.code)
    assert_redirected_to game_session_path(game_session.code)
    follow_redirect!
    assert_select ".alert", /each group needs at least 1 player/i

    game_session.reload
    assert game_session.waiting?
  end

  test "starting game twice does not reset to waiting state" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.players.create!(name: "Player 2", group: group2)

    # Start the game
    post start_game_session_path(game_session.code)
    game_session.reload
    assert game_session.active?

    # Try to start again
    post start_game_session_path(game_session.code)
    game_session.reload

    # Game should still be active (not reverted to waiting)
    assert game_session.active?
    # Should still have a valid current turn group
    assert_includes [group1, group2], game_session.current_turn_group
  end

  test "player joins with name" do
    game_session = GameSession.create!

    assert_difference "Player.count", 1 do
      post join_game_session_path(game_session.code), params: { name: "Bob" }
    end

    player = game_session.players.find_by(name: "Bob")
    assert_not_nil player
    assert_not player.host?
    assert_redirected_to game_session_path(game_session.code)
  end

  test "player cannot join without name" do
    game_session = GameSession.create!

    assert_no_difference "Player.count" do
      post join_game_session_path(game_session.code), params: { name: "" }
    end

    assert_redirected_to game_session_path(game_session.code)
    follow_redirect!
    assert_select ".alert", /enter your name/i
  end

  test "creating a game generates unique session code" do
    post game_sessions_path, params: { host_name: "Alice" }
    game1 = GameSession.last

    reset!
    post game_sessions_path, params: { host_name: "Bob" }
    game2 = GameSession.last

    assert_not_equal game1.code, game2.code
    assert_match(/\A[A-Z0-9]{6}\z/, game1.code)
    assert_match(/\A[A-Z0-9]{6}\z/, game2.code)
  end

  test "game can track time limit setting" do
    post game_sessions_path, params: { host_name: "Alice", time_limit_seconds: 30 }
    game_session = GameSession.last

    assert_equal 30, game_session.time_limit_seconds
  end
end
