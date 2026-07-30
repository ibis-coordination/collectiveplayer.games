require "test_helper"

# The game is called "Group Group Chat"; the working title "Word Ouija"
# must not appear anywhere players can see.
class BrandingTest < ActionDispatch::IntegrationTest
  test "home page uses the Group Group Chat name" do
    get root_path

    assert_response :success
    assert_select "title", "Group Group Chat"
    assert_select "h1", text: /Group Group Chat/
    assert_no_match(/Word Ouija/, response.body)
  end

  test "join page uses the Group Group Chat name" do
    game = GameSession.create!(status: :waiting)

    get game_session_path(game.code)

    assert_response :success
    assert_select "h1", text: /Group Group Chat/
    assert_no_match(/Word Ouija/, response.body)
  end
end
