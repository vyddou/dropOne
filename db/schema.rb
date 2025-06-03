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

ActiveRecord::Schema[7.1].define(version: 2025_06_03_110410) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "comments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "conversation_participants", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_conversation_participants_on_conversation_id"
    t.index ["user_id"], name: "index_conversation_participants_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "first_user_id", null: false
    t.bigint "second_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["first_user_id", "second_user_id"], name: "index_follows_on_first_user_id_and_second_user_id", unique: true
    t.index ["first_user_id"], name: "index_follows_on_first_user_id"
    t.index ["second_user_id"], name: "index_follows_on_second_user_id"
  end

  create_table "genres", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "playlist_items", force: :cascade do |t|
    t.bigint "playlist_id", null: false
    t.bigint "track_id", null: false
    t.integer "order_in_playlist"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id"], name: "index_playlist_items_on_playlist_id"
    t.index ["track_id"], name: "index_playlist_items_on_track_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.text "description"
    t.string "type"
    t.boolean "is_public"
    t.text "ai_prompt_details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "track_id", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["track_id"], name: "index_posts_on_track_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "track_genres", force: :cascade do |t|
    t.bigint "track_id", null: false
    t.bigint "genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["genre_id"], name: "index_track_genres_on_genre_id"
    t.index ["track_id"], name: "index_track_genres_on_track_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "deezer_track_id"
    t.string "title"
    t.string "artist_name"
    t.string "album_name"
    t.integer "duration"
    t.string "preview_url"
    t.string "cover_url"
    t.string "link_deezer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_tracks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "avatar_url"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.boolean "vote_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_votes_on_post_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "conversation_participants", "conversations"
  add_foreign_key "conversation_participants", "users"
  add_foreign_key "follows", "users", column: "first_user_id"
  add_foreign_key "follows", "users", column: "second_user_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users"
  add_foreign_key "playlist_items", "playlists"
  add_foreign_key "playlist_items", "tracks"
  add_foreign_key "playlists", "users"
  add_foreign_key "posts", "tracks"
  add_foreign_key "posts", "users"
  add_foreign_key "track_genres", "genres"
  add_foreign_key "track_genres", "tracks"
  add_foreign_key "tracks", "users"
  add_foreign_key "votes", "posts"
  add_foreign_key "votes", "users"
end
