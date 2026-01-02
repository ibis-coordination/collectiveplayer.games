class Word < ApplicationRecord
  belongs_to :game_session

  validates :text, presence: true
  validates :position, presence: true, numericality: { greater_than: 0 }
end
