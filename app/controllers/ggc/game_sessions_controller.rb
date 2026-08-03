module Ggc
  class GameSessionsController < ApplicationController
    before_action :set_game_session, only: [:show, :join, :join_group, :update_group_name, :start, :end_game, :submit_word]
    before_action :set_current_player, only: [:show, :join_group, :update_group_name, :start, :end_game, :submit_word]

    def new
    end

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
        # Completed games are view-only for non-players
        return if @game_session.complete?

        # Show join form if not joined yet (latecomers may join active games
        # as ungrouped spectators)
        render :join_form and return
      end
    end

    def join
      if @current_player
        redirect_to game_session_path(@game_session.code) and return
      end

      if @game_session.complete?
        redirect_to root_path, alert: "This game has finished" and return
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

    def join_group
      unless @current_player
        redirect_to game_session_path(@game_session.code), alert: "You must join the session first" and return
      end

      # In the lobby anyone can pick/switch groups. Mid-game, only ungrouped
      # spectators may join a group; grouped players are locked in.
      unless @game_session.waiting? || (@game_session.active? && @current_player.group.nil?)
        redirect_to game_session_path(@game_session.code), alert: "Groups are locked once the game starts" and return
      end

      group_id = params[:group_id]

      # Create new group or find existing
      if group_id == "new"
        if @game_session.groups.count >= 2
          redirect_to game_session_path(@game_session.code), alert: "Maximum 2 groups allowed" and return
        end
        group = @game_session.groups.create!(name: "Group #{@game_session.groups.count + 1}")
      else
        group = @game_session.groups.find_by(id: group_id)
        unless group
          redirect_to game_session_path(@game_session.code), alert: "Group not found" and return
        end
      end

      old_group = @current_player.group
      @current_player.update!(group: group)

      # Broadcast group change
      GameSessionChannel.broadcast_to(@game_session, {
        type: "player_changed_group",
        player_name: @current_player.name,
        old_group_id: old_group&.id,
        new_group_id: group.id,
        new_group_name: group.name
      })

      redirect_to game_session_path(@game_session.code)
    end

    def update_group_name
      unless @current_player
        head :unauthorized and return
      end

      group = @game_session.groups.find_by(id: params[:group_id])
      unless group
        head :not_found and return
      end

      # Only allow players in that group to rename it
      unless @current_player.group == group
        head :forbidden and return
      end

      new_name = params[:name].to_s.strip
      if new_name.blank?
        head :unprocessable_entity and return
      end

      group.update!(name: new_name)

      # Broadcast name change
      GameSessionChannel.broadcast_to(@game_session, {
        type: "group_name_changed",
        group_id: group.id,
        name: group.name
      })

      head :ok
    end

    def start
      unless @current_player&.host?
        redirect_to game_session_path(@game_session.code), alert: "Only the host can start the game" and return
      end

      if @game_session.groups.count < 2
        redirect_to game_session_path(@game_session.code), alert: "Need 2 groups to start" and return
      end

      @game_session.groups.each do |group|
        if group.players.count < 1
          redirect_to game_session_path(@game_session.code), alert: "Each group needs at least 1 player" and return
        end
      end

      # Randomly select which group goes first
      first_group = @game_session.groups.sample
      @game_session.update!(
        status: :active,
        current_turn_group: first_group,
        round_started_at: Time.current
      )

      GameSessionChannel.broadcast_to(@game_session, {
        type: "game_started",
        first_group_id: first_group.id,
        first_group_name: first_group.name
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
        conversation: @game_session.conversation.map { |m| { group_name: m[:group].name, text: m[:text] } }
      })

      redirect_to game_session_path(@game_session.code)
    end

    def submit_word
      unless @game_session.active?
        head :unprocessable_entity and return
      end

      # Only players in the active group can submit
      unless @current_player && @current_player.group == @game_session.current_turn_group
        head :forbidden and return
      end

      if @game_session.player_submitted?(@current_player)
        head :unprocessable_entity and return
      end

      word = params[:word].to_s.strip
      if word.blank?
        head :unprocessable_entity and return
      end

      @game_session.current_message!.submissions.create!(
        player: @current_player,
        word: word
      )

      # Process the round if everyone has submitted (self-guarding)
      events = @game_session.complete_round!
      events&.each { |event| GameSessionChannel.broadcast_to(@game_session, event) }

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
  end
end
