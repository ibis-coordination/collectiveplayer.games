require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "belongs to game session and group" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    message = session.messages.create!(group: group, position: 1)

    assert_equal session, message.game_session
    assert_equal group, message.group
  end

  test "has many words" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    message = session.messages.create!(group: group, position: 1)
    message.words.create!(position: 1, text: "hello")
    message.words.create!(position: 2, text: "world")

    assert_equal 2, message.words.count
  end

  test "has many submissions" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player 1", group: group)
    message = session.messages.create!(group: group, position: 1)
    message.submissions.create!(player: player, word: "hello")

    assert_equal 1, message.submissions.count
  end

  test "text returns words joined by spaces in position order" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    message = session.messages.create!(group: group, position: 1)
    message.words.create!(position: 2, text: "world")
    message.words.create!(position: 1, text: "hello")

    assert_equal "hello world", message.text
  end

  test "text returns empty string when no words" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    message = session.messages.create!(group: group, position: 1)

    assert_equal "", message.text
  end

  test "destroys words when destroyed" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    message = session.messages.create!(group: group, position: 1)
    message.words.create!(position: 1, text: "hello")

    assert_difference "Word.count", -1 do
      message.destroy
    end
  end

  test "destroys submissions when destroyed" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player 1", group: group)
    message = session.messages.create!(group: group, position: 1)
    message.submissions.create!(player: player, word: "hello")

    assert_difference "Submission.count", -1 do
      message.destroy
    end
  end
end
