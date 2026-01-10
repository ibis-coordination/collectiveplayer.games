class UpdateGameSessionForGroupChat < ActiveRecord::Migration[8.1]
  def change
    remove_column :game_sessions, :current_round, :integer
    add_reference :game_sessions, :current_turn_group, foreign_key: { to_table: :groups }, null: true
  end
end
