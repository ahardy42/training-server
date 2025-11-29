# frozen_string_literal: true

class MapsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Get date range from first to last activity
    first_activity = current_user.activities.order(:date, :created_at).first
    last_activity = current_user.activities.order(date: :desc, created_at: :desc).first
    
    default_start_date = first_activity&.date || Date.today
    default_end_date = last_activity&.date || Date.today

    # Parse dates from params or use defaults
    begin
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : default_start_date
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : default_end_date
    rescue ArgumentError
      @start_date = default_start_date
      @end_date = default_end_date
    end

    # Get unique activity types for the user (using association)
    @activity_types = current_user.activities
      .joins(:activity_type)
      .includes(:activity_type)
      .distinct
      .map { |a| a.activity_type }
      .compact
      .sort_by(&:name)
  end

  def trackpoints
    # Get date range from first to last activity
    first_activity = current_user.activities.order(:date, :created_at).first
    last_activity = current_user.activities.order(date: :desc, created_at: :desc).first
    
    default_start_date = first_activity&.date || Date.today
    default_end_date = last_activity&.date || Date.today

    begin
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : default_start_date
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : default_end_date
    rescue ArgumentError
      start_date = default_start_date
      end_date = default_end_date
    end

    # Build the base query using ActiveRecord
    # With PostGIS spatial indexes, this will be very fast
    base_query = Trackpoint
      .joins(track: :activity)
      .where(activities: { user_id: current_user.id })
      .where(timestamp: start_date.beginning_of_day..end_date.end_of_day)
      .where.not(location: nil) # Use PostGIS geometry column instead of checking lat/lng separately

    # Filter by activity type if provided (using activity_type_id via key)
    if params[:activity_type].present? && params[:activity_type] != 'all'
      activity_type = ActivityType.find_by(key: params[:activity_type])
      if activity_type
        base_query = base_query.where(activities: { activity_type_id: activity_type.id })
      end
    end

    # Filter by map bounds if provided (for zoomed/zoomed views)
    # Use PostGIS spatial functions for efficient bounding box queries
    if params[:north].present? && params[:south].present? && params[:east].present? && params[:west].present?
      north = params[:north].to_f
      south = params[:south].to_f
      east = params[:east].to_f
      west = params[:west].to_f
      
      # Create a bounding box using PostGIS ST_MakeEnvelope
      # ST_MakeEnvelope(xmin, ymin, xmax, ymax, srid)
      # Note: PostGIS uses (longitude, latitude) order, and we use SRID 4326 (WGS84)
      base_query = base_query.where(
        "ST_Within(trackpoints.location, ST_MakeEnvelope(?, ?, ?, ?, 4326))",
        west, south, east, north
      )
    end

    # Get count efficiently (uses COUNT(*) which is fast with indexes)
    total_count = base_query.count

    # For heatmaps, we don't need every single point
    # Sample points to reduce data transfer and improve performance
    # Sample every Nth point if we have more than 10,000 points
    sample_interval = if total_count > 10_000
      # Sample to get approximately 10,000 points
      (total_count / 10_000.0).ceil
    else
      1 # No sampling needed
    end

    # Adjust sampling based on visible area
    # When zoomed in (bounds provided), we can show more detail
    # When zoomed out (no bounds), use more aggressive sampling
    if params[:north].present? && params[:south].present?
      # Calculate approximate area (rough estimate)
      lat_range = params[:north].to_f - params[:south].to_f
      # If zoomed in (small area), reduce sampling threshold
      # For very zoomed in views (< 1 degree), show more points
      if lat_range < 1.0
        # Very zoomed in - show up to 20,000 points
        sample_interval = if total_count > 20_000
          (total_count / 20_000.0).ceil
        else
          1
        end
      elsif lat_range < 5.0
        # Moderately zoomed - show up to 15,000 points
        sample_interval = if total_count > 15_000
          (total_count / 15_000.0).ceil
        else
          1
        end
      end
      # Otherwise use default 10,000 point sampling
    end

    # Use efficient pluck for small datasets, or raw SQL for sampling
    if sample_interval > 1
      # Use raw SQL with window function for efficient sampling
      # This avoids loading all records into memory
      activity_type_filter = if params[:activity_type].present? && params[:activity_type] != 'all'
        activity_type = ActivityType.find_by(key: params[:activity_type])
        if activity_type
          "AND a.activity_type_id = #{activity_type.id}"
        else
          ""
        end
      else
        ""
      end

      bounds_filter = if params[:north].present? && params[:south].present? && params[:east].present? && params[:west].present?
        north = params[:north].to_f
        south = params[:south].to_f
        east = params[:east].to_f
        west = params[:west].to_f
        
        # Use PostGIS ST_Within for efficient spatial filtering
        # ST_MakeEnvelope(xmin, ymin, xmax, ymax, srid)
        "AND ST_Within(tp.location, ST_MakeEnvelope(#{west}, #{south}, #{east}, #{north}, 4326))"
      else
        ""
      end

      user_id = current_user.id
      start_ts = start_date.beginning_of_day
      end_ts = end_date.end_of_day

      sql = <<-SQL.squish
        SELECT latitude, longitude
        FROM (
          SELECT 
            tp.latitude,
            tp.longitude,
            ROW_NUMBER() OVER (ORDER BY tp.timestamp) as rn
          FROM trackpoints tp
          INNER JOIN tracks t ON t.id = tp.track_id
          INNER JOIN activities a ON a.id = t.activity_id
          WHERE a.user_id = #{user_id}
            AND tp.timestamp >= #{ActiveRecord::Base.connection.quote(start_ts)}
            AND tp.timestamp <= #{ActiveRecord::Base.connection.quote(end_ts)}
            AND tp.location IS NOT NULL
            #{activity_type_filter}
            #{bounds_filter}
        ) sampled
        WHERE rn % #{sample_interval} = 1
      SQL

      result = ActiveRecord::Base.connection.select_all(sql)
      heatmap_data = result.map { |row| [row['latitude'].to_f, row['longitude'].to_f, 1.0] }
    else
      # No sampling needed - use pluck which is very efficient
      # Pluck only loads the specific columns we need
      coordinates = base_query
        .order(:timestamp)
        .pluck(:latitude, :longitude)
        .map { |lat, lng| [lat.to_f, lng.to_f, 1.0] }

      heatmap_data = coordinates
    end

    render json: {
      trackpoints: heatmap_data,
      count: total_count,
      sampled_count: heatmap_data.length,
      date_range: {
        start: start_date,
        end: end_date
      }
    }
  end
end

