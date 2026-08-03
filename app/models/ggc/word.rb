module Ggc
  class Word < ApplicationRecord
    self.table_name = "words"

    belongs_to :message

    validates :text, presence: true
    validates :position, presence: true, numericality: { greater_than: 0 }
  end
end
