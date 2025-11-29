# frozen_string_literal: true

# Background job to sync all activities with activity_type_id
# This job processes activities in batches and sets their activity_type_id
# based on the normalized activity_type string column
class SyncActivitiesActivityTypesJob < ApplicationJob
  queue_as :default

  # Sync all activities with activity_type_id
  # Processes activities in batches for performance
  def perform
    results = {
      processed: 0,
      updated: 0,
      skipped: 0,
      errors: []
    }

    # Process activities in batches
    # Use read_attribute to explicitly reference the column, not the association
    Activity.where.not(Activity.arel_table[:activity_type].eq(nil))
            .where(activity_type_id: nil)
            .find_in_batches(batch_size: 1000) do |batch|
      batch.each do |activity|
        begin
          # Get the activity_type string from the column, not the association
          activity_type_string = activity.read_attribute(:activity_type)
          
          if activity_type_string.blank?
            results[:skipped] += 1
            next
          end
          
          # Normalize the activity_type string
          normalized_key = ActivityType.normalize_key(activity_type_string)
          
          if normalized_key.blank?
            results[:skipped] += 1
            next
          end

          # Find or create the ActivityType
          activity_type = ActivityType.find_or_create_by_key(activity_type_string)
          
          if activity_type
            activity.update_column(:activity_type_id, activity_type.id)
            results[:updated] += 1
          else
            results[:skipped] += 1
            results[:errors] << "Activity #{activity.id}: Could not find or create activity type for '#{activity_type_string}'"
          end
          
          results[:processed] += 1
        rescue StandardError => e
          results[:errors] << "Activity #{activity.id}: #{e.message}"
          Rails.logger.error "SyncActivitiesActivityTypesJob: Error processing activity #{activity.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end

    # Log results
    Rails.logger.info "SyncActivitiesActivityTypesJob completed: " \
                      "#{results[:processed]} processed, #{results[:updated]} updated, " \
                      "#{results[:skipped]} skipped, #{results[:errors].count} errors"
    
    if results[:errors].any?
      Rails.logger.warn "SyncActivitiesActivityTypesJob errors: #{results[:errors].first(10).join('; ')}"
    end

    results
  end
end

