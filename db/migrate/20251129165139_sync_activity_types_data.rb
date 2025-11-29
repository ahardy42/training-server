class SyncActivityTypesData < ActiveRecord::Migration[8.0]
  def up
    # Normalize activity type string: downcase and convert spaces/hyphens to underscores
    def normalize_activity_type(type_string)
      return nil if type_string.blank?
      type_string.to_s.downcase.gsub(/[\s-]+/, '_').gsub(/[^a-z0-9_]/, '').gsub(/_+/, '_').gsub(/^_|_$/, '')
    end

    # Step 1: Create ActivityType records for all unique activity_type strings (normalized)
    activity_type_strings = Activity.where.not(activity_type: nil)
                                    .distinct
                                    .pluck(:activity_type)
                                    .compact
                                    .reject(&:blank?)

    activity_type_strings.each do |type_string|
      normalized_key = normalize_activity_type(type_string)
      next if normalized_key.blank?
      
      # Create ActivityType if it doesn't exist with normalized key
      ActivityType.find_or_create_by(key: normalized_key) do |at|
        # Humanize the normalized key for the name (e.g., "running" -> "Running", "e_biking" -> "E Biking")
        at.name = normalized_key.humanize
      end
    end

    # Step 2: Update activities to set activity_type_id based on normalized activity_type string
    Activity.where.not(activity_type: nil).find_each do |activity|
      normalized_key = normalize_activity_type(activity.activity_type)
      next if normalized_key.blank?
      
      activity_type = ActivityType.find_by(key: normalized_key)
      if activity_type
        activity.update_column(:activity_type_id, activity_type.id)
      end
    end

    # Step 3: Update trackpoints to set activity_type_id from their activity
    Trackpoint.joins(track: :activity)
              .where.not(activities: { activity_type_id: nil })
              .where(trackpoints: { activity_type_id: nil })
              .find_each do |trackpoint|
      activity = trackpoint.track.activity
      if activity&.activity_type_id
        trackpoint.update_column(:activity_type_id, activity.activity_type_id)
      end
    end
  end

  def down
    # Clear activity_type_id from activities and trackpoints
    Activity.update_all(activity_type_id: nil)
    Trackpoint.update_all(activity_type_id: nil)
    
    # Note: We don't delete ActivityType records as they might be referenced elsewhere
    # If you want to fully reverse, you'd need to delete them manually
  end
end
