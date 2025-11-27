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

    minutes = minutes_per_km.to_i
    seconds = ((minutes_per_km - minutes) * 60).to_i

    format("%d:%02d", minutes, seconds)
  end
end
