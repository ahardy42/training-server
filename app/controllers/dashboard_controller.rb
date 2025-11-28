class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # Prepare activity trend data for charts
    @activity_trends = prepare_activity_trends
  end

  private

  def prepare_activity_trends
    current_year = Date.current.year
    start_date = Date.new(current_year, 1, 1)
    end_date = Date.new(current_year, 12, 31)

    # Get all activities for the current year
    activities = current_user.activities
      .where(date: start_date..end_date)
      .where.not(duration: nil)
      .order(:date)

    # Calculate monthly totals (hours per month)
    monthly_hours = {}
    (1..12).each do |month|
      month_start = Date.new(current_year, month, 1)
      month_end = month_start.end_of_month
      month_activities = activities.where(date: month_start..month_end)
      total_seconds = month_activities.sum(:duration) || 0
      monthly_hours[month] = total_seconds / 3600.0
    end

    # Calculate weekly/daily time for 2D histogram
    # Group by week and day of week
    weekly_daily_time = {}
    
    # Get all weeks in the year
    # Start from the first day of the year, but align to week start (Sunday)
    current_week_start = start_date.beginning_of_week
    week_number = 1
    max_weeks = 53
    
    while week_number <= max_weeks
      week_end = current_week_start.end_of_week
      
      # Only process weeks that overlap with the current year
      if week_end >= start_date && current_week_start <= end_date
        week_key = "W#{week_number.to_s.rjust(2, '0')}"
        
        # Initialize days for this week (0 = Sunday, 6 = Saturday)
        weekly_daily_time[week_key] = {}
        (0..6).each do |day_of_week|
          day_date = current_week_start + day_of_week.days
          if day_date >= start_date && day_date <= end_date
            day_activities = activities.where(date: day_date)
            total_seconds = day_activities.sum(:duration) || 0
            weekly_daily_time[week_key][day_of_week] = total_seconds / 3600.0 # Convert to hours
          else
            weekly_daily_time[week_key][day_of_week] = nil
          end
        end
      end
      
      # Move to next week
      current_week_start = week_end + 1.day
      week_number += 1
      
      # Stop if we've passed the end of the year
      break if current_week_start > end_date
    end

    {
      monthly_hours: monthly_hours,
      weekly_daily_time: weekly_daily_time,
      year: current_year
    }
  end
end
