# frozen_string_literal: true

# Background job to sync all trackpoints with activity_type_id
# This job processes trackpoints in batches and sets their activity_type_id
# from their associated activity's activity_type_id
class SyncTrackpointsActivityTypesJob < ApplicationJob
  queue_as :default

  # Sync all trackpoints with activity_type_id
  # Processes trackpoints in batches for performance
  def perform
    results = {
      processed: 0,
      updated: 0,
      skipped: 0,
      errors: []
    }

    # Process trackpoints that don't have activity_type_id but their activity does
    Trackpoint.joins(track: :activity)
              .where.not(activities: { activity_type_id: nil })
              .where(trackpoints: { activity_type_id: nil })
              .find_in_batches(batch_size: 5000) do |batch|
      batch.each do |trackpoint|
        begin
          activity = trackpoint.track&.activity
          
          if activity&.activity_type_id
            trackpoint.update_column(:activity_type_id, activity.activity_type_id)
            results[:updated] += 1
          else
            results[:skipped] += 1
          end
          
          results[:processed] += 1
        rescue StandardError => e
          results[:errors] << "Trackpoint #{trackpoint.id}: #{e.message}"
          Rails.logger.error "SyncTrackpointsActivityTypesJob: Error processing trackpoint #{trackpoint.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end

    # Log results
    Rails.logger.info "SyncTrackpointsActivityTypesJob completed: " \
                      "#{results[:processed]} processed, #{results[:updated]} updated, " \
                      "#{results[:skipped]} skipped, #{results[:errors].count} errors"
    
    if results[:errors].any?
      Rails.logger.warn "SyncTrackpointsActivityTypesJob errors: #{results[:errors].first(10).join('; ')}"
    end

    results
  end
end

