require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  test "normalizes word by stripping whitespace" do
    session = Ggc::GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player", group: group)
    message = session.messages.create!(group: group, position: 1)
    submission = message.submissions.create!(player: player, word: "  hello  ")

    assert_equal "hello", submission.word
  end

  test "normalizes word by taking only first word" do
    session = Ggc::GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player", group: group)
    message = session.messages.create!(group: group, position: 1)
    submission = message.submissions.create!(player: player, word: "hello world")

    assert_equal "hello", submission.word
  end

  test "prevents duplicate submissions per player per message" do
    session = Ggc::GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player", group: group)
    message = session.messages.create!(group: group, position: 1)

    message.submissions.create!(player: player, word: "hello")
    duplicate = message.submissions.build(player: player, word: "world")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:player_id], "has already submitted for this message"
  end

  test "allows same player to submit in different messages" do
    session = Ggc::GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player", group: group)
    message1 = session.messages.create!(group: group, position: 1)
    message2 = session.messages.create!(group: group, position: 2)

    message1.submissions.create!(player: player, word: "hello")
    message2_submission = message2.submissions.create!(player: player, word: "world")

    assert message2_submission.valid?
  end
end
