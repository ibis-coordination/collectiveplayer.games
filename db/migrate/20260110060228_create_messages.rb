class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :game_session, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end
  end
end
