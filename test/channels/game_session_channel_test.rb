require "test_helper"

class GameSessionChannelTest < ActionCable::Channel::TestCase
  def build_active_session(time_limit: nil, round_started_at: Time.current)
    session = GameSession.create!(time_limit_seconds: time_limit)
    group1 = session.groups.create!(name: "Team A")
    group2 = session.groups.create!(name: "Team B")
    2.times { |i| session.players.create!(name: "P#{i + 1}", group: group1) }
    session.players.create!(name: "Other", group: group2)
    session.update!(status: :active, current_turn_group: group1, round_started_at: round_started_at)
    [session, group1, group2]
  end

  test "subscribes with a valid session code" do
    session, = build_active_session

    subscribe code: session.code

    assert subscription.confirmed?
  end

  test "rejects subscription for unknown code" do
    subscribe code: "NOPE99"

    assert subscription.rejected?
  end

  test "submit_word records a submission for an active group player" do
    session, group1, = build_active_session
    player = group1.players.first

    subscribe code: session.code
    perform :submit_word, { "word" => "hello", "player_token" => player.token }

    assert_equal 1, session.current_message.submissions.count
  end

  test "submit_word processes the round when all players have submitted" do
    session, group1, = build_active_session
    message = session.current_message
    message.submissions.create!(player: group1.players.first, word: "hello")

    subscribe code: session.code
    perform :submit_word, { "word" => "hello", "player_token" => group1.players.second.token }

    assert_equal "hello", message.reload.text
    assert_equal 0, message.submissions.count
  end

  test "check_timeout tallies partial submissions when the round has expired" do
    session, group1, = build_active_session(time_limit: 10, round_started_at: 1.minute.ago)
    message = session.current_message
    message.submissions.create!(player: group1.players.first, word: "hello")

    subscribe code: session.code
    perform :check_timeout

    assert_equal "hello", message.reload.text
  end

  test "check_timeout does nothing while time remains" do
    session, group1, = build_active_session(time_limit: 300)
    message = session.current_message
    message.submissions.create!(player: group1.players.first, word: "hello")

    subscribe code: session.code
    perform :check_timeout

    assert_equal "", message.reload.text
    assert_equal 1, message.submissions.count
  end
end
