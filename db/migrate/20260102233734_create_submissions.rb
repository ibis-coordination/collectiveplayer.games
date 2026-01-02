class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.references :game_session, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :round_number
      t.string :word

      t.timestamps
    end
  end
end
