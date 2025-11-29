# frozen_string_literal: true

namespace :activity_types do
  desc "Sync all activities with activity_type_id based on activity_type string"
  task sync_activities: :environment do
    puts "Starting sync of activities with activity types..."
    puts "This may take a while depending on the number of activities."
    puts ""
    
    result = SyncActivitiesActivityTypesJob.new.perform
    
    puts "Sync completed!"
    puts "  Processed: #{result[:processed]}"
    puts "  Updated: #{result[:updated]}"
    puts "  Skipped: #{result[:skipped]}"
    puts "  Errors: #{result[:errors].count}"
    
    if result[:errors].any?
      puts ""
      puts "First 10 errors:"
      result[:errors].first(10).each do |error|
        puts "  - #{error}"
      end
    end
  end

  desc "Sync all trackpoints with activity_type_id from their activity"
  task sync_trackpoints: :environment do
    puts "Starting sync of trackpoints with activity types..."
    puts "This may take a while depending on the number of trackpoints."
    puts ""
    
    result = SyncTrackpointsActivityTypesJob.new.perform
    
    puts "Sync completed!"
    puts "  Processed: #{result[:processed]}"
    puts "  Updated: #{result[:updated]}"
    puts "  Skipped: #{result[:skipped]}"
    puts "  Errors: #{result[:errors].count}"
    
    if result[:errors].any?
      puts ""
      puts "First 10 errors:"
      result[:errors].first(10).each do |error|
        puts "  - #{error}"
      end
    end
  end

  desc "Sync both activities and trackpoints with activity types"
  task sync_all: :environment do
    puts "Starting full sync of activities and trackpoints with activity types..."
    puts ""
    
    puts "=== Syncing Activities ==="
    Rake::Task["activity_types:sync_activities"].invoke
    
    puts ""
    puts "=== Syncing Trackpoints ==="
    Rake::Task["activity_types:sync_trackpoints"].invoke
    
    puts ""
    puts "Full sync completed!"
  end
end

