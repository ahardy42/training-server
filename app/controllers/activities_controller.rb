# frozen_string_literal: true

class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_activity, only: [:show]

  def index
    @activities = current_user.activities.order(date: :desc, created_at: :desc)
  end

  def show
    @track = @activity.track
    @trackpoints = @track&.trackpoints&.order(:timestamp) || []
  end

  def new
    @activity = current_user.activities.build
  end

  def create
    if params[:activity_file].present?
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

  def activity_params
    params.require(:activity).permit(:activity_type, :date, :title, :description, :distance, :duration, :elevation, :average_power, :average_hr)
  end
end

