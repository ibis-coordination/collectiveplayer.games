class GameSession < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :groups, dependent: :destroy
  has_many :messages, dependent: :destroy
  belongs_to :current_turn_group, class_name: 'Group', optional: true

  enum :status, { waiting: 0, active: 1, complete: 2 }

  before_create :generate_code
  before_create :generate_host_token

  validates :code, uniqueness: true, allow_nil: true
  validates :status, presence: true

  # Characters for code generation (excluding ambiguous: 0, O, I, L, 1)
  CODE_CHARS = (('A'..'Z').to_a + ('2'..'9').to_a - ['O', 'I']).freeze

  # Returns the full conversation as an array of { group:, text: } hashes
  def conversation
    messages.includes(:group, :words).order(:position).map do |msg|
      { group: msg.group, text: msg.text }
    end
  end

  # Returns the current message being composed, or nil. Read-only: use
  # current_message! from write paths that need the message to exist.
  def current_message
    return nil unless current_turn_group

    messages.where(group: current_turn_group).order(:position).last
  end

  # Find or create the message currently being composed
  def current_message!
    return nil unless current_turn_group

    current_message || messages.create!(group: current_turn_group, position: messages.count + 1)
  end

  # Check if all players in the active group have submitted for current message
  def all_group_players_submitted?
    return false unless current_turn_group && current_message

    current_message.submissions.count >= current_turn_group.players.count
  end

  # Check if a specific player has submitted for the current message
  def player_submitted?(player)
    return false unless current_message

    current_message.submissions.exists?(player: player)
  end

  # Determine the winning word from current message submissions.
  # Votes are tallied case-insensitively; the returned word keeps the
  # original casing of the first submitter of the winning spelling.
  def determine_winner
    return nil unless current_message

    votes = current_message.submissions.group_by { |s| s.word.downcase.strip }
    return nil if votes.empty?

    max_votes = votes.values.map(&:size).max
    winners = votes.values.select { |v| v.size == max_votes }
    winners.sample.first.word.strip # Random tie-breaker
  end

  # Does this word mean END? Case-insensitive, forgiving of trailing
  # punctuation ("END.", "end!").
  def end_word?(word)
    word.to_s.downcase.strip.sub(/[[:punct:]]+\z/, "") == "end"
  end

  # Add winning word to current message
  def add_winning_word!(word_text)
    return if word_text.blank?

    message = current_message!
    return if message.nil?

    message.words.create!(
      position: message.words.count + 1,
      text: word_text
    )
    update!(round_started_at: Time.current)
  end

  # Switch turn to the other group
  def switch_turn!
    other_group = groups.where.not(id: current_turn_group_id).first
    update!(current_turn_group: other_group, round_started_at: Time.current)
  end

  # Start a new message for the current group (called after END)
  def start_new_message!
    return unless current_turn_group

    messages.create!(
      group: current_turn_group,
      position: messages.count + 1
    )
    update!(round_started_at: Time.current)
  end

  # Serializes round processing within this process. Two players submitting
  # simultaneously must not both process the same round (double words /
  # double turn-switches). SQLite has no SELECT ... FOR UPDATE, so a
  # process-level mutex plus the re-check below is our guard.
  ROUND_PROCESSING_MUTEX = Mutex.new

  # Process the current round if (and only if) every player in the active
  # group has submitted. Returns an array of event hashes for the caller to
  # broadcast, or nil if there was nothing to process. Safe to call
  # repeatedly/concurrently: a second call is a no-op because the first one
  # clears the round's submissions.
  def complete_round!
    ROUND_PROCESSING_MUTEX.synchronize do
      reload
      return nil unless active? && current_turn_group

      message = current_message
      return nil if message.nil? || message.submissions.none?
      return nil unless all_group_players_submitted?

      process_round!(message)
    end
  end

  # Process an expired round (time limit reached) using whatever submissions
  # exist. If nobody submitted, the round timer resets instead. Safe to call
  # repeatedly/concurrently: processing or resetting bumps round_started_at,
  # so the round no longer counts as expired.
  def timeout_round!
    ROUND_PROCESSING_MUTEX.synchronize do
      reload
      return nil unless active? && current_turn_group && round_expired?

      message = current_message
      if message.nil? || message.submissions.none?
        # Nobody submitted: restart the round timer
        update!(round_started_at: Time.current)
        [{
          type: "round_reset",
          round_started_at: round_started_at.iso8601
        }]
      else
        process_round!(message)
      end
    end
  end

  def time_remaining
    return nil if time_limit_seconds.nil? || round_started_at.nil?

    elapsed = Time.current - round_started_at
    remaining = time_limit_seconds - elapsed
    [remaining, 0].max
  end

  def round_expired?
    return false if time_limit_seconds.nil? || round_started_at.nil?

    time_remaining <= 0
  end

  private

  # Tally the current submissions and apply the result (add word, complete
  # message, or end the game). Callers hold ROUND_PROCESSING_MUTEX and have
  # verified the round should be processed. Returns broadcast event hashes.
  def process_round!(message)
    winning_word = determine_winner

    if end_word?(winning_word)
      message.submissions.destroy_all

      if message.words.empty?
        # END as the first word ends the whole game
        update!(status: :complete)
        [{
          type: "game_ended",
          conversation: conversation.map { |m| { group_name: m[:group].name, text: m[:text] } }
        }]
      else
        # Message complete: switch turns and open a new message
        completed_event = {
          type: "message_completed",
          group_id: current_turn_group.id,
          group_name: current_turn_group.name,
          message_text: message.text
        }
        switch_turn!
        start_new_message!
        [completed_event, {
          type: "turn_switched",
          active_group_id: current_turn_group.id,
          active_group_name: current_turn_group.name
        }]
      end
    else
      add_winning_word!(winning_word) if winning_word
      # Clear this round's submissions so players can submit the next word
      message.submissions.destroy_all
      [{
        type: "word_revealed",
        word: winning_word,
        group_id: current_turn_group.id,
        message_text: message.reload.text
      }]
    end
  end

  def generate_code
    loop do
      self.code = 6.times.map { CODE_CHARS.sample }.join
      break unless GameSession.exists?(code: code)
    end
  end

  def generate_host_token
    self.host_token = SecureRandom.urlsafe_base64(32)
  end
end
