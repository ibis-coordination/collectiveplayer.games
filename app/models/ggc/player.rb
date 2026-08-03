module Ggc
  class Player < ApplicationRecord
    belongs_to :game_session
    belongs_to :group, optional: true
    has_many :submissions, dependent: :destroy

    before_create :generate_token, unless: -> { token.present? }

    validates :name, presence: true

    def host?
      token == game_session.host_token
    end

    private

    def generate_token
      self.token = SecureRandom.urlsafe_base64(32)
    end
  end
end
