namespace :playkit do
  desc "Import all TOML files from playkits directory"
  task import: :environment do
    playkit_dir = Rails.root.join("playkits")

    unless playkit_dir.exist?
      puts "No playkits directory found at #{playkit_dir}"
      Rails.logger.error "ImportRake: No playkits directory found at #{playkit_dir}"
      exit 1
    end

    Rails.logger.debug "ImportRake: Starting import from #{playkit_dir}"

    imported_count = 0
    error_count = 0

    toml_files = Dir.glob(playkit_dir.join("**/*.toml")).reject { |f| File.basename(f) == "overlays.toml" }
    Rails.logger.debug "ImportRake: Found #{toml_files.count} TOML files"

    puts "Importing TOML files from #{playkit_dir}..."
    puts "=" * 60

    toml_files.each do |file_path|
      puts "\nImporting #{file_path}..."

      begin
        TomlImporter.import_file(file_path)
        puts "  ✓ Success"
        Rails.logger.debug "ImportRake: Successfully imported #{file_path}"
        imported_count += 1
      rescue => e
        puts "  ✗ Error: #{e.message}"
        Rails.logger.error "ImportRake: Failed to import #{file_path}: #{e.message}"
        error_count += 1
      end
    end

    puts "\n" + "=" * 60
    puts "Import complete: #{imported_count} entities imported"
    puts "Errors: #{error_count}" if error_count > 0

    exit 1 if error_count > 0
  end
end
