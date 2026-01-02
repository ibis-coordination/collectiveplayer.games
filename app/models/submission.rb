class Submission < ApplicationRecord
  belongs_to :game_session
  belongs_to :player

  validates :word, presence: true
  validates :round_number, presence: true, numericality: { greater_than: 0 }
  validates :player_id, uniqueness: { scope: [:game_session_id, :round_number], message: "has already submitted for this round" }

  before_validation :normalize_word

  private

  def normalize_word
    self.word = word.to_s.strip.split.first # Take only the first word, remove extra spaces
  end
end
