require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "generates token on create" do
    session = GameSession.create!
    player = session.players.create!(name: "Test Player")

    assert_not_nil player.token
    assert player.token.length > 20
  end

  test "does not overwrite token if provided" do
    session = GameSession.create!
    custom_token = "my-custom-token-12345"
    player = session.players.create!(name: "Host", token: custom_token)

    assert_equal custom_token, player.token
  end

  test "host? returns true when player token matches game session host_token" do
    session = GameSession.create!
    host = session.players.create!(name: "Host", token: session.host_token)

    assert host.host?
  end

  test "host? returns false when player token does not match" do
    session = GameSession.create!
    player = session.players.create!(name: "Regular Player")

    assert_not player.host?
  end

  test "validates presence of name" do
    session = GameSession.create!
    player = session.players.build(name: nil)

    assert_not player.valid?
    assert_includes player.errors[:name], "can't be blank"
  end
end
