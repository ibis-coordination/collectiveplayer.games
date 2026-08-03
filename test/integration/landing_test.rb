require "test_helper"

# `collectiveplayer.games` hosts multiple collective-player games; Group
# Group Chat is one of them and lives at /ggc. The root page
# is a plain concept explainer plus the list of playable games.
class LandingTest < ActionDispatch::IntegrationTest
  test "root page explains the concept and links to Group Group Chat" do
    get "/"

    assert_response :success
    # Concept keyword must appear so people know what they're looking at
    assert_match(/collective[- ]player/i, response.body)
    # The game list card points at /ggc
    assert_select "a[href='/ggc']", text: /Group Group Chat/i
  end

  test "root page does not host the Group Group Chat create form" do
    get "/"

    # The create-session form lives on the game's own page, not the landing
    assert_select "input[name='host_name']", count: 0
  end

  test "/ggc shows the create-session form" do
    get "/ggc"

    assert_response :success
    assert_select "input[name='host_name']"
    assert_select "form[action='#{game_sessions_path}']"
  end

  test "session share link uses the /ggc/:code URL" do
    post game_sessions_path, params: { host_name: "Alice" }
    game = Ggc::GameSession.last
    follow_redirect!

    assert_response :success
    assert_select "input#share-link" do |els|
      value = els.first["value"]
      assert_match %r{/ggc/#{game.code}\z}, value,
        "share link should end with /ggc/#{game.code}, got #{value.inspect}"
    end
  end
end
