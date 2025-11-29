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

ActiveRecord::Schema[8.0].define(version: 2025_11_29_134320) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "activities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "activity_type"
    t.date "date"
    t.string "title"
    t.text "description"
    t.decimal "distance"
    t.integer "duration"
    t.decimal "elevation"
    t.decimal "average_power"
    t.decimal "average_hr"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_activities_on_activity_type"
    t.index ["date"], name: "index_activities_on_date"
    t.index ["user_id", "activity_type"], name: "index_activities_on_user_id_and_activity_type"
    t.index ["user_id", "date"], name: "index_activities_on_user_id_and_date"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "trackpoints", force: :cascade do |t|
    t.bigint "track_id", null: false
    t.datetime "timestamp"
    t.float "latitude", limit: 24
    t.float "longitude", limit: 24
    t.integer "heartrate", limit: 2
    t.integer "power"
    t.integer "cadence", limit: 2
    t.float "elevation", limit: 24
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.geometry "location", limit: {:srid=>0, :type=>"geometry"}
    t.index ["location"], name: "index_trackpoints_on_location_gist", using: :gist
    t.index ["timestamp", "latitude", "longitude"], name: "index_trackpoints_on_timestamp_and_coords", where: "((latitude IS NOT NULL) AND (longitude IS NOT NULL))"
    t.index ["timestamp"], name: "index_trackpoints_on_timestamp"
    t.index ["track_id"], name: "index_trackpoints_on_track_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "polyline"
    t.index ["activity_id"], name: "index_tracks_on_activity_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "units"
    t.string "name"
    t.date "date_of_birth"
    t.decimal "height", precision: 5, scale: 2
    t.decimal "weight", precision: 5, scale: 2
    t.string "refresh_token"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["refresh_token"], name: "index_users_on_refresh_token", where: "(refresh_token IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "activities", "users"
  add_foreign_key "trackpoints", "tracks"
  add_foreign_key "tracks", "activities"
end
