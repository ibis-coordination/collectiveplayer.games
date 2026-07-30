require "test_helper"

class GameSessionsControllerTest < ActionDispatch::IntegrationTest
  # Helper: Create game session and join as host (properly authenticated)
  def create_game_as_host(host_name: "Host", time_limit: nil)
    params = { host_name: host_name }
    params[:time_limit_seconds] = time_limit if time_limit
    post game_sessions_path, params: params
    GameSession.last
  end

  # Helper: Join a game session as a new player (properly authenticated)
  def join_game_as_player(game_session, player_name:)
    post join_game_session_path(game_session.code), params: { name: player_name }
    game_session.players.find_by(name: player_name)
  end

  # ============= CREATE =============

  test "create creates a new game session with host player" do
    assert_difference ["GameSession.count", "Player.count"], 1 do
      post game_sessions_path, params: { host_name: "Alice" }
    end

    game_session = GameSession.last
    assert game_session.waiting?
    assert_equal 1, game_session.players.count
    assert_equal "Alice", game_session.players.first.name
    assert game_session.players.first.host?
    assert_redirected_to game_session_path(game_session.code)
  end

  test "create with time_limit_seconds" do
    post game_sessions_path, params: { host_name: "Alice", time_limit_seconds: 30 }

    game_session = GameSession.last
    assert_equal 30, game_session.time_limit_seconds
  end

  # ============= SHOW =============

  test "show renders join form for non-joined player" do
    game_session = GameSession.create!

    get game_session_path(game_session.code)

    assert_response :success
    assert_select "input[name='name']"
  end

  # ============= JOIN =============

  test "join creates a new player" do
    game_session = GameSession.create!

    assert_difference "Player.count", 1 do
      post join_game_session_path(game_session.code), params: { name: "Bob" }
    end

    assert_equal "Bob", game_session.players.last.name
    assert_redirected_to game_session_path(game_session.code)
  end

  test "join requires a name" do
    game_session = GameSession.create!

    post join_game_session_path(game_session.code), params: { name: "" }

    assert_redirected_to game_session_path(game_session.code)
    follow_redirect!
    assert_select ".alert", /enter your name/i
  end

  # ============= JOIN_GROUP =============

  test "join_group creates new group when group_id is 'new'" do
    # Create game and stay logged in as host
    game_session = create_game_as_host

    assert_difference "Group.count", 1 do
      post join_group_game_session_path(game_session.code), params: { group_id: "new" }
    end

    group = game_session.groups.last
    assert_equal "Group 1", group.name
  end

  test "join_group assigns player to existing group" do
    game_session = create_game_as_host
    group = game_session.groups.create!(name: "Team A")
    host = game_session.players.first

    post join_group_game_session_path(game_session.code), params: { group_id: group.id }

    host.reload
    assert_equal group, host.group
  end

  test "join_group limits to 2 groups" do
    game_session = create_game_as_host
    game_session.groups.create!(name: "Team A")
    game_session.groups.create!(name: "Team B")

    post join_group_game_session_path(game_session.code), params: { group_id: "new" }

    assert_redirected_to game_session_path(game_session.code)
    follow_redirect!
    assert_select ".alert", /maximum 2 groups/i
  end

  # ============= UPDATE_GROUP_NAME =============

  test "update_group_name changes group name" do
    game_session = create_game_as_host
    group = game_session.groups.create!(name: "Team A")
    host = game_session.players.first
    host.update!(group: group)

    post update_group_name_game_session_path(game_session.code), params: { group_id: group.id, name: "The Winners" }

    assert_response :ok
    group.reload
    assert_equal "The Winners", group.name
  end

  test "update_group_name requires player to be in that group" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)

    post update_group_name_game_session_path(game_session.code), params: { group_id: group2.id, name: "Hackers" }

    assert_response :forbidden
    group2.reload
    assert_equal "Team B", group2.name
  end

  # ============= START =============

  test "start requires host" do
    # Create a game session with the host but don't stay logged in as host
    game_session = GameSession.create!
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    game_session.players.create!(name: "Host", token: game_session.host_token, group: group1)
    game_session.players.create!(name: "Player 2", group: group2)

    # Join as a different non-host player
    join_game_as_player(game_session, player_name: "Not Host")

    post start_game_session_path(game_session.code)

    assert_redirected_to game_session_path(game_session.code)
    game_session.reload
    assert game_session.waiting?
  end

  test "start requires 2 groups" do
    game_session = create_game_as_host
    group = game_session.groups.create!(name: "Team A")
    host = game_session.players.first
    host.update!(group: group)

    post start_game_session_path(game_session.code)

    assert_redirected_to game_session_path(game_session.code)
    follow_redirect!
    assert_select ".alert", /need 2 groups/i
  end

  test "start requires each group to have at least 1 player" do
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
  end

  test "start activates game and sets current_turn_group" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.players.create!(name: "Player 2", group: group2)

    post start_game_session_path(game_session.code)

    game_session.reload
    assert game_session.active?
    assert_includes [group1, group2], game_session.current_turn_group
    assert_not_nil game_session.round_started_at
  end

  # ============= END_GAME =============

  test "end_game requires host" do
    game_session = GameSession.create!
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    game_session.players.create!(name: "Host", token: game_session.host_token, group: group1)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1)

    # Login as non-host
    join_game_as_player(game_session, player_name: "NonHost")

    post end_game_game_session_path(game_session.code)

    game_session.reload
    assert game_session.active?
  end

  test "end_game completes the game" do
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

  # ============= MID-GAME JOIN / SPECTATORS =============
  # Rules: latecomers can join an active game (they spectate ungrouped and may
  # pick a group at any time to start playing). Grouped players are locked to
  # their group once the game starts. Completed games are view-only.

  def create_active_game
    game_session = GameSession.create!
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    game_session.players.create!(name: "P1", group: group1)
    game_session.players.create!(name: "P2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)
    game_session
  end

  test "latecomer can join an active game as an ungrouped spectator" do
    game_session = create_active_game

    assert_difference "Player.count", 1 do
      post join_game_session_path(game_session.code), params: { name: "Latecomer" }
    end

    latecomer = game_session.players.find_by(name: "Latecomer")
    assert_nil latecomer.group
    assert_redirected_to game_session_path(game_session.code)
  end

  test "join is rejected once the game is complete" do
    game_session = create_active_game
    game_session.update!(status: :complete)

    assert_no_difference "Player.count" do
      post join_game_session_path(game_session.code), params: { name: "Latecomer" }
    end

    assert_redirected_to root_path
  end

  test "ungrouped player can join a group mid-game" do
    game_session = create_active_game
    group2 = game_session.groups.second
    join_game_as_player(game_session, player_name: "Latecomer")

    post join_group_game_session_path(game_session.code), params: { group_id: group2.id }

    latecomer = game_session.players.find_by(name: "Latecomer")
    assert_equal group2, latecomer.group
  end

  test "grouped player cannot switch groups mid-game" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.players.create!(name: "P2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    # Host tries to defect to the other team mid-game
    post join_group_game_session_path(game_session.code), params: { group_id: group2.id }

    assert_equal group1, host.reload.group
  end

  test "show renders the join form for non-players while the game is active" do
    game_session = create_active_game

    get game_session_path(game_session.code)

    assert_response :ok
  end

  test "show renders the final conversation for non-players once the game is complete" do
    game_session = create_active_game
    game_session.update!(status: :complete)

    get game_session_path(game_session.code)

    assert_response :ok
    assert_match "Conversation Complete", response.body
  end

  test "ungrouped spectator sees the active game with group join buttons" do
    game_session = create_active_game
    join_game_as_player(game_session, player_name: "Spectator")

    get game_session_path(game_session.code)

    assert_response :ok
    assert_match "spectating", response.body
  end

  # Regression: the waiting-for-other-group view must still render the
  # wordInput target. The JS injects the word input into that target when the
  # turn switches; without it, the second group never gets an input box and
  # can never submit.
  test "inactive group player still has the wordInput target for turn switches" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group2) # host's group is NOT the active group
    game_session.players.create!(name: "P1", group: group1)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    get game_session_path(game_session.code)

    assert_response :ok
    assert_select "[data-game-target=wordInput]"
  end

  # ============= SUBMIT_WORD =============

  test "submit_word creates submission for active group player" do
    # Create game and log in as host
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    # Second player in group1 keeps the round open, so the submission persists
    game_session.players.create!(name: "Teammate", group: group1)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    # Host is in group1, which is the active group
    assert_difference "Submission.count", 1 do
      post submit_word_game_session_path(game_session.code), params: { word: "hello" }
    end

    assert_response :ok
  end

  test "submit_word rejects submission from non-active group" do
    # Create game and log in as host
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group2)  # Host is in group2
    game_session.players.create!(name: "Player 1", group: group1)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    # Host is in group2, but group1's turn
    assert_no_difference "Submission.count" do
      post submit_word_game_session_path(game_session.code), params: { word: "hello" }
    end

    assert_response :forbidden
  end

  test "submit_word rejects empty words" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    assert_no_difference "Submission.count" do
      post submit_word_game_session_path(game_session.code), params: { word: "" }
    end

    assert_response :unprocessable_entity
  end

  # Regression: submissions must be cleared when a round completes, otherwise
  # every player counts as "already submitted" forever and the game deadlocks
  # after the first word.
  test "player can submit again after a round completes" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    post submit_word_game_session_path(game_session.code), params: { word: "hello" }
    assert_response :ok
    assert_equal "hello", game_session.reload.current_message!.text

    # Host is the only player in the active group, so the round completed.
    # The next word must be accepted.
    post submit_word_game_session_path(game_session.code), params: { word: "world" }
    assert_response :ok
    assert_equal "hello world", game_session.reload.current_message!.text
  end

  test "submissions are cleared after a round completes" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.players.create!(name: "Player 2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    post submit_word_game_session_path(game_session.code), params: { word: "hello" }

    assert_equal 0, game_session.reload.current_message!.submissions.count
  end

  # Regression: a visitor who never joined the session has no @current_player;
  # submit_word must reject them, not raise NoMethodError (500).
  test "submit_word rejects visitor who has not joined" do
    game_session = GameSession.create!
    group1 = game_session.groups.create!(name: "Team A")
    group2 = game_session.groups.create!(name: "Team B")
    game_session.players.create!(name: "P1", group: group1)
    game_session.players.create!(name: "P2", group: group2)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)

    assert_no_difference "Submission.count" do
      post submit_word_game_session_path(game_session.code), params: { word: "hello" }
    end

    assert_response :forbidden
  end

  test "submit_word rejects duplicate submission" do
    game_session = create_game_as_host
    group1 = game_session.groups.create!(name: "Team A")
    host = game_session.players.first
    host.update!(group: group1)
    game_session.update!(status: :active, current_turn_group: group1, round_started_at: Time.current)
    message = game_session.current_message!
    message.submissions.create!(player: host, word: "first")

    assert_no_difference "Submission.count" do
      post submit_word_game_session_path(game_session.code), params: { word: "second" }
    end

    assert_response :unprocessable_entity
  end
end
