class NamespaceGgcTables < ActiveRecord::Migration[8.1]
  def change
    rename_table :game_sessions, :ggc_game_sessions
    rename_table :groups,        :ggc_groups
    rename_table :messages,      :ggc_messages
    rename_table :players,       :ggc_players
    rename_table :submissions,   :ggc_submissions
    rename_table :words,         :ggc_words
  end
end
