class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words do |t|
      t.references :game_session, null: false, foreign_key: true
      t.integer :position
      t.string :text

      t.timestamps
    end
  end
end
