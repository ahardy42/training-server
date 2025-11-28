# frozen_string_literal: true

class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_activity, only: [:show]

  def index
    @activities = current_user.activities
      .includes(track: :trackpoints)
      .order(date: :desc, created_at: :desc)
      .page(params[:page])
      .per(10)
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @track = @activity.track
    @trackpoints = @track&.trackpoints&.where.not(latitude: nil, longitude: nil)&.order(:timestamp) || []
    
    # Prepare chart data if we have trackpoints
    if @trackpoints.any?
      @chart_data = prepare_chart_data(@trackpoints)
    end
  end

  def new
    @activity = current_user.activities.build
  end

  def create
    if params[:bulk_files].present?
      create_bulk
    elsif params[:activity_file].present?
      create_from_file
    else
      create_manual
    end
  end

  private

  def set_activity
    @activity = current_user.activities.find(params[:id])
  end

  def create_manual
    @activity = current_user.activities.build(activity_params)

    if @activity.save
      redirect_to @activity, notice: "Activity was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_from_file
    parser = ActivityFileParser.new(params[:activity_file])
    parsed_data = parser.parse

    if parser.errors.any?
      @activity = current_user.activities.build
      flash.now[:alert] = parser.errors.join(", ")
      render :new, status: :unprocessable_entity
      return
    end

    unless parsed_data
      @activity = current_user.activities.build
      flash.now[:alert] = "Failed to parse activity file."
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      # Create activity
      @activity = current_user.activities.create!(
        activity_type: parsed_data[:activity_type],
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
        track = @activity.create_track!(
          start_date: parsed_data[:start_time],
          end_date: parsed_data[:end_time]
        )

        # Create trackpoints in batches for performance
        trackpoints_to_create = parsed_data[:trackpoints].map do |tp_data|
          {
            track_id: track.id,
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
      end

      redirect_to @activity, notice: "Activity was successfully created from file."
    end
  rescue StandardError => e
    @activity = current_user.activities.build
    flash.now[:alert] = "Error creating activity: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def create_bulk
    require 'zip'
    require 'fileutils'
    
    results = {
      success: 0,
      failed: 0,
      skipped: 0,
      errors: []
    }
    
    begin
      # Handle zip file upload
      zip_file = params[:bulk_files]
      
      # Create temporary directory for extraction
      temp_dir = Dir.mktmpdir
      
      begin
        # Ensure temp directory exists and is writable
        FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
        
        # Extract zip file
        Zip::File.open(zip_file.path) do |zip|
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
              Rails.logger.error "Failed to extract #{entry.name}: #{e.message}"
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
              
              # Create activity
              ActiveRecord::Base.transaction do
                activity = current_user.activities.create!(
                  activity_type: parsed_data[:activity_type],
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
                end
                
                results[:success] += 1
              end
            rescue StandardError => e
              results[:failed] += 1
              results[:errors] << "#{File.basename(entry.name)}: #{e.message}"
              Rails.logger.error "Error processing #{entry.name}: #{e.message}"
              Rails.logger.error e.backtrace.join("\n")
            ensure
              file_obj&.close
              # Clean up extracted file
              File.delete(file_path) if File.exist?(file_path)
            end
          end
        end
        
        # Build success message
        message_parts = []
        message_parts << "#{results[:success]} activities created" if results[:success] > 0
        message_parts << "#{results[:skipped]} files skipped" if results[:skipped] > 0
        message_parts << "#{results[:failed]} files failed" if results[:failed] > 0
        
        if results[:success] > 0
          redirect_to activities_path, notice: message_parts.join(", ") + "."
        else
          redirect_to activities_path, alert: "No activities were created. #{results[:errors].first(5).join('; ')}"
        end
      ensure
        # Clean up temp directory
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    rescue Zip::Error => e
      redirect_to activities_path, alert: "Error processing zip file: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Bulk upload error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to activities_path, alert: "Error processing bulk upload: #{e.message}"
    end
  end

  def activity_params
    params.require(:activity).permit(:activity_type, :date, :title, :description, :distance, :duration, :elevation, :average_power, :average_hr)
  end

  def prepare_chart_data(trackpoints)
    return nil if trackpoints.empty?

    # Calculate cumulative distance and time arrays
    cumulative_distance_km = []
    cumulative_time_seconds = []
    elevations = []
    heartrates = []
    powers = []
    cadences = []
    speeds_kmh = []
    paces_min_per_km = []
    
    total_distance = 0.0
    start_time = trackpoints.first.timestamp
    
    trackpoints.each_with_index do |tp, index|
      # Calculate cumulative distance (Haversine formula)
      if index > 0
        prev_tp = trackpoints[index - 1]
        if prev_tp.latitude && prev_tp.longitude && tp.latitude && tp.longitude
          # Haversine formula to calculate distance between two points
          lat1_rad = prev_tp.latitude * Math::PI / 180
          lat2_rad = tp.latitude * Math::PI / 180
          delta_lat = (tp.latitude - prev_tp.latitude) * Math::PI / 180
          delta_lon = (tp.longitude - prev_tp.longitude) * Math::PI / 180
          
          a = Math.sin(delta_lat / 2) ** 2 +
              Math.cos(lat1_rad) * Math.cos(lat2_rad) *
              Math.sin(delta_lon / 2) ** 2
          c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
          distance_km = 6371 * c # Earth radius in km
          
          total_distance += distance_km
        end
      end
      
      cumulative_distance_km << total_distance
      
      # Calculate cumulative time in seconds
      if tp.timestamp && start_time
        time_diff = (tp.timestamp - start_time).to_f
        cumulative_time_seconds << time_diff
      else
        cumulative_time_seconds << (index * 1.0) # Fallback: assume 1 second intervals
      end
      
      # Collect data points
      elevations << (tp.elevation || 0)
      heartrates << (tp.heartrate || nil)
      powers << (tp.power || nil)
      cadences << (tp.cadence || nil)
      
      # Calculate speed and pace from segment distance and time
      if index > 0
        prev_tp = trackpoints[index - 1]
        segment_distance_km = cumulative_distance_km[index] - cumulative_distance_km[index - 1]
        segment_time_seconds = cumulative_time_seconds[index] - cumulative_time_seconds[index - 1]
        
        if segment_time_seconds > 0 && segment_distance_km > 0
          # Speed in km/h
          speed_kmh = (segment_distance_km / segment_time_seconds) * 3600.0
          speeds_kmh << speed_kmh
          
          # Pace in min/km
          pace_min_per_km = (segment_time_seconds / 60.0) / segment_distance_km
          paces_min_per_km << pace_min_per_km
        else
          speeds_kmh << nil
          paces_min_per_km << nil
        end
      else
        speeds_kmh << nil
        paces_min_per_km << nil
      end
    end
    
    # Convert units based on user preference
    if current_user&.units == "imperial"
      # Convert distance from km to miles
      distance_data = cumulative_distance_km.map { |km| km * 0.621371 }
      
      # Convert elevation from meters to feet
      elevation_data = elevations.map { |m| m * 3.28084 }
      
      # Convert speed from km/h to mph
      speed_data = speeds_kmh.map { |kmh| kmh ? kmh * 0.621371 : nil }
      
      # Convert pace from min/km to min/mile
      pace_data = paces_min_per_km.map { |pace| pace ? pace * 1.60934 : nil }
    else
      distance_data = cumulative_distance_km
      elevation_data = elevations
      speed_data = speeds_kmh
      pace_data = paces_min_per_km
    end
    
    {
      distance: distance_data,
      time_seconds: cumulative_time_seconds,
      elevation: elevation_data,
      heartrate: heartrates,
      power: powers,
      cadence: cadences,
      speed: speed_data,
      pace: pace_data
    }
  end
end

