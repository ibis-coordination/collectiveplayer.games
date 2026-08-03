module Ggc
  class Word < ApplicationRecord
    belongs_to :message

    validates :text, presence: true
    validates :position, presence: true, numericality: { greater_than: 0 }
  end
end
