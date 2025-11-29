module ApplicationHelper
  def format_duration(seconds)
    return "0:00" if seconds.nil? || seconds.zero?

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours.positive?
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end

  def format_pace(minutes_per_km)
    return "0:00" if minutes_per_km.nil? || minutes_per_km.zero?

    # Convert to minutes per mile if user prefers imperial
    pace = user_prefers_imperial? ? minutes_per_km * 1.60934 : minutes_per_km

    minutes = pace.to_i
    seconds = ((pace - minutes) * 60).to_i

    format("%d:%02d", minutes, seconds)
  end

  def format_distance(distance_km)
    return nil if distance_km.nil?

    if user_prefers_imperial?
      distance_miles = distance_km * 0.621371
      number_with_precision(distance_miles, precision: 2)
    else
      number_with_precision(distance_km, precision: 2)
    end
  end

  def distance_unit
    user_prefers_imperial? ? "mi" : "km"
  end

  def format_elevation(elevation_m)
    return nil if elevation_m.nil?

    if user_prefers_imperial?
      elevation_ft = elevation_m * 3.28084
      number_with_precision(elevation_ft, precision: 0)
    else
      number_with_precision(elevation_m, precision: 0)
    end
  end

  def elevation_unit
    user_prefers_imperial? ? "ft" : "m"
  end

  def pace_unit
    user_prefers_imperial? ? "/mi" : "/km"
  end

  def format_speed(kmh)
    return nil if kmh.nil?

    if user_prefers_imperial?
      mph = kmh * 0.621371
      number_with_precision(mph, precision: 2)
    else
      number_with_precision(kmh, precision: 2)
    end
  end

  def speed_unit
    user_prefers_imperial? ? "mph" : "km/h"
  end

  # Get the activity type display name from the association
  def activity_type_display_name(activity)
    activity.activity_type&.name
  end

  # Get the activity type key from the association
  def activity_type_key(activity)
    activity.activity_type&.key
  end

  private

  def user_prefers_imperial?
    current_user&.units == "imperial"
  end
end
