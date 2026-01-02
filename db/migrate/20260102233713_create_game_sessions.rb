class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.string :code, null: false
      t.string :host_token, null: false
      t.integer :time_limit_seconds
      t.integer :status, default: 0, null: false
      t.integer :current_round, default: 1, null: false
      t.datetime :round_started_at

      t.timestamps
    end
    add_index :game_sessions, :code, unique: true
  end
end
