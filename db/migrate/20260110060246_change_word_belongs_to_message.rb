class ChangeWordBelongsToMessage < ActiveRecord::Migration[8.1]
  def change
    remove_reference :words, :game_session, foreign_key: true
    add_reference :words, :message, null: false, foreign_key: true
  end
end
