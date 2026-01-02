class GameSession < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :words, dependent: :destroy
  has_many :submissions, dependent: :destroy

  enum :status, { waiting: 0, active: 1, complete: 2 }

  before_create :generate_code
  before_create :generate_host_token

  validates :code, uniqueness: true, allow_nil: true
  validates :status, presence: true

  # Characters for code generation (excluding ambiguous: 0, O, I, L, 1)
  CODE_CHARS = (('A'..'Z').to_a + ('2'..'9').to_a - ['O', 'I']).freeze

  def message
    words.order(:position).pluck(:text).join(' ')
  end

  def current_round_submissions
    submissions.where(round_number: current_round)
  end

  def all_players_submitted?
    current_round_submissions.count >= players.count
  end

  def player_submitted?(player)
    current_round_submissions.exists?(player: player)
  end

  def determine_winner
    votes = current_round_submissions.group_by { |s| s.word.downcase.strip }
    return nil if votes.empty?

    max_votes = votes.values.map(&:size).max
    winners = votes.select { |_, v| v.size == max_votes }.keys
    winners.sample # Random tie-breaker, returns the original casing from first submission
  end

  def add_winning_word!(word_text)
    return if word_text.blank?

    words.create!(position: words.count + 1, text: word_text)
    increment!(:current_round)
    update!(round_started_at: Time.current)
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
