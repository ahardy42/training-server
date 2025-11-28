# frozen_string_literal: true

class MapsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Default to last 30 days if no dates provided
    begin
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    rescue ArgumentError
      @start_date = 30.days.ago.to_date
      @end_date = Date.today
    end
  end

  def trackpoints
    begin
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    rescue ArgumentError
      start_date = 30.days.ago.to_date
      end_date = Date.today
    end

    # Build the base query
    base_query = Trackpoint
      .joins(track: :activity)
      .where(activities: { user_id: current_user.id })
      .where(timestamp: start_date.beginning_of_day..end_date.end_of_day)
      .where.not(latitude: nil, longitude: nil)

    # Get count before selecting specific columns
    count = base_query.count

    # Get all trackpoints for the user's activities within the date range
    trackpoints = base_query
      .select(:latitude, :longitude, :timestamp)
      .order(:timestamp)

    # Format for heatmap: [lat, lng, intensity]
    # Intensity can be based on frequency or just set to 1
    heatmap_data = trackpoints.map { |tp| [tp.latitude, tp.longitude, 1.0] }

    render json: {
      trackpoints: heatmap_data,
      count: count,
      date_range: {
        start: start_date,
        end: end_date
      }
    }
  end
end

