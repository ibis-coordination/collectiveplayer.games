class ChangeSubmissionBelongsToMessage < ActiveRecord::Migration[8.1]
  def change
    remove_reference :submissions, :game_session, foreign_key: true
    remove_column :submissions, :round_number, :integer
    add_reference :submissions, :message, null: false, foreign_key: true
  end
end
