class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    @game_session = GameSession.find_by(code: params[:code])

    if @game_session
      stream_for @game_session
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
  end

  def submit_word(data)
    @game_session.reload # Ensure we have fresh data
    return unless @game_session&.active?

    player = find_player(data["player_token"])
    return unless player

    # Only players in the active group can submit
    return unless player.group == @game_session.current_turn_group
    return if @game_session.player_submitted?(player)

    word = data["word"].to_s.strip
    return if word.blank?

    @game_session.current_message.submissions.create!(
      player: player,
      word: word
    )

    # Process the round if everyone has submitted (self-guarding)
    events = @game_session.complete_round!
    events&.each { |event| GameSessionChannel.broadcast_to(@game_session, event) }
  end

  private

  def find_player(token)
    @game_session.players.find_by(token: token)
  end
end
