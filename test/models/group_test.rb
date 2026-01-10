require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "belongs to game session" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")

    assert_equal session, group.game_session
  end

  test "has many players" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player1 = session.players.create!(name: "Player 1", group: group)
    player2 = session.players.create!(name: "Player 2", group: group)

    assert_equal 2, group.players.count
    assert_includes group.players, player1
    assert_includes group.players, player2
  end

  test "has many messages" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    msg1 = session.messages.create!(group: group, position: 1)
    msg2 = session.messages.create!(group: group, position: 2)

    assert_equal 2, group.messages.count
  end

  test "validates presence of name" do
    session = GameSession.create!
    group = session.groups.build(name: nil)

    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "nullifies players when destroyed" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    player = session.players.create!(name: "Player 1", group: group)

    group.destroy

    player.reload
    assert_nil player.group_id
  end

  test "destroys messages when destroyed" do
    session = GameSession.create!
    group = session.groups.create!(name: "Team A")
    session.messages.create!(group: group, position: 1)

    assert_difference "Message.count", -1 do
      group.destroy
    end
  end
end
