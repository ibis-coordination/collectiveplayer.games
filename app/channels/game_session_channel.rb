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
    return unless @game_session&.active?
    
    player = find_player(data["player_token"])
    return unless player
    return if @game_session.player_submitted?(player)
    
    word = data["word"].to_s.strip
    return if word.blank?
    
    @game_session.submissions.create!(
      player: player,
      round_number: @game_session.current_round,
      word: word
    )
    
    # Check if all players have submitted
    if @game_session.all_players_submitted?
      process_round_completion
    end
  end

  private

  def find_player(token)
    @game_session.players.find_by(token: token)
  end

  def process_round_completion
    winning_word = @game_session.determine_winner
    
    # Check for END keyword
    if winning_word&.downcase == "end"
      @game_session.update!(status: :complete)
      GameSessionChannel.broadcast_to(@game_session, {
        type: "game_ended",
        message: @game_session.message
      })
    else
      @game_session.add_winning_word!(winning_word) if winning_word
      
      GameSessionChannel.broadcast_to(@game_session, {
        type: "word_revealed",
        word: winning_word,
        message: @game_session.message,
        round: @game_session.current_round
      })
    end
  end
end
