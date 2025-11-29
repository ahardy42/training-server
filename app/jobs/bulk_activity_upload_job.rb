# frozen_string_literal: true

# Background job for processing bulk activity uploads from ZIP files
# This job extracts files from a ZIP archive and processes each activity file
class BulkActivityUploadJob < ApplicationJob
  queue_as :default

  # Process a bulk activity upload from a ZIP file
  # @param zip_file_path [String] Path to the uploaded ZIP file
  # @param user_id [Integer] ID of the user uploading the activities
  def perform(zip_file_path, user_id)
    require 'zip'
    require 'fileutils'

    user = User.find(user_id)
    cache_key = "bulk_upload_job:#{user_id}"
    
    # Set flag to indicate job is running
    Rails.cache.write(cache_key, true, expires_in: 1.hour)
    
    results = {
      success: 0,
      failed: 0,
      skipped: 0,
      errors: []
    }

    # Create temporary directory for extraction
    temp_dir = Dir.mktmpdir

    begin
      # Verify zip file exists
      unless File.exist?(zip_file_path) && File.readable?(zip_file_path)
        Rails.logger.error "BulkActivityUploadJob: ZIP file not found or not readable: #{zip_file_path}"
        return
      end

      # Extract zip file
      Zip::File.open(zip_file_path) do |zip|
        zip.each do |entry|
          # Skip directories
          next if entry.name.end_with?('/')

          # Skip macOS metadata files
          next if entry.name.include?('__MACOSX') || entry.name.start_with?('._')

          # Skip hidden files
          next if File.basename(entry.name).start_with?('.')

          # Get file extension
          ext = File.extname(entry.name).downcase

          # Check if it's a supported file type
          # For .gz files, check if the base name ends with .fit
          is_supported = false
          if ext == '.gz'
            base_name = File.basename(entry.name, '.gz')
            is_supported = base_name.downcase.end_with?('.fit')
          else
            is_supported = ['.gpx', '.fit'].include?(ext)
          end

          next unless is_supported

          # Preserve directory structure but flatten to temp_dir
          # Use just the filename to avoid path issues
          safe_filename = File.basename(entry.name)
          # Sanitize filename to avoid any issues
          safe_filename = safe_filename.gsub(/[^0-9A-Za-z.\-_]/, '_')
          file_path = File.join(temp_dir, safe_filename)

          # Extract the file using get_input_stream to handle it better
          begin
            # Use get_input_stream and write manually for better control
            entry.get_input_stream do |is|
              File.open(file_path, 'wb') do |f|
                f.write(is.read)
              end
            end
          rescue => e
            results[:skipped] += 1
            results[:errors] << "#{File.basename(entry.name)}: Failed to extract - #{e.message}"
            Rails.logger.error "BulkActivityUploadJob: Failed to extract #{entry.name}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            next
          end

          # Verify file exists and is readable
          unless File.exist?(file_path) && File.readable?(file_path)
            results[:skipped] += 1
            results[:errors] << "#{File.basename(entry.name)}: File not accessible after extraction"
            next
          end

          # Process the file
          begin
            file_obj = File.open(file_path, 'rb')
            parser = ActivityFileParser.new(file_obj)
            parsed_data = parser.parse

            if parser.errors.any? || !parsed_data
              results[:skipped] += 1
              results[:errors] << "#{File.basename(entry.name)}: #{parser.errors.join(', ') || 'Failed to parse'}"
              next
            end

            # Check for duplicates before creating
            trackpoint_count = parsed_data[:trackpoints]&.count || 0
            duplicate = Activity.find_duplicate(
              user: user,
              date: parsed_data[:date],
              activity_type: parsed_data[:activity_type],
              start_time: parsed_data[:start_time],
              end_time: parsed_data[:end_time],
              trackpoint_count: trackpoint_count
            )

            if duplicate
              results[:skipped] += 1
              results[:errors] << "#{File.basename(entry.name)}: Duplicate activity already exists for this date and time"
              next
            end

            # Create activity
            ActiveRecord::Base.transaction do
              # Find or create ActivityType
              activity_type_obj = ActivityType.find_or_create_by_key(parsed_data[:activity_type])
              
              activity = user.activities.create!(
                activity_type_id: activity_type_obj&.id,
                activity_type: parsed_data[:activity_type], # Keep string for backward compatibility
                title: parsed_data[:title],
                date: parsed_data[:date],
                description: parsed_data[:description],
                distance: parsed_data[:distance],
                duration: parsed_data[:duration],
                elevation: parsed_data[:elevation],
                average_power: parsed_data[:average_power],
                average_hr: parsed_data[:average_hr]
              )

              # Create track if we have trackpoints
              if parsed_data[:trackpoints].present? && parsed_data[:trackpoints].any?
                track = activity.create_track!(
                  start_date: parsed_data[:start_time],
                  end_date: parsed_data[:end_time]
                )

                # Create trackpoints in batches
                trackpoints_to_create = parsed_data[:trackpoints].map do |tp_data|
                  {
                    track_id: track.id,
                    activity_type_id: activity_type_obj&.id,
                    timestamp: tp_data[:timestamp],
                    latitude: tp_data[:latitude],
                    longitude: tp_data[:longitude],
                    heartrate: tp_data[:heartrate],
                    power: tp_data[:power],
                    cadence: tp_data[:cadence],
                    elevation: tp_data[:elevation],
                    created_at: Time.current,
                    updated_at: Time.current
                  }
                end

                Trackpoint.insert_all(trackpoints_to_create) if trackpoints_to_create.any?
                
                # Generate polyline from trackpoints
                track.generate_polyline! if trackpoints_to_create.any?
              end

              results[:success] += 1
            end
          rescue StandardError => e
            results[:failed] += 1
            results[:errors] << "#{File.basename(entry.name)}: #{e.message}"
            Rails.logger.error "BulkActivityUploadJob: Error processing #{entry.name}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
          ensure
            file_obj&.close
            # Clean up extracted file
            File.delete(file_path) if File.exist?(file_path)
          end
        end
      end

      # Log results
      Rails.logger.info "BulkActivityUploadJob completed for user #{user_id}: " \
                        "#{results[:success]} success, #{results[:failed]} failed, " \
                        "#{results[:skipped]} skipped"
      if results[:errors].any?
        Rails.logger.warn "BulkActivityUploadJob errors: #{results[:errors].first(10).join('; ')}"
      end
    rescue Zip::Error => e
      Rails.logger.error "BulkActivityUploadJob: Error processing zip file: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    rescue StandardError => e
      Rails.logger.error "BulkActivityUploadJob: Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    ensure
      # Clean up temp directory
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      # Clean up zip file
      File.delete(zip_file_path) if File.exist?(zip_file_path)
      # Clear the job flag
      Rails.cache.delete(cache_key)
    end
  end
end

