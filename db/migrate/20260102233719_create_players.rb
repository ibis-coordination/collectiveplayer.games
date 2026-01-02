class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :game_session, null: false, foreign_key: true
      t.string :name
      t.string :token

      t.timestamps
    end
  end
end
