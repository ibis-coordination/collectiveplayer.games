# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_10_060348) do
  create_table "game_sessions", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "current_turn_group_id"
    t.string "host_token", null: false
    t.datetime "round_started_at"
    t.integer "status", default: 0, null: false
    t.integer "time_limit_seconds"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_game_sessions_on_code", unique: true
    t.index ["current_turn_group_id"], name: "index_game_sessions_on_current_turn_group_id"
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_session_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["game_session_id"], name: "index_groups_on_game_session_id"
  end

  create_table "messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_session_id", null: false
    t.integer "group_id", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["game_session_id"], name: "index_messages_on_game_session_id"
    t.index ["group_id"], name: "index_messages_on_group_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_session_id", null: false
    t.integer "group_id"
    t.string "name"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["game_session_id"], name: "index_players_on_game_session_id"
    t.index ["group_id"], name: "index_players_on_group_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.string "word"
    t.index ["message_id"], name: "index_submissions_on_message_id"
    t.index ["player_id"], name: "index_submissions_on_player_id"
  end

  create_table "words", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.integer "position"
    t.string "text"
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_words_on_message_id"
  end

  add_foreign_key "game_sessions", "groups", column: "current_turn_group_id"
  add_foreign_key "groups", "game_sessions"
  add_foreign_key "messages", "game_sessions"
  add_foreign_key "messages", "groups"
  add_foreign_key "players", "game_sessions"
  add_foreign_key "players", "groups"
  add_foreign_key "submissions", "messages"
  add_foreign_key "submissions", "players"
  add_foreign_key "words", "messages"
end
