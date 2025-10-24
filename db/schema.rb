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

ActiveRecord::Schema[8.0].define(version: 2025_10_20_011637) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "base_entities", force: :cascade do |t|
    t.string "entity_id", null: false
    t.string "entity_type", null: false
    t.string "name", null: false
    t.jsonb "core_data", default: {}, null: false
    t.jsonb "conditional_fragments", default: [], null: false
    t.jsonb "visibility_rules", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_base_entities_on_entity_id", unique: true
    t.index ["entity_type"], name: "index_base_entities_on_entity_type"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name"
    t.string "play_kit_id"
    t.jsonb "active_overlays"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dm_overrides", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "base_entity_id", null: false
    t.string "override_type"
    t.jsonb "override_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_entity_id"], name: "index_dm_overrides_on_base_entity_id"
    t.index ["campaign_id"], name: "index_dm_overrides_on_campaign_id"
  end

  create_table "overlays", force: :cascade do |t|
    t.string "overlay_id"
    t.string "name"
    t.string "overlay_type"
    t.jsonb "mutually_exclusive_with"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "dm_overrides", "base_entities"
  add_foreign_key "dm_overrides", "campaigns"
end
