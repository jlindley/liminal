# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "Creating base entities..."

BaseEntity.find_or_create_by!(entity_id: "npc-bran") do |entity|
  entity.entity_type = "npc"
  entity.name = "Bran"
  entity.core_data = {
    role: "Bartender",
    race: "Human",
    description: "A weathered bartender with kind eyes"
  }
  entity.visibility_rules = {
    name: "public_when_discovered",
    description: "public_when_discovered",
    role: "public_when_discovered"
  }
end

puts "Created #{BaseEntity.count} entities"
