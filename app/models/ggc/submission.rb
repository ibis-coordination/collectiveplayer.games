module Ggc
  class Submission < ApplicationRecord
    self.table_name = "submissions"

    belongs_to :message
    belongs_to :player

    validates :word, presence: true
    validates :player_id, uniqueness: { scope: :message_id, message: "has already submitted for this message" }

    before_validation :normalize_word

    private

    def normalize_word
      self.word = word.to_s.strip.split.first # Take only the first word, remove extra spaces
    end
  end
end
