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

  test "defaults to round 1" do
    session = GameSession.create!

    assert_equal 1, session.current_round
  end

  test "message returns words joined by spaces in position order" do
    session = GameSession.create!
    session.words.create!(position: 2, text: "world")
    session.words.create!(position: 1, text: "hello")

    assert_equal "hello world", session.message
  end

  test "message returns empty string when no words" do
    session = GameSession.create!

    assert_equal "", session.message
  end

  test "all_players_submitted? returns true when all players have submitted" do
    session = GameSession.create!
    player1 = session.players.create!(name: "Player 1")
    player2 = session.players.create!(name: "Player 2")

    session.submissions.create!(player: player1, round_number: 1, word: "hello")
    session.submissions.create!(player: player2, round_number: 1, word: "world")

    assert session.all_players_submitted?
  end

  test "all_players_submitted? returns false when not all players have submitted" do
    session = GameSession.create!
    player1 = session.players.create!(name: "Player 1")
    player2 = session.players.create!(name: "Player 2")

    session.submissions.create!(player: player1, round_number: 1, word: "hello")

    assert_not session.all_players_submitted?
  end

  test "player_submitted? returns true for player who submitted current round" do
    session = GameSession.create!
    player = session.players.create!(name: "Player 1")
    session.submissions.create!(player: player, round_number: 1, word: "hello")

    assert session.player_submitted?(player)
  end

  test "player_submitted? returns false for player who has not submitted current round" do
    session = GameSession.create!
    player = session.players.create!(name: "Player 1")

    assert_not session.player_submitted?(player)
  end

  test "player_submitted? checks current round not previous rounds" do
    session = GameSession.create!
    player = session.players.create!(name: "Player 1")

    # Submit for round 1
    session.submissions.create!(player: player, round_number: 1, word: "hello")

    # Advance to round 2
    session.update!(current_round: 2)

    # Player has not submitted for round 2 yet
    assert_not session.player_submitted?(player)
  end

  test "determine_winner returns word with most votes (case-insensitive)" do
    session = GameSession.create!
    player1 = session.players.create!(name: "Player 1")
    player2 = session.players.create!(name: "Player 2")
    player3 = session.players.create!(name: "Player 3")

    session.submissions.create!(player: player1, round_number: 1, word: "Hello")
    session.submissions.create!(player: player2, round_number: 1, word: "hello")
    session.submissions.create!(player: player3, round_number: 1, word: "world")

    # "hello" has 2 votes, "world" has 1
    assert_equal "hello", session.determine_winner
  end

  test "determine_winner breaks ties randomly" do
    session = GameSession.create!
    player1 = session.players.create!(name: "Player 1")
    player2 = session.players.create!(name: "Player 2")

    session.submissions.create!(player: player1, round_number: 1, word: "hello")
    session.submissions.create!(player: player2, round_number: 1, word: "world")

    # Both have 1 vote, should return one of them
    winner = session.determine_winner
    assert_includes ["hello", "world"], winner
  end

  test "add_winning_word! creates word and increments round" do
    session = GameSession.create!(round_started_at: Time.current)

    session.add_winning_word!("hello")

    assert_equal 1, session.words.count
    assert_equal "hello", session.words.first.text
    assert_equal 1, session.words.first.position
    assert_equal 2, session.current_round
  end

  test "add_winning_word! sets correct position for subsequent words" do
    session = GameSession.create!(round_started_at: Time.current)

    session.add_winning_word!("hello")
    session.add_winning_word!("world")

    assert_equal 2, session.words.count
    assert_equal 2, session.words.find_by(text: "world").position
  end
end
