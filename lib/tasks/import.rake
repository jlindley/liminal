namespace :playkit do
  desc "Import all TOML files from playkits directory"
  task import: :environment do
    playkit_dir = Rails.root.join("playkits")

    unless playkit_dir.exist?
      puts "No playkits directory found at #{playkit_dir}"
      exit 1
    end

    imported_count = 0
    error_count = 0

    puts "Importing TOML files from #{playkit_dir}..."
    puts "=" * 60

    Dir.glob(playkit_dir.join("**/*.toml")).each do |file_path|
      # Skip overlays.toml - that will be handled separately later
      next if File.basename(file_path) == "overlays.toml"

      puts "\nImporting #{file_path}..."

      begin
        TomlImporter.import_file(file_path)
        puts "  ✓ Success"
        imported_count += 1
      rescue => e
        puts "  ✗ Error: #{e.message}"
        error_count += 1
      end
    end

    puts "\n" + "=" * 60
    puts "Import complete: #{imported_count} entities imported"
    puts "Errors: #{error_count}" if error_count > 0
  end
end
