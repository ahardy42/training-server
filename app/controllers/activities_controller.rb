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
    
    # Check if bulk upload job is running
    cache_key = "bulk_upload_job:#{current_user.id}"
    @bulk_upload_in_progress = Rails.cache.exist?(cache_key)
    
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: { bulk_upload_in_progress: @bulk_upload_in_progress } }
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
    require 'fileutils'
    
    begin
      # Handle zip file upload
      zip_file = params[:bulk_files]
      
      unless zip_file
        redirect_to activities_path, alert: "No file uploaded."
        return
      end
      
      # Check if a bulk upload job is already running for this user
      cache_key = "bulk_upload_job:#{current_user.id}"
      if Rails.cache.exist?(cache_key)
        redirect_to activities_path, alert: "A bulk upload is already in progress. Please wait for it to complete."
        return
      end
      
      # Save uploaded file to a temporary location that the job can access
      # Use Rails.root/tmp/uploads to ensure it persists until the job processes it
      upload_dir = Rails.root.join('tmp', 'uploads')
      FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
      
      # Generate a unique filename to avoid conflicts
      timestamp = Time.current.to_i
      unique_filename = "bulk_upload_#{current_user.id}_#{timestamp}_#{zip_file.original_filename}"
      zip_file_path = File.join(upload_dir, unique_filename)
      
      # Save the uploaded file
      File.open(zip_file_path, 'wb') do |f|
        f.write(zip_file.read)
      end
      
      # Enqueue the background job
      BulkActivityUploadJob.perform_later(zip_file_path, current_user.id)
      
      # Redirect back to activities page with success message
      redirect_to activities_path, notice: "Bulk upload started. Your activities will be processed in the background."
      return
    rescue StandardError => e
      Rails.logger.error "Bulk upload error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to activities_path, alert: "Error starting bulk upload: #{e.message}"
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

