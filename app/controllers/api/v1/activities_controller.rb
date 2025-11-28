# frozen_string_literal: true

module Api
  module V1
    class ActivitiesController < Api::BaseController
      before_action :set_activity, only: [:update]
      
      # GET /api/v1/activities
      def index
        @activities = current_user.activities
          .includes(:track)  # Only include track, not trackpoints (they're not needed in index)
          .order(date: :desc, created_at: :desc)
        
        # Optional pagination
        if params[:page].present?
          @activities = @activities.page(params[:page]).per(params[:per_page] || 10)
        end
        
        render json: {
          activities: @activities.map { |activity| serialize_activity(activity) }
        }
      end
      
      # GET /api/v1/activities/:id
      def show
        # Eager load trackpoints only for the show action where they're needed
        @activity = current_user.activities
          .includes(track: :trackpoints)
          .find(params[:id])
        
        render json: serialize_activity(@activity, include_trackpoints: true)
      rescue ActiveRecord::RecordNotFound
        render_json_error("Activity not found", status: :not_found)
      end
      
      # POST /api/v1/activities
      def create
        ActiveRecord::Base.transaction do
          @activity = current_user.activities.build(activity_params.except(:track, :trackpoints))
          
          unless @activity.save
            render_json_validation_errors(@activity)
            raise ActiveRecord::Rollback
          end
          
          # Handle track and trackpoints if provided
          if track_data.present?
            create_or_update_track(@activity, track_data)
          end
          
          render json: serialize_activity(@activity, include_trackpoints: true), 
                 status: :created
        end
      rescue StandardError => e
        render_json_error("Failed to create activity: #{e.message}")
      end
      
      # PATCH/PUT /api/v1/activities/:id
      def update
        ActiveRecord::Base.transaction do
          unless @activity.update(activity_params.except(:track, :trackpoints))
            render_json_validation_errors(@activity)
            raise ActiveRecord::Rollback
          end
          
          # Handle track and trackpoints if provided
          if track_data.present?
            create_or_update_track(@activity, track_data)
          end
          
          render json: serialize_activity(@activity, include_trackpoints: true)
        end
      rescue StandardError => e
        render_json_error("Failed to update activity: #{e.message}")
      end
      
      private
      
      def set_activity
        @activity = current_user.activities.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_json_error("Activity not found", status: :not_found)
      end
      
      def activity_params
        params.require(:activity).permit(
          :activity_type, 
          :date, 
          :title, 
          :description, 
          :distance, 
          :duration, 
          :elevation, 
          :average_power, 
          :average_hr,
          track: [:start_date, :end_date],
          trackpoints: [
            :timestamp,
            :latitude,
            :longitude,
            :heartrate,
            :power,
            :cadence,
            :elevation
          ]
        )
      end
      
      def track_data
        params[:activity][:track] if params[:activity].present?
      end
      
      def trackpoints_data
        params[:activity][:trackpoints] if params[:activity].present?
      end
      
      def create_or_update_track(activity, track_params)
        track = activity.track || activity.build_track
        
        track_attrs = {
          start_date: track_params[:start_date],
          end_date: track_params[:end_date]
        }.compact
        
        # Save track if it's new or if we have attributes to update
        if track.new_record? || track_attrs.any?
          track.assign_attributes(track_attrs) if track_attrs.any?
          track.save!
        end
        
        # Handle trackpoints if provided
        if trackpoints_data.present? && trackpoints_data.is_a?(Array)
          # Delete existing trackpoints if we're replacing them
          track.trackpoints.destroy_all if track.persisted?
          
          # Create new trackpoints in batches
          trackpoints_to_create = trackpoints_data.map do |tp_data|
            {
              track_id: track.id,
              timestamp: parse_datetime(tp_data[:timestamp]),
              latitude: tp_data[:latitude],
              longitude: tp_data[:longitude],
              heartrate: tp_data[:heartrate],
              power: tp_data[:power],
              cadence: tp_data[:cadence],
              elevation: tp_data[:elevation],
              created_at: Time.current,
              updated_at: Time.current
            }.compact
          end
          
          Trackpoint.insert_all(trackpoints_to_create) if trackpoints_to_create.any?
        end
        
        track
      end
      
      def parse_datetime(value)
        return nil if value.blank?
        
        case value
        when String
          Time.parse(value) rescue nil
        when Time, DateTime
          value
        else
          nil
        end
      end
      
      def serialize_activity(activity, include_trackpoints: false)
        data = {
          id: activity.id,
          activity_type: activity.activity_type,
          date: activity.date,
          title: activity.title,
          description: activity.description,
          distance: activity.distance&.to_f,
          duration: activity.duration,
          elevation: activity.elevation&.to_f,
          average_power: activity.average_power&.to_f,
          average_hr: activity.average_hr&.to_f,
          created_at: activity.created_at,
          updated_at: activity.updated_at
        }
        
        if activity.track.present?
          track = activity.track
          data[:track] = {
            id: track.id,
            start_date: track.start_date,
            end_date: track.end_date
          }
          
          if include_trackpoints && track.trackpoints.any?
            data[:track][:trackpoints] = track.trackpoints.order(:timestamp).map do |tp|
              {
                id: tp.id,
                timestamp: tp.timestamp,
                latitude: tp.latitude&.to_f,
                longitude: tp.longitude&.to_f,
                heartrate: tp.heartrate&.to_f,
                power: tp.power&.to_f,
                cadence: tp.cadence&.to_f,
                elevation: tp.elevation&.to_f
              }
            end
          end
        end
        
        data
      end
    end
  end
end

