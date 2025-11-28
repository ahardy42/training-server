# frozen_string_literal: true

class AddIndexesForTrackpointsQuery < ActiveRecord::Migration[8.0]
  def change
    # Index on trackpoints.timestamp for date range filtering
    add_index :trackpoints, :timestamp, name: 'index_trackpoints_on_timestamp'
    
    # Composite index on trackpoints for common query pattern (timestamp + coordinates)
    # This helps with queries that filter by timestamp and check for non-null coordinates
    add_index :trackpoints, [:timestamp, :latitude, :longitude], 
              where: 'latitude IS NOT NULL AND longitude IS NOT NULL',
              name: 'index_trackpoints_on_timestamp_and_coords'
    
    # Index on activities.activity_type for filtering
    add_index :activities, :activity_type, name: 'index_activities_on_activity_type'
    
    # Composite index on activities for user + activity_type filtering
    add_index :activities, [:user_id, :activity_type], 
              name: 'index_activities_on_user_id_and_activity_type'
    
    # Index on activities.date for date range queries
    add_index :activities, :date, name: 'index_activities_on_date'
    
    # Composite index on activities for user + date filtering
    add_index :activities, [:user_id, :date], name: 'index_activities_on_user_id_and_date'
  end
end

