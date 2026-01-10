# frozen_string_literal: true

require_relative '../ollama_client'

namespace :game do
  desc 'Run an LLM vs LLM game of Word Ouija'
  task :llm_battle, [:players_per_group, :model] => :environment do |_t, args|
    players_per_group = (args[:players_per_group] || 1).to_i
    model = args[:model] || 'llama3.2'

    orchestrator = LLMGameOrchestrator.new(
      players_per_group: players_per_group,
      model: model
    )

    orchestrator.run
  end
end

# Orchestrates an LLM vs LLM game
class LLMGameOrchestrator
  # ANSI color codes
  COLORS = {
    reset: "\e[0m",
    bold: "\e[1m",
    dim: "\e[2m",
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    magenta: "\e[35m",
    cyan: "\e[36m"
  }.freeze

  GROUP_COLORS = [COLORS[:cyan], COLORS[:magenta]].freeze
  GROUP_NAMES = ['The Algorithms', 'Neural Network'].freeze
  PLAYER_NAMES = [
    %w[Alpha Beta Gamma Delta],
    %w[Omega Sigma Theta Lambda]
  ].freeze

  def initialize(players_per_group:, model:)
    @players_per_group = players_per_group
    @model = model
    @ollama = OllamaClient.new(model: model)
    @game_session = nil
    @groups = []
    @running = true

    # Handle Ctrl+C gracefully
    trap('INT') do
      puts "\n#{COLORS[:yellow]}Stopping game...#{COLORS[:reset]}"
      @running = false
    end
  end

  def run
    print_header
    check_ollama_availability

    setup_game
    print_game_start

    play_game

    print_final_results
  rescue OllamaClient::ConnectionError => e
    puts "#{COLORS[:red]}Error: #{e.message}#{COLORS[:reset]}"
    puts "Make sure Ollama is running: #{COLORS[:dim]}ollama serve#{COLORS[:reset]}"
    exit 1
  rescue OllamaClient::TimeoutError => e
    puts "#{COLORS[:red]}Error: #{e.message}#{COLORS[:reset]}"
    exit 1
  end

  private

  def print_header
    puts
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}╔════════════════════════════════════════╗#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}║     🔮 Word Ouija: LLM Battle 🔮       ║#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}╚════════════════════════════════════════╝#{COLORS[:reset]}"
    puts
    puts "#{COLORS[:dim]}Model: #{@model} | Players per group: #{@players_per_group}#{COLORS[:reset]}"
    puts
  end

  def check_ollama_availability
    print "Checking Ollama availability... "

    unless @ollama.available?
      puts "#{COLORS[:red]}FAILED#{COLORS[:reset]}"
      available_models = @ollama.list_models
      if available_models.any?
        puts "#{COLORS[:yellow]}Model '#{@model}' not found. Available models:#{COLORS[:reset]}"
        available_models.each { |m| puts "  - #{m}" }
      else
        puts "#{COLORS[:yellow]}Cannot connect to Ollama or no models installed.#{COLORS[:reset]}"
      end
      exit 1
    end

    puts "#{COLORS[:green]}OK#{COLORS[:reset]}"
  end

  def setup_game
    puts "Setting up game..."

    # Create game session
    @game_session = GameSession.create!

    # Create two groups
    @groups = GROUP_NAMES.map.with_index do |name, i|
      @game_session.groups.create!(name: name)
    end

    # Create players for each group
    @groups.each_with_index do |group, group_idx|
      @players_per_group.times do |player_idx|
        name = PLAYER_NAMES[group_idx][player_idx] || "Bot#{group_idx + 1}-#{player_idx + 1}"
        token = group_idx == 0 && player_idx == 0 ? @game_session.host_token : SecureRandom.urlsafe_base64(32)

        @game_session.players.create!(
          name: name,
          group: group,
          token: token
        )
      end
    end

    # Start the game
    first_group = @groups.sample
    @game_session.update!(
      status: :active,
      current_turn_group: first_group,
      round_started_at: Time.current
    )

    puts "#{COLORS[:green]}Game created: #{@game_session.code}#{COLORS[:reset]}"
  end

  def print_game_start
    puts
    puts "#{COLORS[:bold]}Game Started!#{COLORS[:reset]}"
    puts "#{COLORS[:dim]}First turn: #{group_colored_name(@game_session.current_turn_group)}#{COLORS[:reset]}"
    puts "#{COLORS[:dim]}(Press Ctrl+C to end early)#{COLORS[:reset]}"
    puts
    puts "─" * 50
  end

  def play_game
    round = 0

    while @running && @game_session.active?
      round += 1
      @game_session.reload

      current_group = @game_session.current_turn_group
      current_message = @game_session.current_message
      current_text = current_message&.text || ''

      # Print current state
      print_turn_header(current_group, current_text)

      # Get submissions from all players in current group
      submissions = collect_submissions(current_group, current_text)

      break unless @running

      # Process the round
      process_round(submissions)

      # Small delay for readability
      sleep(0.5)
    end
  end

  def print_turn_header(group, current_text)
    color = group_color(group)
    puts
    puts "#{color}#{COLORS[:bold]}#{group.name}'s turn#{COLORS[:reset]}"
    if current_text.present?
      puts "#{COLORS[:dim]}Current message: \"#{current_text}\"#{COLORS[:reset]}"
    end
  end

  def collect_submissions(group, current_text)
    submissions = []
    players = group.players.to_a

    players.each do |player|
      print "  #{player.name} thinking... "

      word = generate_word_for_player(player, current_text)
      puts "#{COLORS[:green]}\"#{word}\"#{COLORS[:reset]}"

      # Create submission
      @game_session.current_message.submissions.create!(
        player: player,
        word: word
      )

      submissions << { player: player, word: word }
    end

    submissions
  end

  def generate_word_for_player(player, current_text)
    prompt = build_prompt(player, current_text)

    begin
      response = @ollama.generate(prompt)
      @ollama.extract_word(response)
    rescue OllamaClient::Error => e
      puts "#{COLORS[:red]}Error: #{e.message}#{COLORS[:reset]}"
      'END'
    end
  end

  def build_prompt(player, current_text)
    conversation = @game_session.conversation
    other_group = @groups.find { |g| g.id != player.group_id }

    prompt = <<~PROMPT
      You are #{player.name}, playing a collaborative word game called Word Ouija.
      Your team "#{player.group.name}" is having a conversation with "#{other_group.name}".
      Each team writes messages one word at a time, with all team members voting on each word.

    PROMPT

    if conversation.any?
      prompt += "The conversation so far:\n"
      conversation.each do |msg|
        next if msg[:text].blank?
        label = msg[:group].id == player.group_id ? "Your team" : other_group.name
        prompt += "#{label}: #{msg[:text]}\n"
      end
      prompt += "\n"
    end

    if current_text.present?
      prompt += "Your team's current message so far: \"#{current_text}\"\n\n"
    else
      prompt += "You are starting a new message.\n\n"
    end

    prompt += <<~PROMPT
      Respond with ONLY a single word to add to your team's message.
      - No punctuation, no quotes, no explanation
      - Just one word
      - If you want to finish your message and send it, respond with just: END

      Your word:
    PROMPT

    prompt
  end

  def process_round(submissions)
    winning_word = @game_session.determine_winner
    current_message = @game_session.current_message
    group = @game_session.current_turn_group

    # Show voting result if multiple players
    if submissions.size > 1
      votes = submissions.group_by { |s| s[:word].downcase }
      vote_summary = votes.map { |word, subs| "#{word}(#{subs.size})" }.join(', ')
      puts "  #{COLORS[:dim]}Votes: #{vote_summary} → Winner: \"#{winning_word}\"#{COLORS[:reset]}"
    end

    if winning_word&.downcase == 'end'
      handle_end_word(current_message, group)
    else
      # Add word to message
      @game_session.add_winning_word!(winning_word) if winning_word
      puts "  #{COLORS[:bold]}Added: \"#{winning_word}\"#{COLORS[:reset]}"
    end

    # Clear submissions for next round
    current_message.submissions.destroy_all
  end

  def handle_end_word(current_message, group)
    if current_message.words.empty?
      # Game ends - first word was END
      puts "  #{COLORS[:yellow]}#{group.name} ended the conversation!#{COLORS[:reset]}"
      @game_session.update!(status: :complete)
    else
      # Message complete, switch turns
      message_text = current_message.text
      puts "  #{COLORS[:bold]}Message complete: \"#{message_text}\"#{COLORS[:reset]}"

      print_message_sent(group, message_text)

      @game_session.switch_turn!
      @game_session.start_new_message!
    end
  end

  def print_message_sent(group, text)
    color = group_color(group)
    puts
    puts "#{color}┌─────────────────────────────────────────┐#{COLORS[:reset]}"
    puts "#{color}│ #{group.name}: #{text.truncate(30).ljust(30)}│#{COLORS[:reset]}"
    puts "#{color}└─────────────────────────────────────────┘#{COLORS[:reset]}"
  end

  def print_final_results
    @game_session.reload

    puts
    puts "─" * 50
    puts
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}╔════════════════════════════════════════╗#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}║           Final Conversation           ║#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}╚════════════════════════════════════════╝#{COLORS[:reset]}"
    puts

    conversation = @game_session.conversation

    if conversation.empty? || conversation.all? { |m| m[:text].blank? }
      puts "#{COLORS[:dim]}(No messages were exchanged)#{COLORS[:reset]}"
    else
      conversation.each do |msg|
        next if msg[:text].blank?
        color = group_color(msg[:group])
        puts "#{color}#{COLORS[:bold]}#{msg[:group].name}:#{COLORS[:reset]} #{msg[:text]}"
        puts
      end
    end

    puts "─" * 50
    puts "#{COLORS[:dim]}Game code: #{@game_session.code} | Status: #{@game_session.status}#{COLORS[:reset]}"
    puts
  end

  def group_color(group)
    idx = @groups.index { |g| g.id == group.id } || 0
    GROUP_COLORS[idx]
  end

  def group_colored_name(group)
    "#{group_color(group)}#{group.name}#{COLORS[:reset]}"
  end
end
