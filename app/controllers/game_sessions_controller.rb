class GameSessionsController < ApplicationController
  before_action :set_game_session, only: [:show, :join, :start, :end_game, :submit_word]
  before_action :set_current_player, only: [:show, :start, :end_game, :submit_word]

  def create
    @game_session = GameSession.new(game_session_params)
    
    if @game_session.save
      # Create host player
      host_player = @game_session.players.create!(
        name: params[:host_name].presence || "Host",
        token: @game_session.host_token
      )
      
      # Store player token in session
      session[:player_tokens] ||= {}
      session[:player_tokens][@game_session.code] = host_player.token
      
      redirect_to game_session_path(@game_session.code)
    else
      redirect_to root_path, alert: "Could not create session"
    end
  end

  def show
    unless @current_player
      # Show join form if not joined yet
      render :join_form and return
    end
  end

  def join
    if @current_player
      redirect_to game_session_path(@game_session.code) and return
    end

    name = params[:name].to_s.strip
    if name.blank?
      redirect_to game_session_path(@game_session.code), alert: "Please enter your name" and return
    end

    player = @game_session.players.create!(name: name)
    
    # Store player token in session
    session[:player_tokens] ||= {}
    session[:player_tokens][@game_session.code] = player.token
    
    # Broadcast player joined
    GameSessionChannel.broadcast_to(@game_session, {
      type: "player_joined",
      player_name: player.name,
      player_count: @game_session.players.count
    })
    
    redirect_to game_session_path(@game_session.code)
  end

  def start
    unless @current_player&.host?
      redirect_to game_session_path(@game_session.code), alert: "Only the host can start the game" and return
    end

    if @game_session.players.count < 2
      redirect_to game_session_path(@game_session.code), alert: "Need at least 2 players to start" and return
    end

    @game_session.update!(status: :active, round_started_at: Time.current)
    
    GameSessionChannel.broadcast_to(@game_session, {
      type: "game_started"
    })
    
    redirect_to game_session_path(@game_session.code)
  end

  def end_game
    unless @current_player&.host?
      redirect_to game_session_path(@game_session.code), alert: "Only the host can end the game" and return
    end

    @game_session.update!(status: :complete)
    
    GameSessionChannel.broadcast_to(@game_session, {
      type: "game_ended",
      message: @game_session.message
    })
    
    redirect_to game_session_path(@game_session.code)
  end

  def submit_word
    unless @game_session.active?
      head :unprocessable_entity and return
    end

    if @game_session.player_submitted?(@current_player)
      head :unprocessable_entity and return
    end

    word = params[:word].to_s.strip
    if word.blank?
      head :unprocessable_entity and return
    end

    @game_session.submissions.create!(
      player: @current_player,
      round_number: @game_session.current_round,
      word: word
    )

    # Check if all players have submitted
    if @game_session.all_players_submitted?
      process_round_completion
    end

    head :ok
  end

  private

  def set_game_session
    @game_session = GameSession.find_by!(code: params[:code])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Session not found"
  end

  def set_current_player
    token = session.dig(:player_tokens, @game_session.code)
    @current_player = @game_session.players.find_by(token: token) if token
  end

  def game_session_params
    params.permit(:time_limit_seconds)
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
