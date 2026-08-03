module Ggc
  class Message < ApplicationRecord
    self.table_name = "messages"

    belongs_to :game_session
    belongs_to :group
    has_many :words, dependent: :destroy
    has_many :submissions, dependent: :destroy

    def text
      words.order(:position).pluck(:text).join(" ")
    end
  end
end
