# Overlay System Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Status:** Underway (Tasks 1-12 complete, 13-19 pending)

**Goal:** Build the compositional layers overlay system for Liminal using vertical slices, starting with basic entity display and progressing to full overlay resolution with DM customizations.

**Implementation Notes:**
- Tasks 1-12 completed with code reviews and comprehensive test coverage
- Campaign model includes additional validations beyond plan: type checking, non-existent overlay rejection, duplicate prevention
- BaseEntity replacement fields include validations (replaces_must_exist, cannot_replace_self) and unique index constraint
- EntityResolver includes fix for empty required_overlays bug (uses `required.any?` check)
- All controller actions include proper error handling and N+1 query fixes

**Architecture:** Vertical slice progression - each slice delivers working end-to-end functionality. Start with minimal BaseEntity → add TOML import → add overlay resolution → add replacements → add DM overrides → add visibility filtering. Service objects handle resolution logic, models stay simple.

**Tech Stack:** Rails 8, PostgreSQL with jsonb columns, Minitest, Turbo, Tailwind CSS

---

## Slice 1: Static Entity Display

### Task 1: BaseEntity Model

**Files:**
- Create: `app/models/base_entity.rb`
- Create: `db/migrate/XXXXXX_create_base_entities.rb`
- Create: `test/models/base_entity_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/base_entity_test.rb
require "test_helper"

class BaseEntityTest < ActiveSupport::TestCase
  test "requires entity_id" do
    entity = BaseEntity.new(entity_type: "npc", name: "Bran", core_data: {})
    assert_not entity.valid?
    assert_includes entity.errors[:entity_id], "can't be blank"
  end

  test "requires entity_type" do
    entity = BaseEntity.new(entity_id: "npc-bran", name: "Bran", core_data: {})
    assert_not entity.valid?
    assert_includes entity.errors[:entity_type], "can't be blank"
  end

  test "requires unique entity_id" do
    BaseEntity.create!(entity_id: "npc-bran", entity_type: "npc", name: "Bran", core_data: {})
    duplicate = BaseEntity.new(entity_id: "npc-bran", entity_type: "npc", name: "Other", core_data: {})
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:entity_id], "has already been taken"
  end

  test "stores arbitrary JSON data in core_data" do
    entity = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: { role: "Bartender", race: "Human" }
    )
    assert_equal "Bartender", entity.core_data["role"]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/base_entity_test.rb`
Expected: FAIL with "uninitialized constant BaseEntity"

**Step 3: Create migration**

```bash
bin/rails generate migration CreateBaseEntities entity_id:string:uniq entity_type:string name:string core_data:jsonb conditional_fragments:jsonb visibility_rules:jsonb
```

Edit migration to add defaults and constraints:

```ruby
# db/migrate/XXXXXX_create_base_entities.rb
class CreateBaseEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :base_entities do |t|
      t.string :entity_id, null: false, index: { unique: true }
      t.string :entity_type, null: false
      t.string :name, null: false
      t.jsonb :core_data, null: false, default: {}
      t.jsonb :conditional_fragments, null: false, default: []
      t.jsonb :visibility_rules, null: false, default: {}

      t.timestamps
    end

    add_index :base_entities, :entity_type
  end
end
```

**Step 4: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds

**Step 5: Write minimal model**

```ruby
# app/models/base_entity.rb
class BaseEntity < ApplicationRecord
  validates :entity_id, presence: true, uniqueness: true
  validates :entity_type, presence: true
  validates :name, presence: true
end
```

**Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/base_entity_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/models/base_entity.rb db/migrate/ test/models/base_entity_test.rb db/schema.rb
git commit -m "feat: add BaseEntity model with validations"
```

### Task 2: Entities Controller and View

**Files:**
- Create: `app/controllers/entities_controller.rb`
- Create: `app/views/entities/show.html.erb`
- Create: `test/controllers/entities_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/entities_controller_test.rb
require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  test "displays entity core data" do
    entity = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {
        "role" => "Bartender",
        "race" => "Human",
        "description" => "A weathered bartender with kind eyes"
      }
    )

    get "/entities/npc-bran"

    assert_response :success
    assert_select "body", /Bran/
    assert_select "body", /Bartender/
    assert_select "body", /A weathered bartender with kind eyes/
  end

  test "returns 404 for missing entity" do
    get "/entities/npc-missing"
    assert_response :not_found
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/entities_controller_test.rb`
Expected: FAIL with "No route matches"

**Step 3: Add route**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Reveal health status on /up
  get "up" => "rails/health#show", as: :rails_health_check

  # Entities
  get "entities/:entity_id", to: "entities#show", as: :entity

  # Defines the root path route ("/")
  # root "posts#index"
end
```

**Step 4: Create controller**

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def show
    @entity = BaseEntity.find_by!(entity_id: params[:entity_id])
  rescue ActiveRecord::RecordNotFound
    render plain: "Entity not found", status: :not_found
  end
end
```

**Step 5: Create view**

```erb
<!-- app/views/entities/show.html.erb -->
<div class="max-w-4xl mx-auto p-6">
  <h1 class="text-3xl font-bold mb-4"><%= @entity.name %></h1>

  <div class="bg-white shadow rounded-lg p-6">
    <dl class="space-y-2">
      <% @entity.core_data.each do |key, value| %>
        <div>
          <dt class="font-semibold text-gray-700"><%= key.titleize %>:</dt>
          <dd class="text-gray-900"><%= value %></dd>
        </div>
      <% end %>
    </dl>
  </div>
</div>
```

**Step 6: Run test to verify it passes**

Run: `bin/rails test test/controllers/entities_controller_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/controllers/entities_controller.rb app/views/entities/show.html.erb test/controllers/entities_controller_test.rb config/routes.rb
git commit -m "feat: add entities display with basic view"
```

### Task 3: Seed Data for Manual Testing

**Files:**
- Create: `db/seeds.rb`

**Step 1: Create seed data**

```ruby
# db/seeds.rb
puts "Creating base entities..."

BaseEntity.create!(
  entity_id: "npc-bran",
  entity_type: "npc",
  name: "Bran",
  core_data: {
    role: "Bartender",
    race: "Human",
    description: "A weathered bartender with kind eyes"
  },
  visibility_rules: {
    name: "public_when_discovered",
    description: "public_when_discovered",
    role: "public_when_discovered"
  }
)

puts "Created #{BaseEntity.count} entities"
```

**Step 2: Run seeds**

Run: `bin/rails db:seed`
Expected: "Created 1 entities"

**Step 3: Manual verification**

Run: `bin/rails server`
Visit: `http://localhost:3000/entities/npc-bran`
Expected: See Bran's information displayed

**Step 4: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: add seed data for manual testing"
```

---

## Slice 2: TOML Import

### Task 4: TOML Importer Service

**Files:**
- Create: `app/services/toml_importer.rb`
- Create: `test/services/toml_importer_test.rb`
- Create: `playkits/bubble/entities/npcs/npc-bran.toml`

**Step 1: Create fixture TOML file**

```toml
# playkits/bubble/entities/npcs/npc-bran.toml
entity_id = "npc-bran"
entity_type = "npc"
name = "Bran"

[core_data]
name = "Bran"
race = "Human"
role = "Bartender"
description = "A weathered bartender with kind eyes"

[core_data.stats]
ac = 10
hp = 8

[[conditional_fragments]]
required_overlays = ["recently-bubbled"]
[conditional_fragments.data]
personality = "Skeptical of outsiders"
items = ["magical-mace"]

[[conditional_fragments]]
required_overlays = ["elemental-maelstorm"]
[conditional_fragments.data]
description = "A weathered bartender with kind eyes and a burn scar on his left cheek"
quest_hooks = ["recover-roof-materials"]

[visibility_rules]
name = "public_when_discovered"
description = "public_when_discovered"
personality = "dm_controlled"
role = "public_when_discovered"
stats = "dm_only"
quest_hooks = "dm_only"
```

**Step 2: Write the failing test**

```ruby
# test/services/toml_importer_test.rb
require "test_helper"

class TomlImporterTest < ActiveSupport::TestCase
  def setup
    @fixture_path = Rails.root.join("playkits/bubble/entities/npcs/npc-bran.toml")
  end

  test "creates BaseEntity from TOML file" do
    assert_difference "BaseEntity.count", 1 do
      TomlImporter.import_file(@fixture_path)
    end

    entity = BaseEntity.find_by(entity_id: "npc-bran")
    assert_equal "Bran", entity.name
    assert_equal "npc", entity.entity_type
    assert_equal "Bartender", entity.core_data["role"]
    assert_equal 10, entity.core_data["stats"]["ac"]
  end

  test "imports conditional_fragments" do
    TomlImporter.import_file(@fixture_path)
    entity = BaseEntity.find_by(entity_id: "npc-bran")

    assert_equal 2, entity.conditional_fragments.length

    recent_fragment = entity.conditional_fragments.find { |f| f["required_overlays"] == ["recently-bubbled"] }
    assert_equal "Skeptical of outsiders", recent_fragment["data"]["personality"]

    elemental_fragment = entity.conditional_fragments.find { |f| f["required_overlays"] == ["elemental-maelstorm"] }
    assert_equal ["recover-roof-materials"], elemental_fragment["data"]["quest_hooks"]
  end

  test "imports visibility_rules" do
    TomlImporter.import_file(@fixture_path)
    entity = BaseEntity.find_by(entity_id: "npc-bran")

    assert_equal "public_when_discovered", entity.visibility_rules["name"]
    assert_equal "dm_only", entity.visibility_rules["stats"]
  end

  test "updates existing entity on re-import" do
    TomlImporter.import_file(@fixture_path)

    assert_no_difference "BaseEntity.count" do
      TomlImporter.import_file(@fixture_path)
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bin/rails test test/services/toml_importer_test.rb`
Expected: FAIL with "uninitialized constant TomlImporter"

**Step 4: Add toml gem to Gemfile**

```ruby
# Gemfile (add this line)
gem "toml-rb"
```

Run: `bundle install`

**Step 5: Write minimal implementation**

```ruby
# app/services/toml_importer.rb
require "toml-rb"

class TomlImporter
  def self.import_file(file_path)
    data = TomlRB.load_file(file_path)

    BaseEntity.find_or_initialize_by(entity_id: data["entity_id"]).tap do |entity|
      entity.entity_type = data["entity_type"]
      entity.name = data["name"]
      entity.core_data = data["core_data"] || {}
      entity.conditional_fragments = data["conditional_fragments"] || []
      entity.visibility_rules = data["visibility_rules"] || {}
      entity.save!
    end
  end
end
```

**Step 6: Run test to verify it passes**

Run: `bin/rails test test/services/toml_importer_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add Gemfile Gemfile.lock app/services/toml_importer.rb test/services/toml_importer_test.rb playkits/
git commit -m "feat: add TOML importer service"
```

### Task 5: Rake Task for Importing

**Files:**
- Create: `lib/tasks/import.rake`

**Step 1: Create rake task**

```ruby
# lib/tasks/import.rake
namespace :playkit do
  desc "Import all TOML files from playkits directory"
  task import: :environment do
    playkit_dir = Rails.root.join("playkits")

    unless playkit_dir.exist?
      puts "No playkits directory found at #{playkit_dir}"
      exit 1
    end

    imported_count = 0
    Dir.glob(playkit_dir.join("**/*.toml")).each do |file_path|
      next if File.basename(file_path) == "overlays.toml"

      puts "Importing #{file_path}..."
      TomlImporter.import_file(file_path)
      imported_count += 1
    rescue => e
      puts "Error importing #{file_path}: #{e.message}"
    end

    puts "Imported #{imported_count} entities"
  end
end
```

**Step 2: Test rake task**

Run: `bin/rails playkit:import`
Expected: "Imported 1 entities"

**Step 3: Verify import worked**

Run: `bin/rails console`
```ruby
BaseEntity.find_by(entity_id: "npc-bran").core_data
```
Expected: Hash with Bran's data

**Step 4: Commit**

```bash
git add lib/tasks/import.rake
git commit -m "feat: add rake task for importing playkits"
```

---

## Slice 3: Overlay Resolution

### Task 6: Overlay Model

**Files:**
- Create: `app/models/overlay.rb`
- Create: `db/migrate/XXXXXX_create_overlays.rb`
- Create: `test/models/overlay_test.rb`
- Create: `playkits/bubble/overlays/overlays.toml`

**Step 1: Write the failing test**

```ruby
# test/models/overlay_test.rb
require "test_helper"

class OverlayTest < ActiveSupport::TestCase
  test "requires overlay_id" do
    overlay = Overlay.new(name: "Recently Bubbled", overlay_type: "major")
    assert_not overlay.valid?
    assert_includes overlay.errors[:overlay_id], "can't be blank"
  end

  test "requires unique overlay_id" do
    Overlay.create!(overlay_id: "recently-bubbled", name: "Recently", overlay_type: "major")
    duplicate = Overlay.new(overlay_id: "recently-bubbled", name: "Other", overlay_type: "major")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:overlay_id], "has already been taken"
  end

  test "validates overlay_type is major or flavor" do
    overlay = Overlay.new(overlay_id: "test", name: "Test", overlay_type: "invalid")
    assert_not overlay.valid?
    assert_includes overlay.errors[:overlay_type], "is not included in the list"
  end

  test "stores array of mutually exclusive overlays" do
    overlay = Overlay.create!(
      overlay_id: "recently-bubbled",
      name: "Recently Bubbled",
      overlay_type: "major",
      mutually_exclusive_with: ["100-years-bubbled"]
    )
    assert_equal ["100-years-bubbled"], overlay.mutually_exclusive_with
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/overlay_test.rb`
Expected: FAIL with "uninitialized constant Overlay"

**Step 3: Create migration**

```bash
bin/rails generate migration CreateOverlays overlay_id:string:uniq name:string overlay_type:string mutually_exclusive_with:jsonb
```

Edit migration:

```ruby
# db/migrate/XXXXXX_create_overlays.rb
class CreateOverlays < ActiveRecord::Migration[8.0]
  def change
    create_table :overlays do |t|
      t.string :overlay_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :overlay_type, null: false
      t.jsonb :mutually_exclusive_with, null: false, default: []

      t.timestamps
    end
  end
end
```

**Step 4: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds

**Step 5: Write model**

```ruby
# app/models/overlay.rb
class Overlay < ApplicationRecord
  validates :overlay_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :overlay_type, presence: true, inclusion: { in: %w[major flavor] }
end
```

**Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/overlay_test.rb`
Expected: All tests PASS

**Step 7: Create overlays TOML**

```toml
# playkits/bubble/overlays/overlays.toml

[[overlay]]
overlay_id = "recently-bubbled"
name = "Recently Bubbled"
overlay_type = "major"
mutually_exclusive_with = ["100-years-bubbled"]

[[overlay]]
overlay_id = "100-years-bubbled"
name = "100 Years Bubbled"
overlay_type = "major"
mutually_exclusive_with = ["recently-bubbled"]

[[overlay]]
overlay_id = "elemental-maelstorm"
name = "Elemental Maelstorm"
overlay_type = "flavor"
mutually_exclusive_with = []

[[overlay]]
overlay_id = "political-lockdown"
name = "Political Lockdown"
overlay_type = "flavor"
mutually_exclusive_with = []
```

**Step 8: Commit**

```bash
git add app/models/overlay.rb db/migrate/ test/models/overlay_test.rb db/schema.rb playkits/bubble/overlays/
git commit -m "feat: add Overlay model"
```

### Task 7: Update Importer for Overlays

**Files:**
- Modify: `app/services/toml_importer.rb`
- Modify: `test/services/toml_importer_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/toml_importer_test.rb (add this test)
test "imports all overlays from overlays.toml" do
  overlays_path = Rails.root.join("playkits/bubble/overlays/overlays.toml")

  assert_difference "Overlay.count", 4 do
    TomlImporter.import_overlays(overlays_path)
  end

  recently = Overlay.find_by(overlay_id: "recently-bubbled")
  assert_equal "Recently Bubbled", recently.name
  assert_equal "major", recently.overlay_type
  assert_equal ["100-years-bubbled"], recently.mutually_exclusive_with
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/toml_importer_test.rb`
Expected: FAIL with "undefined method `import_overlays'"

**Step 3: Implement import_overlays**

```ruby
# app/services/toml_importer.rb (add this method)
def self.import_overlays(file_path)
  data = TomlRB.load_file(file_path)

  data["overlay"].each do |overlay_data|
    Overlay.find_or_initialize_by(overlay_id: overlay_data["overlay_id"]).tap do |overlay|
      overlay.name = overlay_data["name"]
      overlay.overlay_type = overlay_data["overlay_type"]
      overlay.mutually_exclusive_with = overlay_data["mutually_exclusive_with"] || []
      overlay.save!
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/toml_importer_test.rb`
Expected: All tests PASS

**Step 5: Update rake task**

```ruby
# lib/tasks/import.rake (modify task)
namespace :playkit do
  desc "Import all TOML files from playkits directory"
  task import: :environment do
    playkit_dir = Rails.root.join("playkits")

    unless playkit_dir.exist?
      puts "No playkits directory found at #{playkit_dir}"
      exit 1
    end

    # Import overlays first
    overlays_file = playkit_dir.join("bubble/overlays/overlays.toml")
    if overlays_file.exist?
      puts "Importing overlays from #{overlays_file}..."
      TomlImporter.import_overlays(overlays_file)
      puts "Imported #{Overlay.count} overlays"
    end

    # Import entities
    imported_count = 0
    Dir.glob(playkit_dir.join("**/*.toml")).each do |file_path|
      next if File.basename(file_path) == "overlays.toml"

      puts "Importing #{file_path}..."
      TomlImporter.import_file(file_path)
      imported_count += 1
    rescue => e
      puts "Error importing #{file_path}: #{e.message}"
    end

    puts "Imported #{imported_count} entities"
  end
end
```

**Step 6: Test full import**

Run: `bin/rails db:reset && bin/rails playkit:import`
Expected: Overlays and entities imported

**Step 7: Commit**

```bash
git add app/services/toml_importer.rb test/services/toml_importer_test.rb lib/tasks/import.rake
git commit -m "feat: add overlay import to TomlImporter"
```

### Task 8: Campaign Model

**Files:**
- Create: `app/models/campaign.rb`
- Create: `db/migrate/XXXXXX_create_campaigns.rb`
- Create: `test/models/campaign_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/campaign_test.rb
require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  def setup
    Overlay.create!([
      { overlay_id: "recently-bubbled", name: "Recently Bubbled", overlay_type: "major", mutually_exclusive_with: ["100-years-bubbled"] },
      { overlay_id: "100-years-bubbled", name: "100 Years Bubbled", overlay_type: "major", mutually_exclusive_with: ["recently-bubbled"] },
      { overlay_id: "elemental-maelstorm", name: "Elemental Maelstorm", overlay_type: "flavor", mutually_exclusive_with: [] }
    ])
  end

  test "requires name" do
    campaign = Campaign.new(active_overlays: [])
    assert_not campaign.valid?
    assert_includes campaign.errors[:name], "can't be blank"
  end

  test "validates mutually exclusive overlays" do
    campaign = Campaign.new(
      name: "Test Campaign",
      active_overlays: ["recently-bubbled", "100-years-bubbled"]
    )
    assert_not campaign.valid?
    assert_match /mutually exclusive/, campaign.errors[:active_overlays].first
  end

  test "allows non-conflicting overlays" do
    campaign = Campaign.new(
      name: "Test Campaign",
      active_overlays: ["recently-bubbled", "elemental-maelstorm"]
    )
    assert campaign.valid?
  end

  test "allows empty active_overlays" do
    campaign = Campaign.new(name: "Test Campaign", active_overlays: [])
    assert campaign.valid?
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/campaign_test.rb`
Expected: FAIL with "uninitialized constant Campaign"

**Step 3: Create migration**

```bash
bin/rails generate migration CreateCampaigns name:string active_overlays:jsonb
```

Edit migration:

```ruby
# db/migrate/XXXXXX_create_campaigns.rb
class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.jsonb :active_overlays, null: false, default: []

      t.timestamps
    end
  end
end
```

**Step 4: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds

**Step 5: Write model with validation**

```ruby
# app/models/campaign.rb
class Campaign < ApplicationRecord
  validates :name, presence: true
  validate :validate_mutually_exclusive_overlays

  private

  def validate_mutually_exclusive_overlays
    return if active_overlays.blank?

    active_overlays.each do |overlay_id|
      overlay = Overlay.find_by(overlay_id: overlay_id)
      next unless overlay

      conflicts = overlay.mutually_exclusive_with & active_overlays
      if conflicts.any?
        errors.add(:active_overlays, "#{overlay_id} is mutually exclusive with #{conflicts.join(', ')}")
      end
    end
  end
end
```

**Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/campaign_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/models/campaign.rb db/migrate/ test/models/campaign_test.rb db/schema.rb
git commit -m "feat: add Campaign model with mutual exclusivity validation"
```

### Task 9: EntityResolver Service

**Files:**
- Create: `app/services/entity_resolver.rb`
- Create: `test/services/entity_resolver_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/entity_resolver_test.rb
require "test_helper"

class EntityResolverTest < ActiveSupport::TestCase
  def setup
    @bran = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {
        "name" => "Bran",
        "role" => "Bartender",
        "description" => "A weathered bartender with kind eyes"
      },
      conditional_fragments: [
        {
          "required_overlays" => ["recently-bubbled"],
          "data" => {
            "personality" => "Skeptical of outsiders",
            "items" => ["magical-mace"]
          }
        },
        {
          "required_overlays" => ["elemental-maelstorm"],
          "data" => {
            "description" => "A weathered bartender with kind eyes and a burn scar on his left cheek",
            "quest_hooks" => ["recover-roof-materials"]
          }
        }
      ]
    )
  end

  test "returns only core_data with no active overlays" do
    campaign = Campaign.create!(name: "Test", active_overlays: [])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_equal "Bartender", result["role"]
    assert_equal "A weathered bartender with kind eyes", result["description"]
    assert_nil result["personality"]
    assert_nil result["quest_hooks"]
  end

  test "merges matching conditional fragments with one overlay" do
    campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_equal "Skeptical of outsiders", result["personality"]
    assert_equal ["magical-mace"], result["items"]
    assert_nil result["quest_hooks"]
  end

  test "merges all matching fragments with multiple overlays" do
    campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled", "elemental-maelstorm"])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_equal "Skeptical of outsiders", result["personality"]
    assert_equal ["magical-mace"], result["items"]
    assert_equal "A weathered bartender with kind eyes and a burn scar on his left cheek", result["description"]
    assert_equal ["recover-roof-materials"], result["quest_hooks"]
  end

  test "does not merge non-matching fragments" do
    campaign = Campaign.create!(name: "Test", active_overlays: ["100-years-bubbled"])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_nil result["personality"]
    assert_nil result["items"]
  end

  test "returns nil for missing entity" do
    campaign = Campaign.create!(name: "Test", active_overlays: [])
    result = EntityResolver.resolve(entity_id: "npc-missing", campaign: campaign)
    assert_nil result
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: FAIL with "uninitialized constant EntityResolver"

**Step 3: Write minimal implementation**

```ruby
# app/services/entity_resolver.rb
class EntityResolver
  def self.resolve(entity_id:, campaign:)
    entity = BaseEntity.find_by(entity_id: entity_id)
    return nil unless entity

    # Start with core_data
    resolved = entity.core_data.deep_dup

    # Merge matching conditional fragments
    entity.conditional_fragments.each do |fragment|
      required = fragment["required_overlays"] || []
      next unless required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }

      resolved.deep_merge!(fragment["data"] || {})
    end

    resolved
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/entity_resolver.rb test/services/entity_resolver_test.rb
git commit -m "feat: add EntityResolver service for overlay resolution"
```

### Task 9.5: Add Debug Logging to EntityResolver

**Files:**
- Modify: `app/services/entity_resolver.rb`
- Modify: `test/services/entity_resolver_test.rb`

**Context:** This project has complex multi-layer data resolution. Debug logging is fundamental for understanding why entities resolve the way they do. Logs should be developer-friendly: explain WHY decisions happen, not just WHAT.

**Step 1: Write test for logging behavior**

```ruby
# test/services/entity_resolver_test.rb (add this test)
test "logs resolution steps at debug level" do
  campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled", "elemental-maelstorm"])

  Rails.logger.expects(:debug).at_least(6)

  EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/entity_resolver_test.rb -n test_logs_resolution_steps_at_debug_level`
Expected: FAIL - no logging calls

**Step 3: Add logging to EntityResolver**

```ruby
# app/services/entity_resolver.rb
class EntityResolver
  def self.resolve(entity_id:, campaign:)
    Rails.logger.debug "EntityResolver: Starting resolution for entity_id=#{entity_id}, campaign=#{campaign.name} (id=#{campaign.id})"
    Rails.logger.debug "EntityResolver: Active overlays: #{campaign.active_overlays.inspect}"

    entity = BaseEntity.find_by(entity_id: entity_id)
    unless entity
      Rails.logger.debug "EntityResolver: Entity not found for entity_id=#{entity_id}"
      return nil
    end

    Rails.logger.debug "EntityResolver: Found entity: name=#{entity.name}, type=#{entity.entity_type}"

    # Start with core_data
    resolved = entity.core_data.deep_dup
    Rails.logger.debug "EntityResolver: Starting with core_data: #{resolved.keys.inspect}"

    # Merge matching conditional fragments
    matched_count = 0
    entity.conditional_fragments.each_with_index do |fragment, idx|
      required = fragment["required_overlays"] || []

      if required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }
        Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment["data"]&.keys.inspect}"
        resolved.deep_merge!(fragment["data"] || {})
        matched_count += 1
      else
        reason = required.empty? ? "empty required_overlays" : "not all overlays active"
        Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (#{reason})"
      end
    end

    Rails.logger.debug "EntityResolver: Matched #{matched_count} fragments out of #{entity.conditional_fragments.length}"
    Rails.logger.debug "EntityResolver: Resolution complete. Final data keys: #{resolved.keys.inspect}"

    resolved
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/entity_resolver_test.rb -n test_logs_resolution_steps_at_debug_level`
Expected: All tests PASS

**Step 5: Manual verification**

Run: `bin/rails console`
```ruby
campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)
```

Check console output - should see debug logs explaining the resolution process.

**Step 6: Run full spec to ensure nothing broke**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/services/entity_resolver.rb test/services/entity_resolver_test.rb
git commit -m "feat: add debug logging to EntityResolver for troubleshooting"
```

### Task 10: Update Entities Controller for Campaigns

**Files:**
- Modify: `app/controllers/entities_controller.rb`
- Modify: `app/views/entities/show.html.erb`
- Modify: `test/controllers/entities_controller_test.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/entities_controller_test.rb (replace existing tests)
require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @bran = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {
        "name" => "Bran",
        "role" => "Bartender",
        "description" => "A weathered bartender"
      },
      conditional_fragments: [
        {
          "required_overlays" => ["recently-bubbled"],
          "data" => { "personality" => "Skeptical of outsiders" }
        }
      ]
    )
  end

  test "displays resolved entity data based on campaign overlays" do
    campaign = Campaign.create!(name: "Test Campaign", active_overlays: ["recently-bubbled"])
    get "/campaigns/#{campaign.id}/entities/npc-bran"

    assert_response :success
    assert_select "body", /Bran/
    assert_select "body", /Skeptical of outsiders/
  end

  test "returns 404 for missing entity" do
    campaign = Campaign.create!(name: "Test Campaign", active_overlays: [])
    get "/campaigns/#{campaign.id}/entities/npc-missing"
    assert_response :not_found
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/entities_controller_test.rb`
Expected: FAIL with "No route matches"

**Step 3: Update route**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :campaigns do
    get "entities/:entity_id", to: "entities#show", as: :entity
  end

  root "campaigns#index"
end
```

**Step 4: Update controller**

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def show
    @campaign = Campaign.find(params[:campaign_id])
    @resolved_data = EntityResolver.resolve(
      entity_id: params[:entity_id],
      campaign: @campaign
    )

    if @resolved_data.nil?
      render plain: "Entity not found", status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "Campaign not found", status: :not_found
  end
end
```

**Step 5: Update view**

```erb
<!-- app/views/entities/show.html.erb -->
<div class="max-w-4xl mx-auto p-6">
  <div class="mb-4">
    <a href="<%= campaign_path(@campaign) %>" class="text-blue-600 hover:underline">&larr; Back to <%= @campaign.name %></a>
  </div>

  <h1 class="text-3xl font-bold mb-4"><%= @resolved_data["name"] %></h1>

  <div class="bg-white shadow rounded-lg p-6">
    <dl class="space-y-2">
      <% @resolved_data.each do |key, value| %>
        <div>
          <dt class="font-semibold text-gray-700"><%= key.titleize %>:</dt>
          <dd class="text-gray-900"><%= value.is_a?(Array) ? value.join(", ") : value %></dd>
        </div>
      <% end %>
    </dl>
  </div>

  <div class="mt-6 text-sm text-gray-500">
    <p>Active overlays: <%= @campaign.active_overlays.join(", ").presence || "None" %></p>
  </div>
</div>
```

**Step 6: Run test to verify it passes**

Run: `bin/rails test test/controllers/entities_controller_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/controllers/entities_controller.rb app/views/entities/show.html.erb test/controllers/entities_controller_test.rb config/routes.rb
git commit -m "feat: update entities controller to use campaign-based resolution"
```

### Task 11: Campaigns Controller and Views

**Files:**
- Create: `app/controllers/campaigns_controller.rb`
- Create: `app/views/campaigns/index.html.erb`
- Create: `app/views/campaigns/show.html.erb`
- Create: `app/views/campaigns/new.html.erb`
- Create: `app/views/campaigns/_form.html.erb`
- Create: `test/controllers/campaigns_controller_test.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/campaigns_controller_test.rb
require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  def setup
    Overlay.create!([
      { overlay_id: "recently-bubbled", name: "Recently Bubbled", overlay_type: "major", mutually_exclusive_with: ["100-years-bubbled"] },
      { overlay_id: "elemental-maelstorm", name: "Elemental Maelstorm", overlay_type: "flavor", mutually_exclusive_with: [] }
    ])
  end

  test "lists all campaigns" do
    Campaign.create!(name: "Test Campaign", active_overlays: [])

    get "/campaigns"
    assert_response :success
    assert_select "body", /Test Campaign/
  end

  test "shows campaign creation form" do
    get "/campaigns/new"
    assert_response :success
    assert_select "body", /New Campaign/
  end

  test "creates a campaign with selected overlays" do
    assert_difference "Campaign.count", 1 do
      post "/campaigns", params: {
        campaign: {
          name: "My Campaign",
          active_overlays: ["recently-bubbled", "elemental-maelstorm"]
        }
      }
    end

    campaign = Campaign.last
    assert_equal "My Campaign", campaign.name
    assert_equal ["recently-bubbled", "elemental-maelstorm"], campaign.active_overlays.sort
  end

  test "rejects mutually exclusive overlays" do
    post "/campaigns", params: {
      campaign: {
        name: "Bad Campaign",
        active_overlays: ["recently-bubbled", "100-years-bubbled"]
      }
    }
    assert_response :unprocessable_entity
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/campaigns_controller_test.rb`
Expected: FAIL with "missing template campaigns/index"

**Step 3: Create controller**

```ruby
# app/controllers/campaigns_controller.rb
class CampaignsController < ApplicationController
  def index
    @campaigns = Campaign.all
  end

  def show
    @campaign = Campaign.find(params[:id])
    @entities = BaseEntity.all
  end

  def new
    @campaign = Campaign.new
    @overlays = Overlay.all.group_by(&:overlay_type)
  end

  def create
    @campaign = Campaign.new(campaign_params)

    if @campaign.save
      redirect_to @campaign, notice: "Campaign created successfully"
    else
      @overlays = Overlay.all.group_by(&:overlay_type)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def campaign_params
    params.require(:campaign).permit(:name, active_overlays: [])
  end
end
```

**Step 4: Create views**

```erb
<!-- app/views/campaigns/index.html.erb -->
<div class="max-w-4xl mx-auto p-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Campaigns</h1>
    <a href="<%= new_campaign_path %>" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">New Campaign</a>
  </div>

  <div class="space-y-4">
    <% @campaigns.each do |campaign| %>
      <div class="bg-white shadow rounded-lg p-4">
        <h2 class="text-xl font-semibold">
          <a href="<%= campaign_path(campaign) %>" class="text-blue-600 hover:underline"><%= campaign.name %></a>
        </h2>
        <p class="text-sm text-gray-600">
          Overlays: <%= campaign.active_overlays.join(", ").presence || "None" %>
        </p>
      </div>
    <% end %>

    <% if @campaigns.empty? %>
      <p class="text-gray-500">No campaigns yet. Create one to get started!</p>
    <% end %>
  </div>
</div>
```

```erb
<!-- app/views/campaigns/show.html.erb -->
<div class="max-w-4xl mx-auto p-6">
  <div class="mb-4">
    <a href="<%= campaigns_path %>" class="text-blue-600 hover:underline">&larr; Back to Campaigns</a>
  </div>

  <h1 class="text-3xl font-bold mb-4"><%= @campaign.name %></h1>

  <div class="bg-white shadow rounded-lg p-6 mb-6">
    <h2 class="text-xl font-semibold mb-2">Active Overlays</h2>
    <% if @campaign.active_overlays.any? %>
      <ul class="list-disc list-inside">
        <% @campaign.active_overlays.each do |overlay_id| %>
          <% overlay = Overlay.find_by(overlay_id: overlay_id) %>
          <li><%= overlay&.name || overlay_id %> (<%= overlay&.overlay_type %>)</li>
        <% end %>
      </ul>
    <% else %>
      <p class="text-gray-500">No overlays active</p>
    <% end %>
  </div>

  <div class="bg-white shadow rounded-lg p-6">
    <h2 class="text-xl font-semibold mb-4">Entities</h2>
    <div class="space-y-2">
      <% @entities.each do |entity| %>
        <div>
          <a href="<%= campaign_entity_path(@campaign, entity.entity_id) %>" class="text-blue-600 hover:underline">
            <%= entity.name %> (<%= entity.entity_type %>)
          </a>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

```erb
<!-- app/views/campaigns/new.html.erb -->
<div class="max-w-2xl mx-auto p-6">
  <h1 class="text-3xl font-bold mb-6">New Campaign</h1>

  <%= render "form", campaign: @campaign, overlays: @overlays %>
</div>
```

```erb
<!-- app/views/campaigns/_form.html.erb -->
<%= form_with(model: campaign, class: "space-y-6") do |f| %>
  <% if campaign.errors.any? %>
    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
      <h2 class="font-bold mb-2"><%= pluralize(campaign.errors.count, "error") %> prohibited this campaign from being saved:</h2>
      <ul class="list-disc list-inside">
        <% campaign.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :name, class: "block font-semibold mb-2" %>
    <%= f.text_field :name, class: "w-full border border-gray-300 rounded px-3 py-2" %>
  </div>

  <div>
    <label class="block font-semibold mb-2">Overlays</label>

    <% overlays.each do |type, type_overlays| %>
      <div class="mb-4">
        <h3 class="font-semibold text-gray-700 mb-2"><%= type.titleize %> Overlays</h3>
        <% type_overlays.each do |overlay| %>
          <div class="flex items-center mb-2">
            <%= check_box_tag "campaign[active_overlays][]", overlay.overlay_id,
                campaign.active_overlays.include?(overlay.overlay_id),
                id: "overlay_#{overlay.overlay_id}",
                class: "mr-2" %>
            <%= label_tag "overlay_#{overlay.overlay_id}", overlay.name %>
            <% if overlay.mutually_exclusive_with.any? %>
              <span class="ml-2 text-xs text-gray-500">(exclusive with: <%= overlay.mutually_exclusive_with.join(", ") %>)</span>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>

  <%= f.submit "Create Campaign", class: "bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600" %>
<% end %>
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/campaigns_controller_test.rb`
Expected: All tests PASS

**Step 6: Manual test**

Run: `bin/rails server`
Visit: `http://localhost:3000/campaigns`
- Create a new campaign
- Select overlays
- View campaign
- Click on an entity to see resolved data

**Step 7: Commit**

```bash
git add app/controllers/campaigns_controller.rb app/views/campaigns/ test/controllers/campaigns_controller_test.rb
git commit -m "feat: add campaigns CRUD with overlay selection"
```

---

## Slice 4: Entity Replacement

### Task 12: Add Replacement Fields to BaseEntity

**Files:**
- Create: `db/migrate/XXXXXX_add_replacement_fields_to_base_entities.rb`
- Create: `playkits/bubble/entities/npcs/npc-elena.toml`

**Step 1: Create migration**

```bash
bin/rails generate migration AddReplacementFieldsToBaseEntities replaces:string show_when:jsonb
```

Edit migration:

```ruby
# db/migrate/XXXXXX_add_replacement_fields_to_base_entities.rb
class AddReplacementFieldsToBaseEntities < ActiveRecord::Migration[8.0]
  def change
    add_column :base_entities, :replaces, :string
    add_column :base_entities, :show_when, :jsonb, default: []
  end
end
```

**Step 2: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds

**Step 3: Create Elena TOML**

```toml
# playkits/bubble/entities/npcs/npc-elena.toml
entity_id = "npc-elena"
entity_type = "npc"
name = "Elena"
replaces = "npc-bran"
show_when = ["100-years-bubbled"]

[core_data]
name = "Elena"
race = "Human"
role = "Bartender"
description = "Bran's granddaughter, young and energetic"

[core_data.stats]
ac = 12
hp = 10

[visibility_rules]
name = "public_when_discovered"
description = "public_when_discovered"
role = "public_when_discovered"
stats = "dm_only"
```

**Step 4: Update importer to handle replacement fields**

```ruby
# app/services/toml_importer.rb (modify import_file method)
def self.import_file(file_path)
  data = TomlRB.load_file(file_path)

  BaseEntity.find_or_initialize_by(entity_id: data["entity_id"]).tap do |entity|
    entity.entity_type = data["entity_type"]
    entity.name = data["name"]
    entity.core_data = data["core_data"] || {}
    entity.conditional_fragments = data["conditional_fragments"] || []
    entity.visibility_rules = data["visibility_rules"] || {}
    entity.replaces = data["replaces"]
    entity.show_when = data["show_when"] || []
    entity.save!
  end
end
```

**Step 5: Import Elena**

Run: `bin/rails playkit:import`
Expected: Elena imported

**Step 6: Commit**

```bash
git add db/migrate/ db/schema.rb app/services/toml_importer.rb playkits/bubble/entities/npcs/npc-elena.toml
git commit -m "feat: add replacement fields to BaseEntity"
```

**Step 7: Add validations and tests (IMPORTANT - data integrity)**

After code review, add these validations to prevent data integrity issues:

```ruby
# app/models/base_entity.rb
validate :replaces_must_exist, if: -> { replaces.present? }
validate :cannot_replace_self, if: -> { replaces.present? }

private

def replaces_must_exist
  unless BaseEntity.exists?(entity_id: replaces)
    errors.add(:replaces, "must reference an existing entity_id (#{replaces} not found)")
  end
end

def cannot_replace_self
  if replaces == entity_id
    errors.add(:replaces, "cannot replace itself")
  end
end
```

Create migration for unique constraint (enforces one-to-one replacement mapping):

```bash
bin/rails generate migration AddUniqueIndexToBaseEntitiesReplaces
```

```ruby
# db/migrate/XXXXXX_add_unique_index_to_base_entities_replaces.rb
class AddUniqueIndexToBaseEntitiesReplaces < ActiveRecord::Migration[8.0]
  def change
    add_index :base_entities, :replaces, unique: true, where: "replaces IS NOT NULL"
  end
end
```

Add tests to `test/models/base_entity_test.rb`:
- Test replaces field storage
- Test show_when array storage
- Test show_when defaults to empty array
- Test validation fails for non-existent replaces reference
- Test validation fails for self-replacement
- Test uniqueness constraint prevents duplicate replacements

Run: `bin/rails test test/models/base_entity_test.rb`
Expected: All tests PASS

Commit:
```bash
git add app/models/base_entity.rb db/migrate/ test/models/base_entity_test.rb db/schema.rb
git commit -m "feat: add validations and tests for replacement fields"
```

### Task 13: Update EntityResolver for Replacements

**Files:**
- Modify: `app/services/entity_resolver.rb`
- Modify: `test/services/entity_resolver_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/entity_resolver_test.rb (add these tests)
test "returns replacement entity when show_when conditions are met" do
  elena = BaseEntity.create!(
    entity_id: "npc-elena",
    entity_type: "npc",
    name: "Elena",
    replaces: "npc-bran",
    show_when: ["100-years-bubbled"],
    core_data: {
      "name" => "Elena",
      "role" => "Bartender",
      "description" => "Bran's granddaughter, young and energetic"
    }
  )

  campaign = Campaign.create!(name: "Test", active_overlays: ["100-years-bubbled"])
  result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

  assert_equal "Elena", result["name"]
  assert_equal "Bran's granddaughter, young and energetic", result["description"]
end

test "does not merge original fragments when replacement is active" do
  elena = BaseEntity.create!(
    entity_id: "npc-elena",
    entity_type: "npc",
    name: "Elena",
    replaces: "npc-bran",
    show_when: ["100-years-bubbled"],
    core_data: {
      "name" => "Elena",
      "role" => "Bartender",
      "description" => "Bran's granddaughter, young and energetic"
    }
  )

  campaign = Campaign.create!(name: "Test", active_overlays: ["100-years-bubbled"])
  result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

  assert_nil result["personality"]
  assert_nil result["items"]
end

test "returns original entity when replacement show_when conditions are not met" do
  elena = BaseEntity.create!(
    entity_id: "npc-elena",
    entity_type: "npc",
    name: "Elena",
    replaces: "npc-bran",
    show_when: ["100-years-bubbled"],
    core_data: {
      "name" => "Elena",
      "role" => "Bartender",
      "description" => "Bran's granddaughter, young and energetic"
    }
  )

  campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
  result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

  assert_equal "Bran", result["name"]
  assert_equal "Skeptical of outsiders", result["personality"]
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: FAIL - returns Bran instead of Elena

**Step 3: Update EntityResolver**

```ruby
# app/services/entity_resolver.rb
class EntityResolver
  def self.resolve(entity_id:, campaign:)
    Rails.logger.debug "EntityResolver: Starting resolution for entity_id=#{entity_id}, campaign=#{campaign.name} (id=#{campaign.id})"
    Rails.logger.debug "EntityResolver: Active overlays: #{campaign.active_overlays.inspect}"

    entity = BaseEntity.find_by(entity_id: entity_id)
    unless entity
      Rails.logger.debug "EntityResolver: Entity not found for entity_id=#{entity_id}"
      return nil
    end

    Rails.logger.debug "EntityResolver: Found entity: name=#{entity.name}, type=#{entity.entity_type}"

    # Check if another entity replaces this one
    replacement = BaseEntity.find_by(replaces: entity_id)
    if replacement
      Rails.logger.debug "EntityResolver: Found replacement entity candidate: #{replacement.entity_id} (show_when=#{replacement.show_when.inspect})"
      if replacement_active?(replacement, campaign)
        Rails.logger.debug "EntityResolver: Replacement active - using #{replacement.entity_id} instead of #{entity_id}"
        entity = replacement
      else
        Rails.logger.debug "EntityResolver: Replacement not active - continuing with original entity"
      end
    end

    # Start with core_data
    resolved = entity.core_data.deep_dup
    Rails.logger.debug "EntityResolver: Starting with core_data: #{resolved.keys.inspect}"

    # Merge matching conditional fragments (only if not a replacement)
    if entity.replaces.present?
      Rails.logger.debug "EntityResolver: Entity is a replacement - skipping conditional fragments"
    else
      matched_count = 0
      entity.conditional_fragments.each_with_index do |fragment, idx|
        required = fragment["required_overlays"] || []

        if required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }
          Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment["data"]&.keys.inspect}"
          resolved.deep_merge!(fragment["data"] || {})
          matched_count += 1
        else
          reason = required.empty? ? "empty required_overlays" : "not all overlays active"
          Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (#{reason})"
        end
      end

      Rails.logger.debug "EntityResolver: Matched #{matched_count} fragments out of #{entity.conditional_fragments.length}"
    end

    Rails.logger.debug "EntityResolver: Resolution complete. Final data keys: #{resolved.keys.inspect}"

    resolved
  end

  private

  def self.replacement_active?(entity, campaign)
    required = entity.show_when || []
    required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/entity_resolver.rb test/services/entity_resolver_test.rb
git commit -m "feat: add entity replacement logic to EntityResolver"
```

---

## Slice 5: DM Overrides

### Task 14: DmOverride Model

**Files:**
- Create: `app/models/dm_override.rb`
- Create: `db/migrate/XXXXXX_create_dm_overrides.rb`
- Create: `test/models/dm_override_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/dm_override_test.rb
require "test_helper"

class DmOverrideTest < ActiveSupport::TestCase
  def setup
    @campaign = Campaign.create!(name: "Test", active_overlays: [])
    @entity = BaseEntity.create!(entity_id: "npc-bran", entity_type: "npc", name: "Bran", core_data: {})
  end

  test "requires campaign" do
    override = DmOverride.new(base_entity: @entity, override_type: "edit", override_data: {})
    assert_not override.valid?
    assert_includes override.errors[:campaign], "must exist"
  end

  test "requires base_entity" do
    override = DmOverride.new(campaign: @campaign, override_type: "edit", override_data: {})
    assert_not override.valid?
    assert_includes override.errors[:base_entity], "must exist"
  end

  test "requires override_type" do
    override = DmOverride.new(campaign: @campaign, base_entity: @entity, override_data: {})
    assert_not override.valid?
    assert_includes override.errors[:override_type], "can't be blank"
  end

  test "validates override_type is disable, edit, or replace" do
    override = DmOverride.new(
      campaign: @campaign,
      base_entity: @entity,
      override_type: "invalid",
      override_data: {}
    )
    assert_not override.valid?
    assert_includes override.errors[:override_type], "is not included in the list"
  end

  test "allows valid override_types" do
    %w[disable edit replace].each do |type|
      override = DmOverride.new(
        campaign: @campaign,
        base_entity: @entity,
        override_type: type,
        override_data: {}
      )
      assert override.valid?
    end
  end

  test "belongs to campaign" do
    override = DmOverride.create!(
      campaign: @campaign,
      base_entity: @entity,
      override_type: "edit",
      override_data: {}
    )
    assert_equal @campaign, override.campaign
  end

  test "belongs to base_entity" do
    override = DmOverride.create!(
      campaign: @campaign,
      base_entity: @entity,
      override_type: "edit",
      override_data: {}
    )
    assert_equal @entity, override.base_entity
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/dm_override_test.rb`
Expected: FAIL with "uninitialized constant DmOverride"

**Step 3: Create migration**

```bash
bin/rails generate migration CreateDmOverrides campaign:references base_entity:references override_type:string override_data:jsonb
```

Edit migration:

```ruby
# db/migrate/XXXXXX_create_dm_overrides.rb
class CreateDmOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :dm_overrides do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :base_entity, null: false, foreign_key: true
      t.string :override_type, null: false
      t.jsonb :override_data, null: false, default: {}

      t.timestamps
    end

    add_index :dm_overrides, [:campaign_id, :base_entity_id], unique: true
  end
end
```

**Step 4: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds

**Step 5: Write model**

```ruby
# app/models/dm_override.rb
class DmOverride < ApplicationRecord
  belongs_to :campaign
  belongs_to :base_entity

  validates :override_type, presence: true, inclusion: { in: %w[disable edit replace] }
end
```

**Step 6: Add associations to Campaign**

```ruby
# app/models/campaign.rb (add this line)
has_many :dm_overrides, dependent: :destroy
```

**Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/dm_override_test.rb`
Expected: All tests PASS

**Step 8: Commit**

```bash
git add app/models/dm_override.rb app/models/campaign.rb db/migrate/ test/models/dm_override_test.rb db/schema.rb
git commit -m "feat: add DmOverride model"
```

### Task 15: Update EntityResolver for DM Overrides

**Files:**
- Modify: `app/services/entity_resolver.rb`
- Modify: `test/services/entity_resolver_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/entity_resolver_test.rb (add these tests)
test "returns nil for disabled entity" do
  campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
  DmOverride.create!(
    campaign: campaign,
    base_entity: @bran,
    override_type: "disable",
    override_data: {}
  )

  result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)
  assert_nil result
end

test "merges override data over resolved base with edit override" do
  campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
  DmOverride.create!(
    campaign: campaign,
    base_entity: @bran,
    override_type: "edit",
    override_data: {
      "description" => "A friendly bartender (DM customized)",
      "custom_note" => "Added by DM"
    }
  )

  result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

  assert_equal "Bran", result["name"]
  assert_equal "Skeptical of outsiders", result["personality"]
  assert_equal "A friendly bartender (DM customized)", result["description"]
  assert_equal "Added by DM", result["custom_note"]
end

test "uses override data entirely with replace override" do
  campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
  DmOverride.create!(
    campaign: campaign,
    base_entity: @bran,
    override_type: "replace",
    override_data: {
      "name" => "Brandon",
      "role" => "Innkeeper",
      "description" => "Completely different person"
    }
  )

  result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

  assert_equal "Brandon", result["name"]
  assert_equal "Innkeeper", result["role"]
  assert_equal "Completely different person", result["description"]
  assert_nil result["personality"]
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: FAIL - overrides not applied

**Step 3: Update EntityResolver**

```ruby
# app/services/entity_resolver.rb
class EntityResolver
  def self.resolve(entity_id:, campaign:)
    Rails.logger.debug "EntityResolver: Starting resolution for entity_id=#{entity_id}, campaign=#{campaign.name} (id=#{campaign.id})"
    Rails.logger.debug "EntityResolver: Active overlays: #{campaign.active_overlays.inspect}"

    entity = BaseEntity.find_by(entity_id: entity_id)
    unless entity
      Rails.logger.debug "EntityResolver: Entity not found for entity_id=#{entity_id}"
      return nil
    end

    Rails.logger.debug "EntityResolver: Found entity: name=#{entity.name}, type=#{entity.entity_type}"

    # Check for DM override first
    override = campaign.dm_overrides.find_by(base_entity: entity)
    if override
      Rails.logger.debug "EntityResolver: DM override found - type=#{override.override_type}"

      # Disable override returns nil immediately
      if override.override_type == "disable"
        Rails.logger.debug "EntityResolver: Entity disabled by DM - returning nil"
        return nil
      end

      # Replace override returns override_data only
      if override.override_type == "replace"
        Rails.logger.debug "EntityResolver: Entity fully replaced by DM - returning override_data (keys=#{override.override_data.keys.inspect})"
        return override.override_data.deep_dup
      end
    else
      Rails.logger.debug "EntityResolver: No DM override found"
    end

    # Check if another entity replaces this one
    replacement = BaseEntity.find_by(replaces: entity_id)
    if replacement
      Rails.logger.debug "EntityResolver: Found replacement entity candidate: #{replacement.entity_id} (show_when=#{replacement.show_when.inspect})"
      if replacement_active?(replacement, campaign)
        Rails.logger.debug "EntityResolver: Replacement active - using #{replacement.entity_id} instead of #{entity_id}"
        entity = replacement
      else
        Rails.logger.debug "EntityResolver: Replacement not active - continuing with original entity"
      end
    end

    # Start with core_data
    resolved = entity.core_data.deep_dup
    Rails.logger.debug "EntityResolver: Starting with core_data: #{resolved.keys.inspect}"

    # Merge matching conditional fragments (only if not a replacement)
    if entity.replaces.present?
      Rails.logger.debug "EntityResolver: Entity is a replacement - skipping conditional fragments"
    else
      matched_count = 0
      entity.conditional_fragments.each_with_index do |fragment, idx|
        required = fragment["required_overlays"] || []

        if required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }
          Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment["data"]&.keys.inspect}"
          resolved.deep_merge!(fragment["data"] || {})
          matched_count += 1
        else
          reason = required.empty? ? "empty required_overlays" : "not all overlays active"
          Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (#{reason})"
        end
      end

      Rails.logger.debug "EntityResolver: Matched #{matched_count} fragments out of #{entity.conditional_fragments.length}"
    end

    # Apply edit override if present
    if override&.override_type == "edit"
      Rails.logger.debug "EntityResolver: Applying DM edit override - merging keys: #{override.override_data.keys.inspect}"
      resolved.deep_merge!(override.override_data)
    end

    Rails.logger.debug "EntityResolver: Resolution complete. Final data keys: #{resolved.keys.inspect}"

    resolved
  end

  private

  def self.replacement_active?(entity, campaign)
    required = entity.show_when || []
    required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/entity_resolver_test.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/entity_resolver.rb test/services/entity_resolver_test.rb
git commit -m "feat: add DM override support to EntityResolver"
```

---

## Slice 6: Visibility Filtering

### Task 16: VisibilityFilter Service

**Files:**
- Create: `app/services/visibility_filter.rb`
- Create: `test/services/visibility_filter_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/visibility_filter_test.rb
require "test_helper"

class VisibilityFilterTest < ActiveSupport::TestCase
  def setup
    @resolved_data = {
      "name" => "Bran",
      "role" => "Bartender",
      "description" => "A weathered bartender",
      "personality" => "Skeptical of outsiders",
      "stats" => { "ac" => 10, "hp" => 8 },
      "quest_hooks" => ["recover-roof-materials"]
    }

    @visibility_rules = {
      "name" => "public_when_discovered",
      "role" => "public_when_discovered",
      "description" => "public_when_discovered",
      "personality" => "dm_controlled",
      "stats" => "dm_only",
      "quest_hooks" => "dm_only"
    }
  end

  test "returns all fields for DM" do
    result = VisibilityFilter.filter(@resolved_data, @visibility_rules, viewer_role: :dm)
    assert_equal @resolved_data.keys.sort, result.keys.sort
  end

  test "returns only public_when_discovered and dm_controlled fields for player" do
    result = VisibilityFilter.filter(@resolved_data, @visibility_rules, viewer_role: :player)

    assert_equal ["name", "role", "description", "personality"].sort, result.keys.sort
    assert_nil result["stats"]
    assert_nil result["quest_hooks"]
  end

  test "hides fields without visibility rules from player" do
    data_with_extra = @resolved_data.merge("secret_field" => "hidden")
    result = VisibilityFilter.filter(data_with_extra, @visibility_rules, viewer_role: :player)

    assert_nil result["secret_field"]
  end

  test "shows all fields to DM with nil visibility_rules" do
    result = VisibilityFilter.filter(@resolved_data, {}, viewer_role: :dm)
    assert_equal @resolved_data.keys, result.keys
  end

  test "hides all fields from player with nil visibility_rules" do
    result = VisibilityFilter.filter(@resolved_data, {}, viewer_role: :player)
    assert_equal({}, result)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/visibility_filter_test.rb`
Expected: FAIL with "uninitialized constant VisibilityFilter"

**Step 3: Write implementation**

```ruby
# app/services/visibility_filter.rb
class VisibilityFilter
  def self.filter(resolved_data, visibility_rules, viewer_role:)
    Rails.logger.debug "VisibilityFilter: Filtering for viewer_role=#{viewer_role}, data_keys=#{resolved_data.keys.inspect}"

    if viewer_role == :dm
      Rails.logger.debug "VisibilityFilter: DM view - returning all fields"
      return resolved_data
    end

    filtered = {}
    hidden_fields = []

    resolved_data.each do |key, value|
      rule = visibility_rules[key]

      if rule.nil?
        Rails.logger.debug "VisibilityFilter: Field '#{key}' has no visibility rule - hiding by default"
        hidden_fields << key
        next
      end

      # Players see public_when_discovered and dm_controlled
      if %w[public_when_discovered dm_controlled].include?(rule)
        Rails.logger.debug "VisibilityFilter: Field '#{key}' visible to player (rule=#{rule})"
        filtered[key] = value
      else
        Rails.logger.debug "VisibilityFilter: Field '#{key}' hidden from player (rule=#{rule})"
        hidden_fields << key
      end
    end

    Rails.logger.debug "VisibilityFilter: Player view - visible=#{filtered.keys.inspect}, hidden=#{hidden_fields.inspect}"

    filtered
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/visibility_filter_test.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/visibility_filter.rb test/services/visibility_filter_test.rb
git commit -m "feat: add VisibilityFilter service"
```

### Task 17: Integrate Visibility Filtering into Controller

**Files:**
- Modify: `app/controllers/entities_controller.rb`
- Modify: `test/controllers/entities_controller_test.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/entities_controller_test.rb (add these tests)
test "shows all fields to DM" do
  campaign = Campaign.create!(name: "Test", active_overlays: [])
  entity = BaseEntity.create!(
    entity_id: "npc-test",
    entity_type: "npc",
    name: "Test NPC",
    core_data: {
      "name" => "Test NPC",
      "description" => "A test character",
      "stats" => { "ac" => 10 }
    },
    visibility_rules: {
      "name" => "public_when_discovered",
      "description" => "public_when_discovered",
      "stats" => "dm_only"
    }
  )

  get "/campaigns/#{campaign.id}/entities/npc-test?view_as=dm"

  assert_response :success
  assert_select "body", /Test NPC/
  assert_select "body", /A test character/
  assert_select "body", /ac/
end

test "hides dm_only fields from player" do
  campaign = Campaign.create!(name: "Test", active_overlays: [])
  entity = BaseEntity.create!(
    entity_id: "npc-test",
    entity_type: "npc",
    name: "Test NPC",
    core_data: {
      "name" => "Test NPC",
      "description" => "A test character",
      "stats" => { "ac" => 10 }
    },
    visibility_rules: {
      "name" => "public_when_discovered",
      "description" => "public_when_discovered",
      "stats" => "dm_only"
    }
  )

  get "/campaigns/#{campaign.id}/entities/npc-test?view_as=player"

  assert_response :success
  assert_select "body", /Test NPC/
  assert_select "body", /A test character/
  # Stats should not be in the body
  assert_select "body", text: /ac/, count: 0
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/entities_controller_test.rb`
Expected: FAIL - stats still showing for player

**Step 3: Update controller**

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def show
    @campaign = Campaign.find(params[:campaign_id])
    entity = BaseEntity.find_by(entity_id: params[:entity_id])

    if entity.nil?
      render plain: "Entity not found", status: :not_found
      return
    end

    resolved = EntityResolver.resolve(entity_id: params[:entity_id], campaign: @campaign)

    if resolved.nil?
      render plain: "Entity not found", status: :not_found
      return
    end

    viewer_role = params[:view_as]&.to_sym || :dm
    @resolved_data = VisibilityFilter.filter(resolved, entity.visibility_rules, viewer_role: viewer_role)
    @viewer_role = viewer_role

  rescue ActiveRecord::RecordNotFound
    render plain: "Campaign not found", status: :not_found
  end
end
```

**Step 4: Update view to show viewer role**

```erb
<!-- app/views/entities/show.html.erb (update bottom section) -->
<div class="max-w-4xl mx-auto p-6">
  <div class="mb-4">
    <a href="<%= campaign_path(@campaign) %>" class="text-blue-600 hover:underline">&larr; Back to <%= @campaign.name %></a>
  </div>

  <h1 class="text-3xl font-bold mb-4"><%= @resolved_data["name"] %></h1>

  <div class="bg-white shadow rounded-lg p-6">
    <dl class="space-y-2">
      <% @resolved_data.each do |key, value| %>
        <div>
          <dt class="font-semibold text-gray-700"><%= key.titleize %>:</dt>
          <dd class="text-gray-900"><%= value.is_a?(Array) ? value.join(", ") : value %></dd>
        </div>
      <% end %>
    </dl>
  </div>

  <div class="mt-6 text-sm text-gray-500">
    <p>Active overlays: <%= @campaign.active_overlays.join(", ").presence || "None" %></p>
    <p>Viewing as: <%= @viewer_role.to_s.titleize %></p>
    <div class="mt-2">
      <%= link_to "View as DM", campaign_entity_path(@campaign, params[:entity_id], view_as: :dm), class: "text-blue-600 hover:underline mr-4" %>
      <%= link_to "View as Player", campaign_entity_path(@campaign, params[:entity_id], view_as: :player), class: "text-blue-600 hover:underline" %>
    </div>
  </div>
</div>
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/entities_controller_test.rb`
Expected: All tests PASS

**Step 6: Manual verification**

Run: `bin/rails server`
Visit entity page and toggle between DM/Player views
Expected: Stats hidden for player view

**Step 7: Commit**

```bash
git add app/controllers/entities_controller.rb app/views/entities/show.html.erb test/controllers/entities_controller_test.rb
git commit -m "feat: integrate visibility filtering into entities display"
```

---

## Final Integration

### Task 18: End-to-End Integration Test

**Files:**
- Create: `test/integration/overlay_system_test.rb`

**Step 1: Write comprehensive integration test**

```ruby
# test/integration/overlay_system_test.rb
require "test_helper"

class OverlaySystemTest < ActionDispatch::IntegrationTest
  def setup
    # Import all playkit data
    Rake::Task["playkit:import"].execute
  end

  test "handles full workflow: campaign creation → overlay selection → entity viewing → DM override" do
    # Step 1: Create campaign with overlays
    post "/campaigns", params: {
      campaign: {
        name: "Integration Test Campaign",
        active_overlays: ["recently-bubbled", "elemental-maelstorm"]
      }
    }
    assert_response :redirect
    follow_redirect!
    campaign = Campaign.last

    # Step 2: View entity with overlays active
    get "/campaigns/#{campaign.id}/entities/npc-bran"
    assert_response :success
    assert_select "body", /Bran/
    assert_select "body", /Skeptical of outsiders/ # from recently-bubbled
    assert_select "body", /burn scar/ # from elemental-maelstorm

    # Step 3: Create DM override
    entity = BaseEntity.find_by(entity_id: "npc-bran")
    override = DmOverride.create!(
      campaign: campaign,
      base_entity: entity,
      override_type: "edit",
      override_data: { "custom_field" => "DM added this" }
    )

    # Step 4: View entity with override
    get "/campaigns/#{campaign.id}/entities/npc-bran"
    assert_select "body", /DM added this/

    # Step 5: View as player (filtered)
    get "/campaigns/#{campaign.id}/entities/npc-bran?view_as=player"
    assert_select "body", /Bran/
    assert_select "body", text: /ac/, count: 0 # stats are dm_only
  end

  test "handles entity replacement" do
    # Create campaign with 100-years-bubbled
    campaign = Campaign.create!(
      name: "Replacement Test",
      active_overlays: ["100-years-bubbled"]
    )

    # View npc-bran (should show Elena instead)
    get "/campaigns/#{campaign.id}/entities/npc-bran"
    assert_select "body", /Elena/
    assert_select "body", /granddaughter/
    assert_select "body", text: /weathered bartender/, count: 0
  end
end
```

**Step 2: Run test to verify it passes**

Run: `bin/rails test test/integration/overlay_system_test.rb`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add test/integration/
git commit -m "test: add end-to-end integration test for overlay system"
```

### Task 19: Documentation and README

**Files:**
- Create: `README.md` (or update existing)

**Step 1: Write usage documentation**

```markdown
# Liminal - Overlay System

Campaign setting platform with dynamic overlay system for D&D content.

## Quick Start

### 1. Setup

```bash
bundle install
bin/rails db:setup
bin/rails playkit:import
bin/rails server
```

Visit `http://localhost:3000` to create your first campaign.

### 2. Importing Content

Place TOML files in `playkits/bubble/`:

- `entities/npcs/*.toml` - NPC definitions
- `entities/locations/*.toml` - Location definitions
- `overlays/overlays.toml` - Overlay definitions

Run: `bin/rails playkit:import`

### 3. Creating a Campaign

1. Go to `/campaigns/new`
2. Enter campaign name
3. Select overlays (respects mutual exclusivity)
4. Click "Create Campaign"

### 4. Viewing Entities

- Navigate to campaign page
- Click on any entity to see resolved content
- Toggle between DM/Player view to see visibility filtering

## Architecture

**Compositional Layers Resolution:**

1. Start with `core_data` (always present)
2. Merge `conditional_fragments` where overlays match
3. Apply DM overrides (disable/edit/replace)
4. Filter by visibility rules (DM vs Player)

**Models:**

- `BaseEntity` - Base content (imported from TOML)
- `Overlay` - Overlay definitions with mutual exclusivity
- `Campaign` - DM instance with active overlays
- `DmOverride` - Per-campaign customizations

**Services:**

- `TomlImporter` - Parse and import TOML files
- `EntityResolver` - Resolve entities for campaigns
- `VisibilityFilter` - Apply field-level permissions

## Testing

```bash
bin/rails test
```

## File Format

See `playkits/bubble/entities/npcs/npc-bran.toml` for example entity structure.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with quick start and architecture"
```

---

## Done!

All 6 slices complete:

1. ✅ Slice 1: Static entity display
2. ✅ Slice 2: TOML import
3. ✅ Slice 3: Overlay resolution
4. ✅ Slice 4: Entity replacement
5. ✅ Slice 5: DM overrides
6. ✅ Slice 6: Visibility filtering

The overlay system is now functional and tested. Each slice built on the previous one, delivering working software at every step.
