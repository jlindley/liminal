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

    puts "Importing TOML files from #{playkit_dir}..."
    puts "=" * 60

    # Import overlays first
    overlays_file = playkit_dir.join("bubble/overlays/overlays.toml")
    if overlays_file.exist?
      puts "\nImporting overlays from #{overlays_file}..."
      begin
        TomlImporter.import_overlays(overlays_file)
        overlay_count = Overlay.count
        puts "  ✓ Success - #{overlay_count} overlays imported"
        Rails.logger.debug "ImportRake: Successfully imported #{overlay_count} overlays"
      rescue => e
        puts "  ✗ Error: #{e.message}"
        Rails.logger.error "ImportRake: Failed to import overlays: #{e.message}"
        error_count += 1
      end
    else
      puts "\nNo overlays file found at #{overlays_file}"
      Rails.logger.debug "ImportRake: No overlays file found"
    end

    # Import entities
    toml_files = Dir.glob(playkit_dir.join("**/*.toml")).reject { |f| File.basename(f) == "overlays.toml" }
    Rails.logger.debug "ImportRake: Found #{toml_files.count} entity TOML files"

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
