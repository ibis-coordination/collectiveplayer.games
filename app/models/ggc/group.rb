module Ggc
  class Group < ApplicationRecord
    self.table_name = "groups"

    belongs_to :game_session
    has_many :players, dependent: :nullify
    has_many :messages, dependent: :destroy

    validates :name, presence: true
  end
end
