# frozen_string_literal: true

class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :activity_type, optional: true
  has_one :track, dependent: :destroy

  # Check if this activity is a duplicate based on:
  # - Same day (date)
  # - Same start time (track.start_date)
  # - Same activity_type, end_time, and trackpoint count
  #
  # @param start_time [Time, DateTime, nil] The start time of the activity being checked
  # @param end_time [Time, DateTime, nil] The end time of the activity being checked
  # @param trackpoint_count [Integer] The number of trackpoints
  # @return [Activity, nil] Returns the duplicate activity if found, nil otherwise
  def self.find_duplicate(user:, date:, activity_type:, start_time: nil, end_time: nil, trackpoint_count: 0)
    # First, check if there are any activities on the same day
    same_day_activities = user.activities
      .where(date: date)
      .includes(:track)
      .to_a

    return nil if same_day_activities.empty?

    # If no start_time provided, we can't check for duplicates (manual entry without track)
    return nil unless start_time

    # Check each activity on the same day
    same_day_activities.each do |existing_activity|
      existing_track = existing_activity.track
      
      # Skip if existing activity has no track or no start_date
      next unless existing_track&.start_date

      # Check if start times match (compare to the second)
      existing_start = existing_track.start_date
      if existing_start.to_i == start_time.to_i
        # Start times match, now check similarity hierarchy:
        # 1. activity_type
        # 2. end_time
        # 3. trackpoint count

        # Check activity_type by key
        # activity_type parameter can be a string (key) or ActivityType object
        existing_type_key = existing_activity.activity_type&.key
        activity_type_key = activity_type.is_a?(ActivityType) ? activity_type.key : ActivityType.normalize_key(activity_type)
        next unless existing_type_key == activity_type_key

        # Check end_time
        # If both have end_time, they must match
        # If only one has end_time, they're not duplicates
        if end_time && existing_track.end_date
          # Both have end_time - must match
          next unless existing_track.end_date.to_i == end_time.to_i
        elsif end_time || existing_track.end_date
          # Only one has end_time - not a duplicate
          next
        end
        # If neither has end_time, continue to trackpoint check

        # Check trackpoint count
        existing_trackpoint_count = existing_track.trackpoints.count
        next unless existing_trackpoint_count == trackpoint_count

        # All checks passed - this is a duplicate
        return existing_activity
      end
    end

    nil
  end
end

