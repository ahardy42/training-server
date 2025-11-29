# frozen_string_literal: true

# Background job to sync all activities with activity_type_id
# This job processes activities that don't have an activity_type_id
# Note: This job is mainly for historical data migration. New activities should
# always have activity_type_id set during creation.
class SyncActivitiesActivityTypesJob < ApplicationJob
  queue_as :default

  # Sync all activities with activity_type_id
  # Processes activities in batches for performance
  # Note: This will only process activities without activity_type_id
  # Since the activity_type string column has been removed, this job
  # will only work for activities that somehow don't have activity_type_id set
  def perform
    results = {
      processed: 0,
      updated: 0,
      skipped: 0,
      errors: []
    }

    # Process activities that don't have activity_type_id
    # Since the string column is gone, we can only process activities
    # that somehow don't have activity_type_id set (shouldn't happen in normal operation)
    Activity.where(activity_type_id: nil)
            .find_in_batches(batch_size: 1000) do |batch|
      batch.each do |activity|
        begin
          # Without the string column, we can't determine what activity type this should be
          # Skip these activities and log an error
          results[:skipped] += 1
          results[:errors] << "Activity #{activity.id}: Cannot determine activity type (string column removed)"
          
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

