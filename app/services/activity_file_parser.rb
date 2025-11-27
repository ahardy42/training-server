# frozen_string_literal: true

# Service to parse activity files (GPX, FIT, gzipped FIT) and extract activity data
class ActivityFileParser
  attr_reader :file, :file_type, :errors

  def initialize(file)
    @file = file
    @errors = []
    @file_type = detect_file_type
  end

  def parse
    return nil unless valid_file?

    case @file_type
    when :gpx
      parse_gpx
    when :fit
      parse_fit
    when :fit_gz
      parse_fit_gz
    else
      @errors << "Unsupported file type: #{@file_type}"
      nil
    end
  end

  private

  def detect_file_type
    filename = @file.respond_to?(:original_filename) ? @file.original_filename : @file.path
    extension = File.extname(filename).downcase

    case extension
    when '.gpx'
      :gpx
    when '.fit'
      :fit
    when '.gz'
      # Check if it's a gzipped FIT file
      if filename.downcase.include?('.fit')
        :fit_gz
      else
        :unknown
      end
    else
      :unknown
    end
  end

  def valid_file?
    if @file_type == :unknown
      @errors << "Unsupported file type. Please upload a GPX, FIT, or gzipped FIT file."
      return false
    end

    unless @file.respond_to?(:read) || File.exist?(@file)
      @errors << "Invalid file"
      return false
    end

    true
  end

  def parse_gpx
    require 'nokogiri'

    begin
      file_content = read_file_content
      Rails.logger.info "Parsing GPX file, content length: #{file_content.length} bytes"
      
      doc = Nokogiri::XML(file_content)
      
      # Register namespaces
      doc.root.add_namespace_definition('gpx', 'http://www.topografix.com/GPX/1/1')
      
      # Find the first track
      trk_element = doc.at_xpath('//gpx:trk', doc.root.namespaces) || doc.at_xpath('//trk')
      unless trk_element
        Rails.logger.error "No tracks found in GPX file"
        return nil
      end
      
      # Extract track metadata
      track_name = (trk_element.at_xpath('./gpx:name', doc.root.namespaces) || trk_element.at_xpath('./name'))&.text
      track_description = (trk_element.at_xpath('./gpx:desc', doc.root.namespaces) || trk_element.at_xpath('./desc'))&.text
      track_type = (trk_element.at_xpath('./gpx:type', doc.root.namespaces) || trk_element.at_xpath('./type'))&.text
      
      Rails.logger.info "Track name: #{track_name.inspect}"
      Rails.logger.info "Track description: #{track_description.inspect}"
      Rails.logger.info "Track type: #{track_type.inspect}"
      
      # Get all track segments
      trkseg_elements = trk_element.xpath('./gpx:trkseg', doc.root.namespaces) || trk_element.xpath('./trkseg')
      Rails.logger.info "Found #{trkseg_elements.length} track segments"
      
      # Extract trackpoints from all segments
      trackpoints_data = []
      trkseg_elements.each_with_index do |trkseg, seg_idx|
        trkpt_elements = trkseg.xpath('./gpx:trkpt', doc.root.namespaces) || trkseg.xpath('./trkpt')
        Rails.logger.info "Segment #{seg_idx + 1}: #{trkpt_elements.length} points"
        
        trkpt_elements.each do |trkpt|
          lat = trkpt['lat']&.to_f
          lon = trkpt['lon']&.to_f
          
          # Extract elevation
          ele_element = trkpt.at_xpath('./gpx:ele', doc.root.namespaces) || trkpt.at_xpath('./ele')
          elevation = ele_element&.text&.to_f
          
          # Extract time
          time_element = trkpt.at_xpath('./gpx:time', doc.root.namespaces) || trkpt.at_xpath('./time')
          timestamp = time_element&.text ? Time.parse(time_element.text) : nil
          
          trackpoints_data << {
            timestamp: timestamp,
            latitude: lat,
            longitude: lon,
            elevation: elevation
          }
        end
      end
      
      Rails.logger.info "Collected #{trackpoints_data.length} trackpoints"
      if trackpoints_data.any?
        first_point = trackpoints_data.first
        last_point = trackpoints_data.last
        Rails.logger.info "First point: lat=#{first_point[:latitude]}, lon=#{first_point[:longitude]}, time=#{first_point[:timestamp]}, elev=#{first_point[:elevation]}"
        Rails.logger.info "Last point: lat=#{last_point[:latitude]}, lon=#{last_point[:longitude]}, time=#{last_point[:timestamp]}, elev=#{last_point[:elevation]}"
      end

      # Calculate activity stats
      start_time = trackpoints_data.first&.dig(:timestamp)
      end_time = trackpoints_data.last&.dig(:timestamp)
      duration = start_time && end_time ? (end_time - start_time).to_i : nil
      
      Rails.logger.info "Start time: #{start_time}"
      Rails.logger.info "End time: #{end_time}"
      Rails.logger.info "Duration: #{duration} seconds"

      # Calculate distance (simple haversine between points)
      distance = calculate_distance(trackpoints_data)
      Rails.logger.info "Calculated distance: #{distance} km"

      # Calculate elevation gain
      elevation_gain = calculate_elevation_gain(trackpoints_data)
      Rails.logger.info "Calculated elevation gain: #{elevation_gain} meters"
      
      # Extract activity type (downcase the type tag)
      activity_type = track_type&.strip&.downcase
      Rails.logger.info "Extracted activity_type: #{activity_type}"
      
      # Generate title
      title = track_name.presence || "Activity on #{start_time&.strftime('%B %d, %Y')}"
      Rails.logger.info "Generated title: #{title}"

      result = {
        activity_type: activity_type || 'Unknown',
        title: title,
        date: start_time&.to_date,
        description: track_description.presence,
        distance: distance,
        duration: duration,
        elevation: elevation_gain,
        start_time: start_time,
        end_time: end_time,
        trackpoints: trackpoints_data
      }
      
      Rails.logger.info "Final result: activity_type=#{result[:activity_type]}, title=#{result[:title]}, distance=#{result[:distance]} km, duration=#{result[:duration]} seconds"
      
      result
    rescue StandardError => e
      Rails.logger.error "Error parsing GPX file: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @errors << "Error parsing GPX file: #{e.message}"
      nil
    end
  end

  def parse_fit
    require 'rubyfit'
    require 'tempfile'

    begin
      file_content = read_file_content
      
      # Write to a temp file for parsing
      temp_file = Tempfile.new(['activity', '.fit'])
      temp_file.binmode
      temp_file.write(file_content)
      temp_file.rewind
      temp_file.close

      Rails.logger.info "Parsing FIT file: #{temp_file.path}"
      
      # Initialize metadata
      activity_type = nil
      title = nil
      date = nil
      distance = nil
      duration_seconds = nil
      total_elapsed_time = nil
      average_power = nil
      average_hr = nil
      total_ascent = nil

      # Get trackpoints and extract data from all record types
      trackpoints_data = []
      session_found = false
      messages = []

      # Create a handler object that implements the callback methods
      handler = Object.new
      
      # Store data in instance variables
      handler.instance_variable_set(:@messages, messages)
      handler.instance_variable_set(:@activity_type, activity_type)
      handler.instance_variable_set(:@date, date)
      handler.instance_variable_set(:@distance, distance)
      handler.instance_variable_set(:@duration_seconds, duration_seconds)
      handler.instance_variable_set(:@total_elapsed_time, total_elapsed_time)
      handler.instance_variable_set(:@average_power, average_power)
      handler.instance_variable_set(:@average_hr, average_hr)
      handler.instance_variable_set(:@total_ascent, total_ascent)
      handler.instance_variable_set(:@trackpoints_data, trackpoints_data)
      handler.instance_variable_set(:@session_found, session_found)
      
      # Define callback methods
      def handler.on_activity(data)
        Rails.logger.info "on_activity called with: #{data.inspect}"
        @messages << { type: 'activity', data: data }
        
        if data['timestamp'] && !@date
          @date = Time.at(data['timestamp'])
          Rails.logger.info "  Extracted date from activity.timestamp: #{@date}"
        end
      end
      
      def handler.on_session(data)
        Rails.logger.info "on_session called with: #{data.inspect}"
        @messages << { type: 'session', data: data }
        @session_found = true
        
        if data['start_time'] && !@date
          @date = Time.at(data['start_time'])
          Rails.logger.info "  Extracted date from session.start_time: #{@date}"
        end
        
        if data['sport']
          # Sport is a numeric value, need to map it
          sport_map = {
            0 => 'generic',
            1 => 'running',
            2 => 'cycling',
            3 => 'transition',
            4 => 'fitness_equipment',
            5 => 'swimming',
            6 => 'basketball',
            7 => 'soccer',
            8 => 'tennis',
            9 => 'american_football',
            10 => 'training',
            11 => 'walking',
            12 => 'cross_country_skiing',
            13 => 'alpine_skiing',
            14 => 'snowboarding',
            15 => 'rowing',
            16 => 'mountaineering',
            17 => 'hiking',
            18 => 'multisport',
            19 => 'paddling',
            20 => 'flying',
            21 => 'e_biking',
            22 => 'motorcycling',
            23 => 'boating',
            24 => 'driving',
            25 => 'golf',
            26 => 'hang_gliding',
            27 => 'horseback_riding',
            28 => 'hunting',
            29 => 'fishing',
            30 => 'inline_skating',
            31 => 'rock_climbing',
            32 => 'sailing',
            33 => 'ice_skating',
            34 => 'sky_diving',
            35 => 'snowshoeing',
            36 => 'snowmobiling',
            37 => 'stand_up_paddleboarding',
            38 => 'surfing',
            39 => 'wakeboarding',
            40 => 'water_skiing',
            41 => 'kayaking',
            42 => 'rafting',
            43 => 'windsurfing',
            44 => 'kitesurfing',
            45 => 'tactical',
            46 => 'jumpmaster',
            47 => 'boxing',
            48 => 'floor_climbing',
            53 => 'all'
          }
          sport_num = data['sport'].to_i
          @activity_type = sport_map[sport_num] || 'unknown'
          Rails.logger.info "  Extracted activity_type from session.sport (#{sport_num}): #{@activity_type}"
        end
        
        if data['total_elapsed_time']
          @total_elapsed_time = data['total_elapsed_time']
          @duration_seconds = @total_elapsed_time
          Rails.logger.info "  Extracted duration from session.total_elapsed_time: #{@duration_seconds} seconds"
        end
        
        if data['total_distance']
          @distance = data['total_distance']
          Rails.logger.info "  Extracted distance from session.total_distance: #{@distance} meters"
        end
        
        if data['avg_power']
          @average_power = data['avg_power']
          Rails.logger.info "  Extracted average_power from session.avg_power: #{@average_power}"
        end
        
        if data['avg_heart_rate']
          @average_hr = data['avg_heart_rate']
          Rails.logger.info "  Extracted average_hr from session.avg_heart_rate: #{@average_hr}"
        end
        
        if data['total_ascent']
          @total_ascent = data['total_ascent']
          Rails.logger.info "  Extracted total_ascent from session.total_ascent: #{@total_ascent} meters"
        end
      end
      
      def handler.on_record(data)
        Rails.logger.debug "on_record called with: #{data.inspect}"
        @messages << { type: 'record', data: data }
        
        trackpoint_data = {}
        
        if data['timestamp']
          trackpoint_data[:timestamp] = Time.at(data['timestamp'])
          if !@date && @trackpoints_data.empty?
            @date = trackpoint_data[:timestamp]
            Rails.logger.info "Date from first trackpoint: #{@date}"
          end
        end
        
        if data['position_lat']
          trackpoint_data[:latitude] = data['position_lat']
        end
        
        if data['position_long']
          trackpoint_data[:longitude] = data['position_long']
        end
        
        if data['altitude'] || data['enhanced_altitude']
          trackpoint_data[:elevation] = data['enhanced_altitude'] || data['altitude']
        end
        
        if data['heart_rate']
          trackpoint_data[:heartrate] = data['heart_rate']
        end
        
        if data['cadence']
          trackpoint_data[:cadence] = data['cadence']
        end
        
        if data['power']
          trackpoint_data[:power] = data['power']
        end
        
        if data['speed'] || data['enhanced_speed']
          trackpoint_data[:speed] = data['enhanced_speed'] || data['speed']
        end
        
        if data['distance']
          trackpoint_data[:distance] = data['distance']
        end
        
        if trackpoint_data[:latitude] && trackpoint_data[:longitude]
          @trackpoints_data << trackpoint_data
        end
      end
      
      def handler.on_file_id(data)
        Rails.logger.info "on_file_id called with: #{data.inspect}"
        @messages << { type: 'file_id', data: data }
        
        if data['time_created'] && !@date
          @date = Time.at(data['time_created'])
          Rails.logger.info "  Extracted date from file_id.time_created: #{@date}"
        end
      end
      
      def handler.print_msg(msg)
        Rails.logger.debug "FIT message: #{msg}"
      end
      
      def handler.print_error_msg(msg)
        Rails.logger.error "FIT error: #{msg}"
      end
      
      # Add any other callback methods that might be called
      def handler.method_missing(method_name, *args)
        Rails.logger.debug "Handler method_missing: #{method_name} with args: #{args.inspect}"
        @messages << { type: method_name.to_s, data: args.first }
      end

      begin
        # Read file content
        file_content = File.read(temp_file.path)
        Rails.logger.info "Read #{file_content.length} bytes from FIT file"
        
        # Create parser with handler
        parser = RubyFit::FitParser.new(handler)
        Rails.logger.info "FitParser created with handler"
        
        # Parse the file content (parse expects a string, not a file path)
        parser.parse(file_content)
        
        # Extract values from handler
        activity_type = handler.instance_variable_get(:@activity_type)
        date = handler.instance_variable_get(:@date)
        distance = handler.instance_variable_get(:@distance)
        duration_seconds = handler.instance_variable_get(:@duration_seconds)
        total_elapsed_time = handler.instance_variable_get(:@total_elapsed_time)
        average_power = handler.instance_variable_get(:@average_power)
        average_hr = handler.instance_variable_get(:@average_hr)
        total_ascent = handler.instance_variable_get(:@total_ascent)
        trackpoints_data = handler.instance_variable_get(:@trackpoints_data) || []
        session_found = handler.instance_variable_get(:@session_found) || false
        messages = handler.instance_variable_get(:@messages) || []
        
        Rails.logger.info "Parse completed. Collected #{messages.length} messages, #{trackpoints_data.length} trackpoints"
        
      rescue => e
        Rails.logger.error "Error parsing FIT file: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise "Could not parse FIT file: #{e.message}"
      end
      
      Rails.logger.info "Processed #{messages.length} messages, #{trackpoints_data.length} trackpoints"
      Rails.logger.info "Session found: #{session_found}"

      # Calculate derived values if not found
      start_time = trackpoints_data.first&.dig(:timestamp) || date
      end_time = trackpoints_data.last&.dig(:timestamp)
      
      if !duration_seconds && start_time && end_time
        duration_seconds = (end_time - start_time).to_i
      end

      # Calculate distance if not found in session
      if !distance && trackpoints_data.any?
        calculated_distance = calculate_distance(trackpoints_data)
        distance = calculated_distance * 1000 if calculated_distance # Convert km to meters
        Rails.logger.info "Calculated distance: #{distance} meters"
      end

      # Calculate elevation gain if not found
      elevation_gain = total_ascent
      if !elevation_gain && trackpoints_data.any?
        elevation_gain = calculate_elevation_gain(trackpoints_data)
        Rails.logger.info "Calculated elevation gain: #{elevation_gain} meters"
      end

      # Generate title
      if !title
        if activity_type && activity_type != 'unknown' && duration_seconds
          duration_mins = (duration_seconds / 60).to_i
          title = "#{activity_type.capitalize} - #{duration_mins}min"
        elsif activity_type && activity_type != 'unknown'
          title = "#{activity_type.capitalize} Activity"
        elsif start_time
          title = "Activity on #{start_time.strftime('%B %d, %Y')}"
        else
          title = "Activity #{Date.current.strftime('%Y-%m-%d')}"
        end
      end

      # Set defaults
      activity_type ||= 'unknown'
      date ||= Date.current

      Rails.logger.info "Final activity_type: #{activity_type}"
      Rails.logger.info "Final title: #{title}"
      Rails.logger.info "Final date: #{date}"
      Rails.logger.info "Final distance: #{distance ? (distance / 1000.0) : nil} km"
      Rails.logger.info "Final duration: #{duration_seconds} seconds"

      result = {
        activity_type: activity_type.capitalize,
        title: title,
        date: date.is_a?(Date) ? date : date.to_date,
        description: nil,
        distance: distance ? (distance / 1000.0) : nil, # Convert meters to km
        duration: duration_seconds,
        elevation: elevation_gain,
        average_power: average_power,
        average_hr: average_hr,
        start_time: start_time,
        end_time: end_time,
        trackpoints: trackpoints_data
      }

      # Clean up temp file
      temp_file.unlink

      result
    rescue StandardError => e
      Rails.logger.error "Error parsing FIT file: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @errors << "Error parsing FIT file: #{e.message}"
      nil
    ensure
      # Ensure temp file is cleaned up even if there's an error
      temp_file&.unlink
    end
  end

  def parse_fit_gz
    require 'zlib'
    require 'tempfile'

    begin
      # Decompress gzipped file
      gz_content = read_file_content
      fit_content = Zlib::GzipReader.new(StringIO.new(gz_content)).read

      # Store original file reference
      original_file = @file
      
      # Create a temporary file with the decompressed content
      temp_file = Tempfile.new(['activity', '.fit'])
      temp_file.binmode
      temp_file.write(fit_content)
      temp_file.rewind
      temp_file.close

      # Temporarily replace file with temp file path for parsing
      @file = temp_file.path
      @file_type = :fit

      # Parse as regular FIT file
      result = parse_fit

      # Restore original file reference
      @file = original_file
      @file_type = :fit_gz

      result
    rescue StandardError => e
      @errors << "Error parsing gzipped FIT file: #{e.message}"
      nil
    ensure
      # Clean up temp file
      temp_file&.unlink
    end
  end

  def read_file_content
    if @file.respond_to?(:read)
      # It's an uploaded file (ActionDispatch::Http::UploadedFile or similar)
      @file.rewind if @file.respond_to?(:rewind)
      @file.read
    elsif @file.is_a?(String) && File.exist?(@file)
      # It's a file path
      File.binread(@file)
    elsif @file.is_a?(StringIO)
      # It's a StringIO object
      @file.rewind
      @file.read
    else
      raise "Cannot read file content: #{@file.class}"
    end
  end


  def calculate_distance(trackpoints)
    return nil if trackpoints.length < 2

    total_distance = 0.0
    trackpoints.each_cons(2) do |point1, point2|
      total_distance += haversine_distance(
        point1[:latitude], point1[:longitude],
        point2[:latitude], point2[:longitude]
      )
    end
    total_distance
  end

  def haversine_distance(lat1, lon1, lat2, lon2)
    return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

    # Haversine formula to calculate distance between two points
    earth_radius_km = 6371.0

    dlat = (lat2 - lat1) * Math::PI / 180.0
    dlon = (lon2 - lon1) * Math::PI / 180.0

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * Math::PI / 180.0) *
        Math.cos(lat2 * Math::PI / 180.0) *
        Math.sin(dlon / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    earth_radius_km * c
  end

  def calculate_elevation_gain(trackpoints)
    return nil if trackpoints.empty?

    elevations = trackpoints.map { |tp| tp[:elevation] }.compact
    return nil if elevations.empty?

    gain = 0.0
    elevations.each_cons(2) do |elev1, elev2|
      gain += (elev2 - elev1) if elev2 > elev1
    end
    gain
  end
end

