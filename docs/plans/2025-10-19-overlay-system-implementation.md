# Overlay System Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Build the compositional layers overlay system for Liminal using vertical slices, starting with basic entity display and progressing to full overlay resolution with DM customizations.

**Architecture:** Vertical slice progression - each slice delivers working end-to-end functionality. Start with minimal BaseEntity → add TOML import → add overlay resolution → add replacements → add DM overrides → add visibility filtering. Service objects handle resolution logic, models stay simple.

**Tech Stack:** Rails 8, PostgreSQL with jsonb columns, RSpec, Turbo, Tailwind CSS

---

## Slice 1: Static Entity Display

### Task 1: BaseEntity Model

**Files:**
- Create: `app/models/base_entity.rb`
- Create: `db/migrate/XXXXXX_create_base_entities.rb`
- Create: `spec/models/base_entity_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/models/base_entity_spec.rb
require 'rails_helper'

RSpec.describe BaseEntity, type: :model do
  describe 'validations' do
    it 'requires entity_id' do
      entity = BaseEntity.new(entity_type: 'npc', name: 'Bran', core_data: {})
      expect(entity).not_to be_valid
      expect(entity.errors[:entity_id]).to include("can't be blank")
    end

    it 'requires entity_type' do
      entity = BaseEntity.new(entity_id: 'npc-bran', name: 'Bran', core_data: {})
      expect(entity).not_to be_valid
      expect(entity.errors[:entity_type]).to include("can't be blank")
    end

    it 'requires unique entity_id' do
      BaseEntity.create!(entity_id: 'npc-bran', entity_type: 'npc', name: 'Bran', core_data: {})
      duplicate = BaseEntity.new(entity_id: 'npc-bran', entity_type: 'npc', name: 'Other', core_data: {})
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:entity_id]).to include("has already been taken")
    end
  end

  describe 'core_data' do
    it 'stores arbitrary JSON data' do
      entity = BaseEntity.create!(
        entity_id: 'npc-bran',
        entity_type: 'npc',
        name: 'Bran',
        core_data: { role: 'Bartender', race: 'Human' }
      )
      expect(entity.core_data['role']).to eq('Bartender')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/base_entity_spec.rb`
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

Run: `bundle exec rspec spec/models/base_entity_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/models/base_entity.rb db/migrate/ spec/models/base_entity_spec.rb db/schema.rb
git commit -m "feat: add BaseEntity model with validations"
```

### Task 2: Entities Controller and View

**Files:**
- Create: `app/controllers/entities_controller.rb`
- Create: `app/views/entities/show.html.erb`
- Create: `spec/requests/entities_spec.rb`
- Modify: `config/routes.rb`

**Step 1: Write the failing test**

```ruby
# spec/requests/entities_spec.rb
require 'rails_helper'

RSpec.describe "Entities", type: :request do
  describe "GET /entities/:entity_id" do
    it "displays entity core data" do
      entity = BaseEntity.create!(
        entity_id: 'npc-bran',
        entity_type: 'npc',
        name: 'Bran',
        core_data: {
          role: 'Bartender',
          race: 'Human',
          description: 'A weathered bartender with kind eyes'
        }
      )

      get "/entities/npc-bran"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Bran')
      expect(response.body).to include('Bartender')
      expect(response.body).to include('A weathered bartender with kind eyes')
    end

    it "returns 404 for missing entity" do
      get "/entities/npc-missing"
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/entities_spec.rb`
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

Run: `bundle exec rspec spec/requests/entities_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/controllers/entities_controller.rb app/views/entities/show.html.erb spec/requests/entities_spec.rb config/routes.rb
git commit -m "feat: add entities display with basic view"
```

### Task 3: Seed Data for Manual Testing

**Files:**
- Create: `db/seeds.rb`

**Step 1: Create seed data**

```ruby
# db/seeds.rb
puts "Creating base entities..."

BaseEntity.create!([
  {
    entity_id: 'npc-bran',
    entity_type: 'npc',
    name: 'Bran',
    core_data: {
      role: 'Bartender',
      race: 'Human',
      description: 'A weathered bartender with kind eyes'
    },
    visibility_rules: {
      name: 'public_when_discovered',
      description: 'public_when_discovered',
      role: 'public_when_discovered'
    }
  }
])

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
- Create: `spec/services/toml_importer_spec.rb`
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
# spec/services/toml_importer_spec.rb
require 'rails_helper'

RSpec.describe TomlImporter do
  let(:fixture_path) { Rails.root.join('playkits/bubble/entities/npcs/npc-bran.toml') }

  describe '.import_file' do
    it 'creates BaseEntity from TOML file' do
      expect {
        TomlImporter.import_file(fixture_path)
      }.to change { BaseEntity.count }.by(1)

      entity = BaseEntity.find_by(entity_id: 'npc-bran')
      expect(entity.name).to eq('Bran')
      expect(entity.entity_type).to eq('npc')
      expect(entity.core_data['role']).to eq('Bartender')
      expect(entity.core_data['stats']['ac']).to eq(10)
    end

    it 'imports conditional_fragments' do
      TomlImporter.import_file(fixture_path)
      entity = BaseEntity.find_by(entity_id: 'npc-bran')

      expect(entity.conditional_fragments.length).to eq(2)

      recent_fragment = entity.conditional_fragments.find { |f| f['required_overlays'] == ['recently-bubbled'] }
      expect(recent_fragment['data']['personality']).to eq('Skeptical of outsiders')

      elemental_fragment = entity.conditional_fragments.find { |f| f['required_overlays'] == ['elemental-maelstorm'] }
      expect(elemental_fragment['data']['quest_hooks']).to eq(['recover-roof-materials'])
    end

    it 'imports visibility_rules' do
      TomlImporter.import_file(fixture_path)
      entity = BaseEntity.find_by(entity_id: 'npc-bran')

      expect(entity.visibility_rules['name']).to eq('public_when_discovered')
      expect(entity.visibility_rules['stats']).to eq('dm_only')
    end

    it 'updates existing entity on re-import' do
      TomlImporter.import_file(fixture_path)

      expect {
        TomlImporter.import_file(fixture_path)
      }.not_to change { BaseEntity.count }
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/services/toml_importer_spec.rb`
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
require 'toml-rb'

class TomlImporter
  def self.import_file(file_path)
    data = TomlRB.load_file(file_path)

    BaseEntity.find_or_initialize_by(entity_id: data['entity_id']).tap do |entity|
      entity.entity_type = data['entity_type']
      entity.name = data['name']
      entity.core_data = data['core_data'] || {}
      entity.conditional_fragments = data['conditional_fragments'] || []
      entity.visibility_rules = data['visibility_rules'] || {}
      entity.save!
    end
  end
end
```

**Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/services/toml_importer_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add Gemfile Gemfile.lock app/services/toml_importer.rb spec/services/toml_importer_spec.rb playkits/
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
    playkit_dir = Rails.root.join('playkits')

    unless playkit_dir.exist?
      puts "No playkits directory found at #{playkit_dir}"
      exit 1
    end

    imported_count = 0
    Dir.glob(playkit_dir.join('**/*.toml')).each do |file_path|
      next if File.basename(file_path) == 'overlays.toml'

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
BaseEntity.find_by(entity_id: 'npc-bran').core_data
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
- Create: `spec/models/overlay_spec.rb`
- Create: `playkits/bubble/overlays/overlays.toml`

**Step 1: Write the failing test**

```ruby
# spec/models/overlay_spec.rb
require 'rails_helper'

RSpec.describe Overlay, type: :model do
  describe 'validations' do
    it 'requires overlay_id' do
      overlay = Overlay.new(name: 'Recently Bubbled', overlay_type: 'major')
      expect(overlay).not_to be_valid
    end

    it 'requires unique overlay_id' do
      Overlay.create!(overlay_id: 'recently-bubbled', name: 'Recently', overlay_type: 'major')
      duplicate = Overlay.new(overlay_id: 'recently-bubbled', name: 'Other', overlay_type: 'major')
      expect(duplicate).not_to be_valid
    end

    it 'validates overlay_type is major or flavor' do
      overlay = Overlay.new(overlay_id: 'test', name: 'Test', overlay_type: 'invalid')
      expect(overlay).not_to be_valid
      expect(overlay.errors[:overlay_type]).to include('is not included in the list')
    end
  end

  describe 'mutual_exclusivity' do
    it 'stores array of mutually exclusive overlays' do
      overlay = Overlay.create!(
        overlay_id: 'recently-bubbled',
        name: 'Recently Bubbled',
        overlay_type: 'major',
        mutually_exclusive_with: ['100-years-bubbled']
      )
      expect(overlay.mutually_exclusive_with).to eq(['100-years-bubbled'])
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/overlay_spec.rb`
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

Run: `bundle exec rspec spec/models/overlay_spec.rb`
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
git add app/models/overlay.rb db/migrate/ spec/models/overlay_spec.rb db/schema.rb playkits/bubble/overlays/
git commit -m "feat: add Overlay model"
```

### Task 7: Update Importer for Overlays

**Files:**
- Modify: `app/services/toml_importer.rb`
- Modify: `spec/services/toml_importer_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/services/toml_importer_spec.rb (add this describe block)
describe '.import_overlays' do
  let(:overlays_path) { Rails.root.join('playkits/bubble/overlays/overlays.toml') }

  it 'imports all overlays from overlays.toml' do
    expect {
      TomlImporter.import_overlays(overlays_path)
    }.to change { Overlay.count }.by(4)

    recently = Overlay.find_by(overlay_id: 'recently-bubbled')
    expect(recently.name).to eq('Recently Bubbled')
    expect(recently.overlay_type).to eq('major')
    expect(recently.mutually_exclusive_with).to eq(['100-years-bubbled'])
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/toml_importer_spec.rb`
Expected: FAIL with "undefined method `import_overlays'"

**Step 3: Implement import_overlays**

```ruby
# app/services/toml_importer.rb (add this method)
def self.import_overlays(file_path)
  data = TomlRB.load_file(file_path)

  data['overlay'].each do |overlay_data|
    Overlay.find_or_initialize_by(overlay_id: overlay_data['overlay_id']).tap do |overlay|
      overlay.name = overlay_data['name']
      overlay.overlay_type = overlay_data['overlay_type']
      overlay.mutually_exclusive_with = overlay_data['mutually_exclusive_with'] || []
      overlay.save!
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/toml_importer_spec.rb`
Expected: All tests PASS

**Step 5: Update rake task**

```ruby
# lib/tasks/import.rake (modify task)
namespace :playkit do
  desc "Import all TOML files from playkits directory"
  task import: :environment do
    playkit_dir = Rails.root.join('playkits')

    unless playkit_dir.exist?
      puts "No playkits directory found at #{playkit_dir}"
      exit 1
    end

    # Import overlays first
    overlays_file = playkit_dir.join('bubble/overlays/overlays.toml')
    if overlays_file.exist?
      puts "Importing overlays from #{overlays_file}..."
      TomlImporter.import_overlays(overlays_file)
      puts "Imported #{Overlay.count} overlays"
    end

    # Import entities
    imported_count = 0
    Dir.glob(playkit_dir.join('**/*.toml')).each do |file_path|
      next if File.basename(file_path) == 'overlays.toml'

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
git add app/services/toml_importer.rb spec/services/toml_importer_spec.rb lib/tasks/import.rake
git commit -m "feat: add overlay import to TomlImporter"
```

### Task 8: Campaign Model

**Files:**
- Create: `app/models/campaign.rb`
- Create: `db/migrate/XXXXXX_create_campaigns.rb`
- Create: `spec/models/campaign_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/models/campaign_spec.rb
require 'rails_helper'

RSpec.describe Campaign, type: :model do
  before do
    Overlay.create!([
      { overlay_id: 'recently-bubbled', name: 'Recently Bubbled', overlay_type: 'major', mutually_exclusive_with: ['100-years-bubbled'] },
      { overlay_id: '100-years-bubbled', name: '100 Years Bubbled', overlay_type: 'major', mutually_exclusive_with: ['recently-bubbled'] },
      { overlay_id: 'elemental-maelstorm', name: 'Elemental Maelstorm', overlay_type: 'flavor', mutually_exclusive_with: [] }
    ])
  end

  describe 'validations' do
    it 'requires name' do
      campaign = Campaign.new(active_overlays: [])
      expect(campaign).not_to be_valid
      expect(campaign.errors[:name]).to include("can't be blank")
    end

    it 'validates mutually exclusive overlays' do
      campaign = Campaign.new(
        name: 'Test Campaign',
        active_overlays: ['recently-bubbled', '100-years-bubbled']
      )
      expect(campaign).not_to be_valid
      expect(campaign.errors[:active_overlays]).to include(/mutually exclusive/)
    end

    it 'allows non-conflicting overlays' do
      campaign = Campaign.new(
        name: 'Test Campaign',
        active_overlays: ['recently-bubbled', 'elemental-maelstorm']
      )
      expect(campaign).to be_valid
    end

    it 'allows empty active_overlays' do
      campaign = Campaign.new(name: 'Test Campaign', active_overlays: [])
      expect(campaign).to be_valid
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/campaign_spec.rb`
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

Run: `bundle exec rspec spec/models/campaign_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/models/campaign.rb db/migrate/ spec/models/campaign_spec.rb db/schema.rb
git commit -m "feat: add Campaign model with mutual exclusivity validation"
```

### Task 9: EntityResolver Service

**Files:**
- Create: `app/services/entity_resolver.rb`
- Create: `spec/services/entity_resolver_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/services/entity_resolver_spec.rb
require 'rails_helper'

RSpec.describe EntityResolver do
  let!(:bran) do
    BaseEntity.create!(
      entity_id: 'npc-bran',
      entity_type: 'npc',
      name: 'Bran',
      core_data: {
        'name' => 'Bran',
        'role' => 'Bartender',
        'description' => 'A weathered bartender with kind eyes'
      },
      conditional_fragments: [
        {
          'required_overlays' => ['recently-bubbled'],
          'data' => {
            'personality' => 'Skeptical of outsiders',
            'items' => ['magical-mace']
          }
        },
        {
          'required_overlays' => ['elemental-maelstorm'],
          'data' => {
            'description' => 'A weathered bartender with kind eyes and a burn scar on his left cheek',
            'quest_hooks' => ['recover-roof-materials']
          }
        }
      ]
    )
  end

  describe '.resolve' do
    context 'with no active overlays' do
      let(:campaign) { Campaign.create!(name: 'Test', active_overlays: []) }

      it 'returns only core_data' do
        result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

        expect(result['name']).to eq('Bran')
        expect(result['role']).to eq('Bartender')
        expect(result['description']).to eq('A weathered bartender with kind eyes')
        expect(result['personality']).to be_nil
        expect(result['quest_hooks']).to be_nil
      end
    end

    context 'with one matching overlay' do
      let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['recently-bubbled']) }

      it 'merges matching conditional fragments' do
        result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

        expect(result['name']).to eq('Bran')
        expect(result['personality']).to eq('Skeptical of outsiders')
        expect(result['items']).to eq(['magical-mace'])
        expect(result['quest_hooks']).to be_nil
      end
    end

    context 'with multiple matching overlays' do
      let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['recently-bubbled', 'elemental-maelstorm']) }

      it 'merges all matching fragments' do
        result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

        expect(result['name']).to eq('Bran')
        expect(result['personality']).to eq('Skeptical of outsiders')
        expect(result['items']).to eq(['magical-mace'])
        expect(result['description']).to eq('A weathered bartender with kind eyes and a burn scar on his left cheek')
        expect(result['quest_hooks']).to eq(['recover-roof-materials'])
      end
    end

    context 'with non-matching overlay' do
      let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['100-years-bubbled']) }

      it 'does not merge non-matching fragments' do
        result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

        expect(result['name']).to eq('Bran')
        expect(result['personality']).to be_nil
        expect(result['items']).to be_nil
      end
    end

    context 'with missing entity' do
      let(:campaign) { Campaign.create!(name: 'Test', active_overlays: []) }

      it 'returns nil' do
        result = EntityResolver.resolve(entity_id: 'npc-missing', campaign: campaign)
        expect(result).to be_nil
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
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
      required = fragment['required_overlays'] || []
      next unless required.all? { |overlay| campaign.active_overlays.include?(overlay) }

      resolved.deep_merge!(fragment['data'] || {})
    end

    resolved
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/entity_resolver.rb spec/services/entity_resolver_spec.rb
git commit -m "feat: add EntityResolver service for overlay resolution"
```

### Task 9.5: Add Debug Logging to EntityResolver

**Files:**
- Modify: `app/services/entity_resolver.rb`
- Modify: `spec/services/entity_resolver_spec.rb`

**Context:** This project has complex multi-layer data resolution. Debug logging is fundamental for understanding why entities resolve the way they do. Logs should be developer-friendly: explain WHY decisions happen, not just WHAT.

**Step 1: Write test for logging behavior**

```ruby
# spec/services/entity_resolver_spec.rb (add this describe block at the end)
describe 'debug logging' do
  let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['recently-bubbled', 'elemental-maelstorm']) }

  it 'logs resolution steps at debug level' do
    allow(Rails.logger).to receive(:debug)

    EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

    expect(Rails.logger).to have_received(:debug).with(/Starting resolution for entity_id=npc-bran/)
    expect(Rails.logger).to have_received(:debug).with(/Found entity: name=Bran/)
    expect(Rails.logger).to have_received(:debug).with(/Active overlays: \["recently-bubbled", "elemental-maelstorm"\]/)
    expect(Rails.logger).to have_received(:debug).with(/Fragment matched: required=\["recently-bubbled"\]/)
    expect(Rails.logger).to have_received(:debug).with(/Fragment matched: required=\["elemental-maelstorm"\]/)
    expect(Rails.logger).to have_received(:debug).with(/Resolution complete/)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb -e "debug logging"`
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
      required = fragment['required_overlays'] || []

      if required.all? { |overlay| campaign.active_overlays.include?(overlay) }
        Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment['data']&.keys.inspect}"
        resolved.deep_merge!(fragment['data'] || {})
        matched_count += 1
      else
        Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (not all active)"
      end
    end

    Rails.logger.debug "EntityResolver: Matched #{matched_count} fragments out of #{entity.conditional_fragments.length}"
    Rails.logger.debug "EntityResolver: Resolution complete. Final data keys: #{resolved.keys.inspect}"

    resolved
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb -e "debug logging"`
Expected: All tests PASS

**Step 5: Manual verification**

Run: `bin/rails console`
```ruby
campaign = Campaign.create!(name: 'Test', active_overlays: ['recently-bubbled'])
EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)
```

Check console output - should see debug logs explaining the resolution process.

**Step 6: Run full spec to ensure nothing broke**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/services/entity_resolver.rb spec/services/entity_resolver_spec.rb
git commit -m "feat: add debug logging to EntityResolver for troubleshooting"
```

### Task 10: Update Entities Controller for Campaigns

**Files:**
- Modify: `app/controllers/entities_controller.rb`
- Modify: `app/views/entities/show.html.erb`
- Modify: `spec/requests/entities_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/requests/entities_spec.rb (replace existing tests)
require 'rails_helper'

RSpec.describe "Entities", type: :request do
  let!(:bran) do
    BaseEntity.create!(
      entity_id: 'npc-bran',
      entity_type: 'npc',
      name: 'Bran',
      core_data: {
        'name' => 'Bran',
        'role' => 'Bartender',
        'description' => 'A weathered bartender'
      },
      conditional_fragments: [
        {
          'required_overlays' => ['recently-bubbled'],
          'data' => { 'personality' => 'Skeptical of outsiders' }
        }
      ]
    )
  end

  describe "GET /campaigns/:campaign_id/entities/:entity_id" do
    let(:campaign) { Campaign.create!(name: 'Test Campaign', active_overlays: ['recently-bubbled']) }

    it "displays resolved entity data based on campaign overlays" do
      get "/campaigns/#{campaign.id}/entities/npc-bran"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Bran')
      expect(response.body).to include('Skeptical of outsiders')
    end

    it "returns 404 for missing entity" do
      get "/campaigns/#{campaign.id}/entities/npc-missing"
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/entities_spec.rb`
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

  <h1 class="text-3xl font-bold mb-4"><%= @resolved_data['name'] %></h1>

  <div class="bg-white shadow rounded-lg p-6">
    <dl class="space-y-2">
      <% @resolved_data.each do |key, value| %>
        <div>
          <dt class="font-semibold text-gray-700"><%= key.titleize %>:</dt>
          <dd class="text-gray-900"><%= value.is_a?(Array) ? value.join(', ') : value %></dd>
        </div>
      <% end %>
    </dl>
  </div>

  <div class="mt-6 text-sm text-gray-500">
    <p>Active overlays: <%= @campaign.active_overlays.join(', ').presence || 'None' %></p>
  </div>
</div>
```

**Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/entities_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/controllers/entities_controller.rb app/views/entities/show.html.erb spec/requests/entities_spec.rb config/routes.rb
git commit -m "feat: update entities controller to use campaign-based resolution"
```

### Task 11: Campaigns Controller and Views

**Files:**
- Create: `app/controllers/campaigns_controller.rb`
- Create: `app/views/campaigns/index.html.erb`
- Create: `app/views/campaigns/show.html.erb`
- Create: `app/views/campaigns/new.html.erb`
- Create: `app/views/campaigns/_form.html.erb`
- Create: `spec/requests/campaigns_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/requests/campaigns_spec.rb
require 'rails_helper'

RSpec.describe "Campaigns", type: :request do
  before do
    Overlay.create!([
      { overlay_id: 'recently-bubbled', name: 'Recently Bubbled', overlay_type: 'major', mutually_exclusive_with: ['100-years-bubbled'] },
      { overlay_id: 'elemental-maelstorm', name: 'Elemental Maelstorm', overlay_type: 'flavor', mutually_exclusive_with: [] }
    ])
  end

  describe "GET /campaigns" do
    it "lists all campaigns" do
      Campaign.create!(name: 'Test Campaign', active_overlays: [])

      get "/campaigns"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test Campaign')
    end
  end

  describe "GET /campaigns/new" do
    it "shows campaign creation form" do
      get "/campaigns/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Campaign')
    end
  end

  describe "POST /campaigns" do
    it "creates a campaign with selected overlays" do
      expect {
        post "/campaigns", params: {
          campaign: {
            name: 'My Campaign',
            active_overlays: ['recently-bubbled', 'elemental-maelstorm']
          }
        }
      }.to change { Campaign.count }.by(1)

      campaign = Campaign.last
      expect(campaign.name).to eq('My Campaign')
      expect(campaign.active_overlays).to contain_exactly('recently-bubbled', 'elemental-maelstorm')
    end

    it "rejects mutually exclusive overlays" do
      post "/campaigns", params: {
        campaign: {
          name: 'Bad Campaign',
          active_overlays: ['recently-bubbled', '100-years-bubbled']
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/campaigns_spec.rb`
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
      redirect_to @campaign, notice: 'Campaign created successfully'
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
          Overlays: <%= campaign.active_overlays.join(', ').presence || 'None' %>
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

  <%= render 'form', campaign: @campaign, overlays: @overlays %>
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
            <%= check_box_tag 'campaign[active_overlays][]', overlay.overlay_id,
                campaign.active_overlays.include?(overlay.overlay_id),
                id: "overlay_#{overlay.overlay_id}",
                class: "mr-2" %>
            <%= label_tag "overlay_#{overlay.overlay_id}", overlay.name %>
            <% if overlay.mutually_exclusive_with.any? %>
              <span class="ml-2 text-xs text-gray-500">(exclusive with: <%= overlay.mutually_exclusive_with.join(', ') %>)</span>
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

Run: `bundle exec rspec spec/requests/campaigns_spec.rb`
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
git add app/controllers/campaigns_controller.rb app/views/campaigns/ spec/requests/campaigns_spec.rb
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

  BaseEntity.find_or_initialize_by(entity_id: data['entity_id']).tap do |entity|
    entity.entity_type = data['entity_type']
    entity.name = data['name']
    entity.core_data = data['core_data'] || {}
    entity.conditional_fragments = data['conditional_fragments'] || []
    entity.visibility_rules = data['visibility_rules'] || {}
    entity.replaces = data['replaces']
    entity.show_when = data['show_when'] || []
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

### Task 13: Update EntityResolver for Replacements

**Files:**
- Modify: `app/services/entity_resolver.rb`
- Modify: `spec/services/entity_resolver_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/services/entity_resolver_spec.rb (add this context)
describe 'entity replacement' do
  let!(:elena) do
    BaseEntity.create!(
      entity_id: 'npc-elena',
      entity_type: 'npc',
      name: 'Elena',
      replaces: 'npc-bran',
      show_when: ['100-years-bubbled'],
      core_data: {
        'name' => 'Elena',
        'role' => 'Bartender',
        'description' => "Bran's granddaughter, young and energetic"
      }
    )
  end

  context 'when replacement entity show_when conditions are met' do
    let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['100-years-bubbled']) }

    it 'returns replacement entity instead of original' do
      result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

      expect(result['name']).to eq('Elena')
      expect(result['description']).to eq("Bran's granddaughter, young and energetic")
    end

    it 'does not merge original fragments' do
      result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

      expect(result['personality']).to be_nil
      expect(result['items']).to be_nil
    end
  end

  context 'when replacement entity show_when conditions are not met' do
    let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['recently-bubbled']) }

    it 'returns original entity' do
      result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

      expect(result['name']).to eq('Bran')
      expect(result['personality']).to eq('Skeptical of outsiders')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
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
        required = fragment['required_overlays'] || []

        if required.all? { |overlay| campaign.active_overlays.include?(overlay) }
          Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment['data']&.keys.inspect}"
          resolved.deep_merge!(fragment['data'] || {})
          matched_count += 1
        else
          Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (not all active)"
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
    required.all? { |overlay| campaign.active_overlays.include?(overlay) }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/entity_resolver.rb spec/services/entity_resolver_spec.rb
git commit -m "feat: add entity replacement logic to EntityResolver"
```

---

## Slice 5: DM Overrides

### Task 14: DmOverride Model

**Files:**
- Create: `app/models/dm_override.rb`
- Create: `db/migrate/XXXXXX_create_dm_overrides.rb`
- Create: `spec/models/dm_override_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/models/dm_override_spec.rb
require 'rails_helper'

RSpec.describe DmOverride, type: :model do
  let(:campaign) { Campaign.create!(name: 'Test', active_overlays: []) }
  let(:entity) { BaseEntity.create!(entity_id: 'npc-bran', entity_type: 'npc', name: 'Bran', core_data: {}) }

  describe 'validations' do
    it 'requires campaign' do
      override = DmOverride.new(base_entity: entity, override_type: 'edit', override_data: {})
      expect(override).not_to be_valid
    end

    it 'requires base_entity' do
      override = DmOverride.new(campaign: campaign, override_type: 'edit', override_data: {})
      expect(override).not_to be_valid
    end

    it 'requires override_type' do
      override = DmOverride.new(campaign: campaign, base_entity: entity, override_data: {})
      expect(override).not_to be_valid
    end

    it 'validates override_type is disable, edit, or replace' do
      override = DmOverride.new(
        campaign: campaign,
        base_entity: entity,
        override_type: 'invalid',
        override_data: {}
      )
      expect(override).not_to be_valid
    end

    it 'allows valid override_types' do
      %w[disable edit replace].each do |type|
        override = DmOverride.new(
          campaign: campaign,
          base_entity: entity,
          override_type: type,
          override_data: {}
        )
        expect(override).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to campaign' do
      override = DmOverride.create!(
        campaign: campaign,
        base_entity: entity,
        override_type: 'edit',
        override_data: {}
      )
      expect(override.campaign).to eq(campaign)
    end

    it 'belongs to base_entity' do
      override = DmOverride.create!(
        campaign: campaign,
        base_entity: entity,
        override_type: 'edit',
        override_data: {}
      )
      expect(override.base_entity).to eq(entity)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/dm_override_spec.rb`
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

Run: `bundle exec rspec spec/models/dm_override_spec.rb`
Expected: All tests PASS

**Step 8: Commit**

```bash
git add app/models/dm_override.rb app/models/campaign.rb db/migrate/ spec/models/dm_override_spec.rb db/schema.rb
git commit -m "feat: add DmOverride model"
```

### Task 15: Update EntityResolver for DM Overrides

**Files:**
- Modify: `app/services/entity_resolver.rb`
- Modify: `spec/services/entity_resolver_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/services/entity_resolver_spec.rb (add this describe block)
describe 'DM overrides' do
  let(:campaign) { Campaign.create!(name: 'Test', active_overlays: ['recently-bubbled']) }

  context 'with disable override' do
    before do
      DmOverride.create!(
        campaign: campaign,
        base_entity: bran,
        override_type: 'disable',
        override_data: {}
      )
    end

    it 'returns nil for disabled entity' do
      result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)
      expect(result).to be_nil
    end
  end

  context 'with edit override' do
    before do
      DmOverride.create!(
        campaign: campaign,
        base_entity: bran,
        override_type: 'edit',
        override_data: {
          'description' => 'A friendly bartender (DM customized)',
          'custom_note' => 'Added by DM'
        }
      )
    end

    it 'merges override data over resolved base' do
      result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

      expect(result['name']).to eq('Bran')
      expect(result['personality']).to eq('Skeptical of outsiders')
      expect(result['description']).to eq('A friendly bartender (DM customized)')
      expect(result['custom_note']).to eq('Added by DM')
    end
  end

  context 'with replace override' do
    before do
      DmOverride.create!(
        campaign: campaign,
        base_entity: bran,
        override_type: 'replace',
        override_data: {
          'name' => 'Brandon',
          'role' => 'Innkeeper',
          'description' => 'Completely different person'
        }
      )
    end

    it 'uses override data entirely, ignoring base and fragments' do
      result = EntityResolver.resolve(entity_id: 'npc-bran', campaign: campaign)

      expect(result['name']).to eq('Brandon')
      expect(result['role']).to eq('Innkeeper')
      expect(result['description']).to eq('Completely different person')
      expect(result['personality']).to be_nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
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
      if override.override_type == 'disable'
        Rails.logger.debug "EntityResolver: Entity disabled by DM - returning nil"
        return nil
      end

      # Replace override returns override_data only
      if override.override_type == 'replace'
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
        required = fragment['required_overlays'] || []

        if required.all? { |overlay| campaign.active_overlays.include?(overlay) }
          Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment['data']&.keys.inspect}"
          resolved.deep_merge!(fragment['data'] || {})
          matched_count += 1
        else
          Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (not all active)"
        end
      end

      Rails.logger.debug "EntityResolver: Matched #{matched_count} fragments out of #{entity.conditional_fragments.length}"
    end

    # Apply edit override if present
    if override&.override_type == 'edit'
      Rails.logger.debug "EntityResolver: Applying DM edit override - merging keys: #{override.override_data.keys.inspect}"
      resolved.deep_merge!(override.override_data)
    end

    Rails.logger.debug "EntityResolver: Resolution complete. Final data keys: #{resolved.keys.inspect}"

    resolved
  end

  private

  def self.replacement_active?(entity, campaign)
    required = entity.show_when || []
    required.all? { |overlay| campaign.active_overlays.include?(overlay) }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/entity_resolver_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/entity_resolver.rb spec/services/entity_resolver_spec.rb
git commit -m "feat: add DM override support to EntityResolver"
```

---

## Slice 6: Visibility Filtering

### Task 16: VisibilityFilter Service

**Files:**
- Create: `app/services/visibility_filter.rb`
- Create: `spec/services/visibility_filter_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/services/visibility_filter_spec.rb
require 'rails_helper'

RSpec.describe VisibilityFilter do
  let(:resolved_data) do
    {
      'name' => 'Bran',
      'role' => 'Bartender',
      'description' => 'A weathered bartender',
      'personality' => 'Skeptical of outsiders',
      'stats' => { 'ac' => 10, 'hp' => 8 },
      'quest_hooks' => ['recover-roof-materials']
    }
  end

  let(:visibility_rules) do
    {
      'name' => 'public_when_discovered',
      'role' => 'public_when_discovered',
      'description' => 'public_when_discovered',
      'personality' => 'dm_controlled',
      'stats' => 'dm_only',
      'quest_hooks' => 'dm_only'
    }
  end

  describe '.filter' do
    context 'as DM' do
      it 'returns all fields' do
        result = VisibilityFilter.filter(resolved_data, visibility_rules, viewer_role: :dm)

        expect(result.keys).to contain_exactly('name', 'role', 'description', 'personality', 'stats', 'quest_hooks')
      end
    end

    context 'as player' do
      it 'returns only public_when_discovered and dm_controlled fields' do
        result = VisibilityFilter.filter(resolved_data, visibility_rules, viewer_role: :player)

        expect(result.keys).to contain_exactly('name', 'role', 'description', 'personality')
        expect(result['stats']).to be_nil
        expect(result['quest_hooks']).to be_nil
      end

      it 'hides fields without visibility rules' do
        data_with_extra = resolved_data.merge('secret_field' => 'hidden')
        result = VisibilityFilter.filter(data_with_extra, visibility_rules, viewer_role: :player)

        expect(result['secret_field']).to be_nil
      end
    end

    context 'with nil visibility_rules' do
      it 'shows all fields to DM' do
        result = VisibilityFilter.filter(resolved_data, {}, viewer_role: :dm)
        expect(result.keys).to eq(resolved_data.keys)
      end

      it 'hides all fields from player' do
        result = VisibilityFilter.filter(resolved_data, {}, viewer_role: :player)
        expect(result).to eq({})
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/visibility_filter_spec.rb`
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

Run: `bundle exec rspec spec/services/visibility_filter_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/visibility_filter.rb spec/services/visibility_filter_spec.rb
git commit -m "feat: add VisibilityFilter service"
```

### Task 17: Integrate Visibility Filtering into Controller

**Files:**
- Modify: `app/controllers/entities_controller.rb`
- Modify: `spec/requests/entities_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/requests/entities_spec.rb (add this describe block)
describe "visibility filtering" do
  let(:campaign) { Campaign.create!(name: 'Test', active_overlays: []) }
  let!(:entity) do
    BaseEntity.create!(
      entity_id: 'npc-test',
      entity_type: 'npc',
      name: 'Test NPC',
      core_data: {
        'name' => 'Test NPC',
        'description' => 'A test character',
        'stats' => { 'ac' => 10 }
      },
      visibility_rules: {
        'name' => 'public_when_discovered',
        'description' => 'public_when_discovered',
        'stats' => 'dm_only'
      }
    )
  end

  it "shows all fields to DM" do
    get "/campaigns/#{campaign.id}/entities/npc-test?view_as=dm"

    expect(response.body).to include('Test NPC')
    expect(response.body).to include('A test character')
    expect(response.body).to include('ac')
  end

  it "hides dm_only fields from player" do
    get "/campaigns/#{campaign.id}/entities/npc-test?view_as=player"

    expect(response.body).to include('Test NPC')
    expect(response.body).to include('A test character')
    expect(response.body).not_to include('ac')
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/entities_spec.rb`
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
<!-- app/views/entities/show.html.erb (add at bottom) -->
<div class="mt-6 text-sm text-gray-500">
  <p>Active overlays: <%= @campaign.active_overlays.join(', ').presence || 'None' %></p>
  <p>Viewing as: <%= @viewer_role.to_s.titleize %></p>
  <div class="mt-2">
    <%= link_to "View as DM", campaign_entity_path(@campaign, params[:entity_id], view_as: :dm), class: "text-blue-600 hover:underline mr-4" %>
    <%= link_to "View as Player", campaign_entity_path(@campaign, params[:entity_id], view_as: :player), class: "text-blue-600 hover:underline" %>
  </div>
</div>
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/entities_spec.rb`
Expected: All tests PASS

**Step 6: Manual verification**

Run: `bin/rails server`
Visit entity page and toggle between DM/Player views
Expected: Stats hidden for player view

**Step 7: Commit**

```bash
git add app/controllers/entities_controller.rb app/views/entities/show.html.erb spec/requests/entities_spec.rb
git commit -m "feat: integrate visibility filtering into entities display"
```

---

## Final Integration

### Task 18: End-to-End Integration Test

**Files:**
- Create: `spec/integration/overlay_system_spec.rb`

**Step 1: Write comprehensive integration test**

```ruby
# spec/integration/overlay_system_spec.rb
require 'rails_helper'

RSpec.describe 'Overlay System Integration', type: :request do
  before do
    # Import all playkit data
    Rake::Task['playkit:import'].execute
  end

  it 'handles full workflow: campaign creation → overlay selection → entity viewing → DM override' do
    # Step 1: Create campaign with overlays
    post '/campaigns', params: {
      campaign: {
        name: 'Integration Test Campaign',
        active_overlays: ['recently-bubbled', 'elemental-maelstorm']
      }
    }
    expect(response).to redirect_to(assigns(:campaign))
    campaign = Campaign.last

    # Step 2: View entity with overlays active
    get "/campaigns/#{campaign.id}/entities/npc-bran"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Bran')
    expect(response.body).to include('Skeptical of outsiders') # from recently-bubbled
    expect(response.body).to include('burn scar') # from elemental-maelstorm

    # Step 3: Create DM override
    entity = BaseEntity.find_by(entity_id: 'npc-bran')
    override = DmOverride.create!(
      campaign: campaign,
      base_entity: entity,
      override_type: 'edit',
      override_data: { 'custom_field' => 'DM added this' }
    )

    # Step 4: View entity with override
    get "/campaigns/#{campaign.id}/entities/npc-bran"
    expect(response.body).to include('DM added this')

    # Step 5: View as player (filtered)
    get "/campaigns/#{campaign.id}/entities/npc-bran?view_as=player"
    expect(response.body).to include('Bran')
    expect(response.body).not_to include('ac') # stats are dm_only
  end

  it 'handles entity replacement' do
    # Create campaign with 100-years-bubbled
    campaign = Campaign.create!(
      name: 'Replacement Test',
      active_overlays: ['100-years-bubbled']
    )

    # View npc-bran (should show Elena instead)
    get "/campaigns/#{campaign.id}/entities/npc-bran"
    expect(response.body).to include('Elena')
    expect(response.body).to include('granddaughter')
    expect(response.body).not_to include('weathered bartender')
  end
end
```

**Step 2: Run test to verify it passes**

Run: `bundle exec rspec spec/integration/overlay_system_spec.rb`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add spec/integration/
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
bundle exec rspec
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
