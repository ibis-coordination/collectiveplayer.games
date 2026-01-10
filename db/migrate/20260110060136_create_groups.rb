class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.references :game_session, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
