require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  test "normalizes word by stripping whitespace" do
    session = GameSession.create!
    player = session.players.create!(name: "Player")
    submission = session.submissions.create!(player: player, round_number: 1, word: "  hello  ")

    assert_equal "hello", submission.word
  end

  test "normalizes word by taking only first word" do
    session = GameSession.create!
    player = session.players.create!(name: "Player")
    submission = session.submissions.create!(player: player, round_number: 1, word: "hello world")

    assert_equal "hello", submission.word
  end

  test "prevents duplicate submissions per player per round" do
    session = GameSession.create!
    player = session.players.create!(name: "Player")

    session.submissions.create!(player: player, round_number: 1, word: "hello")
    duplicate = session.submissions.build(player: player, round_number: 1, word: "world")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:player_id], "has already submitted for this round"
  end

  test "allows same player to submit in different rounds" do
    session = GameSession.create!
    player = session.players.create!(name: "Player")

    session.submissions.create!(player: player, round_number: 1, word: "hello")
    round2_submission = session.submissions.create!(player: player, round_number: 2, word: "world")

    assert round2_submission.valid?
  end
end
