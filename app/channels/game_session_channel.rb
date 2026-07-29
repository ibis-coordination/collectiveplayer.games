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

    # Check if all group players have submitted
    if @game_session.all_group_players_submitted?
      process_round_completion
    end
  end

  private

  def find_player(token)
    @game_session.players.find_by(token: token)
  end

  def process_round_completion
    winning_word = @game_session.determine_winner
    current_message = @game_session.current_message

    # Check for END keyword
    if winning_word&.downcase == "end"
      # If message is empty (END is first word), end the entire game
      if current_message.words.empty?
        @game_session.update!(status: :complete)
        GameSessionChannel.broadcast_to(@game_session, {
          type: "game_ended",
          conversation: @game_session.conversation.map { |m| { group_name: m[:group].name, text: m[:text] } }
        })
      else
        # Message complete, switch turns
        current_group = @game_session.current_turn_group
        GameSessionChannel.broadcast_to(@game_session, {
          type: "message_completed",
          group_id: current_group.id,
          group_name: current_group.name,
          message_text: current_message.text
        })

        @game_session.switch_turn!
        @game_session.start_new_message!

        GameSessionChannel.broadcast_to(@game_session, {
          type: "turn_switched",
          active_group_id: @game_session.current_turn_group.id,
          active_group_name: @game_session.current_turn_group.name
        })
      end
    else
      @game_session.add_winning_word!(winning_word) if winning_word

      # Clear this round's submissions so players can submit the next word
      current_message.submissions.destroy_all

      GameSessionChannel.broadcast_to(@game_session, {
        type: "word_revealed",
        word: winning_word,
        group_id: @game_session.current_turn_group.id,
        message_text: current_message.reload.text
      })
    end
  end
end
