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

    # Get unique activity types for the user
    @activity_types = current_user.activities
      .where.not(activity_type: [nil, ''])
      .distinct
      .pluck(:activity_type)
      .compact
      .sort
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
    # With proper indexes, this will be fast
    base_query = Trackpoint
      .joins(track: :activity)
      .where(activities: { user_id: current_user.id })
      .where(timestamp: start_date.beginning_of_day..end_date.end_of_day)
      .where.not(latitude: nil, longitude: nil)

    # Filter by activity type if provided
    if params[:activity_type].present? && params[:activity_type] != 'all'
      base_query = base_query.where(activities: { activity_type: params[:activity_type] })
    end

    # Filter by map bounds if provided (for zoomed/zoomed views)
    if params[:north].present? && params[:south].present? && params[:east].present? && params[:west].present?
      north = params[:north].to_f
      south = params[:south].to_f
      east = params[:east].to_f
      west = params[:west].to_f
      
      # Handle longitude wrapping (east might be less than west if crossing the date line)
      if east < west
        # Crosses the date line - need OR condition
        base_query = base_query.where(
          "(latitude >= ? AND latitude <= ?) AND (longitude >= ? OR longitude <= ?)",
          south, north, west, east
        )
      else
        # Normal case - simple bounding box
        base_query = base_query.where(
          "latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?",
          south, north, west, east
        )
      end
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
        sanitized_type = ActiveRecord::Base.connection.quote(params[:activity_type])
        "AND a.activity_type = #{sanitized_type}"
      else
        ""
      end

      bounds_filter = if params[:north].present? && params[:south].present? && params[:east].present? && params[:west].present?
        north = params[:north].to_f
        south = params[:south].to_f
        east = params[:east].to_f
        west = params[:west].to_f
        
        if east < west
          # Crosses date line
          "AND tp.latitude >= #{south} AND tp.latitude <= #{north} AND (tp.longitude >= #{west} OR tp.longitude <= #{east})"
        else
          "AND tp.latitude >= #{south} AND tp.latitude <= #{north} AND tp.longitude >= #{west} AND tp.longitude <= #{east}"
        end
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
            AND tp.latitude IS NOT NULL
            AND tp.longitude IS NOT NULL
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

