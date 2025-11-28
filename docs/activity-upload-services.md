# Activity Upload Services

This document describes the activity file upload and parsing services in the Training Server application.

## Overview

The application supports uploading fitness activity files in multiple formats:
- **GPX** (GPS Exchange Format) - XML-based format for GPS data
- **FIT** (Flexible and Interoperable Data Transfer) - Binary format used by Garmin and other devices
- **FIT.gz** - Gzipped FIT files

The `ActivityFileParser` service handles parsing these file formats and extracting activity data, trackpoints, and metrics.

## Service Architecture

### ActivityFileParser

**Location**: `app/services/activity_file_parser.rb`

The `ActivityFileParser` class is responsible for:
1. Detecting file type (GPX, FIT, or FIT.gz)
2. Parsing the file content
3. Extracting activity metadata (type, title, date, distance, duration, etc.)
4. Extracting trackpoints (GPS coordinates, elevation, heart rate, power, cadence)
5. Calculating derived metrics (distance, elevation gain)

### Usage

```ruby
parser = ActivityFileParser.new(file)
parsed_data = parser.parse

if parser.errors.any?
  # Handle errors
  puts parser.errors
else
  # Use parsed_data
  activity_type = parsed_data[:activity_type]
  trackpoints = parsed_data[:trackpoints]
end
```

## Supported File Formats

### GPX Files

GPX (GPS Exchange Format) is an XML-based format commonly used for GPS data.

#### Supported Elements

- **Track Name** (`<name>`): Used as activity title
- **Track Description** (`<desc>`): Used as activity description
- **Track Type** (`<type>`): Used as activity type
- **Trackpoints** (`<trkpt>`): GPS coordinates with:
  - Latitude (`lat` attribute)
  - Longitude (`lon` attribute)
  - Elevation (`<ele>` element)
  - Timestamp (`<time>` element)

#### Parsing Process

1. Parse XML using Nokogiri
2. Extract track metadata from the first `<trk>` element
3. Extract all trackpoints from all `<trkseg>` segments
4. Calculate distance using Haversine formula between consecutive points
5. Calculate elevation gain by summing positive elevation differences
6. Calculate duration from first to last trackpoint timestamp

#### Example GPX Structure

```xml
<gpx>
  <trk>
    <name>Morning Ride</name>
    <type>cycling</type>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194">
        <ele>100.0</ele>
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
```

### FIT Files

FIT (Flexible and Interoperable Data Transfer) is a binary format developed by Garmin.

#### Supported Data Types

The parser extracts data from multiple FIT message types:

- **File ID** (`file_id`): File metadata and creation time
- **Activity** (`activity`): Activity-level metadata
- **Session** (`session`): Session summary data including:
  - Sport type (mapped to activity type)
  - Total distance
  - Total elapsed time
  - Average power
  - Average heart rate
  - Total ascent
- **Record** (`record`): Individual trackpoints with:
  - Timestamp
  - Position (latitude/longitude)
  - Altitude
  - Heart rate
  - Power
  - Cadence
  - Speed
  - Distance

#### Sport Type Mapping

FIT files use numeric sport codes. The parser maps these to activity types:

| Code | Activity Type |
|------|---------------|
| 0 | generic |
| 1 | running |
| 2 | cycling |
| 5 | swimming |
| 11 | walking |
| 17 | hiking |
| ... | (see full mapping in code) |

#### Parsing Process

1. Read FIT file using `rubyfit` gem
2. Process messages through callback handlers:
   - `on_file_id`: Extract file creation time
   - `on_activity`: Extract activity metadata
   - `on_session`: Extract session summary (sport, distance, duration, etc.)
   - `on_record`: Extract individual trackpoints
3. Calculate derived metrics if not present in session data
4. Generate activity title from sport type and duration

### Gzipped FIT Files

FIT.gz files are gzipped FIT files. The parser:

1. Decompresses the file using `Zlib::GzipReader`
2. Temporarily stores decompressed content
3. Parses as a regular FIT file
4. Cleans up temporary files

## Parsed Data Structure

The parser returns a hash with the following structure:

```ruby
{
  activity_type: "cycling",        # String: Type of activity
  title: "Morning Ride",           # String: Activity title
  date: Date.new(2024, 1, 15),     # Date: Activity date
  description: "A nice ride",      # String or nil: Description
  distance: 25.5,                  # Float or nil: Distance in kilometers
  duration: 3600,                  # Integer or nil: Duration in seconds
  elevation: 450.0,                # Float or nil: Elevation gain in meters
  average_power: 180.0,            # Float or nil: Average power in watts
  average_hr: 145.0,               # Float or nil: Average heart rate in BPM
  start_time: Time,                # Time or nil: Start timestamp
  end_time: Time,                  # Time or nil: End timestamp
  trackpoints: [                   # Array: Trackpoint data
    {
      timestamp: Time,
      latitude: 37.7749,
      longitude: -122.4194,
      elevation: 100.0,
      heartrate: 140.0,            # Optional
      power: 175.0,                # Optional
      cadence: 85.0,               # Optional
      speed: 25.5,                 # Optional (FIT only)
      distance: 1000.0             # Optional (FIT only)
    }
  ]
}
```

## Integration with Controllers

### Web Interface Upload

The `ActivitiesController` (`app/controllers/activities_controller.rb`) handles file uploads through the web interface:

#### Single File Upload

```ruby
def create_from_file
  parser = ActivityFileParser.new(params[:activity_file])
  parsed_data = parser.parse
  
  if parser.errors.any?
    # Handle errors
  else
    # Create activity from parsed_data
  end
end
```

#### Bulk Upload (ZIP)

The controller supports bulk uploads via ZIP files:

1. Extract ZIP file to temporary directory
2. Filter for supported file types (.gpx, .fit, .fit.gz)
3. Skip system files (__MACOSX, hidden files)
4. Process each file individually
5. Create activities for successfully parsed files
6. Report results (success, skipped, failed)

**Supported ZIP Structure**:
- Flat structure (all files in root)
- Nested directories (files extracted and processed)
- Mixed file types (GPX and FIT files together)

### API Upload

The API controller (`app/controllers/api/v1/activities_controller.rb`) accepts activity data directly in JSON format. File uploads through the API would need to be handled by:

1. Client-side parsing of files
2. Sending parsed data as JSON
3. Or implementing multipart/form-data file upload endpoint

## Calculated Metrics

### Distance Calculation

Distance is calculated using the **Haversine formula** to compute the great-circle distance between consecutive trackpoints:

```ruby
def haversine_distance(lat1, lon1, lat2, lon2)
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
```

The total distance is the sum of distances between all consecutive trackpoints.

### Elevation Gain Calculation

Elevation gain is calculated by:
1. Extracting all elevation values from trackpoints
2. Comparing consecutive elevations
3. Summing positive differences (uphill segments)

```ruby
def calculate_elevation_gain(trackpoints)
  elevations = trackpoints.map { |tp| tp[:elevation] }.compact
  gain = 0.0
  elevations.each_cons(2) do |elev1, elev2|
    gain += (elev2 - elev1) if elev2 > elev1
  end
  gain
end
```

## Error Handling

The parser maintains an `errors` array that collects error messages:

```ruby
parser = ActivityFileParser.new(file)
parsed_data = parser.parse

if parser.errors.any?
  parser.errors.each do |error|
    puts "Error: #{error}"
  end
end
```

### Common Errors

- **Unsupported file type**: File extension not recognized
- **Invalid file**: File cannot be read or parsed
- **No tracks found**: GPX file contains no track data
- **Parse errors**: XML parsing errors (GPX) or binary format errors (FIT)

## Performance Considerations

### Batch Processing

Trackpoints are inserted in batches using `insert_all` for better performance:

```ruby
Trackpoint.insert_all(trackpoints_to_create)
```

### Memory Management

- Files are read into memory for parsing
- Temporary files are cleaned up after processing
- Large files may require streaming processing (not currently implemented)

### Optimization Opportunities

1. **Streaming Parsing**: For very large files, parse and insert trackpoints incrementally
2. **Background Processing**: Move file parsing to background jobs for large uploads
3. **Caching**: Cache parsed metadata to avoid re-parsing
4. **Compression**: Store trackpoints in compressed format in database

## Database Storage

### Activity Model

Activities are stored in the `activities` table with fields:
- `activity_type`, `title`, `date`, `description`
- `distance`, `duration`, `elevation`
- `average_power`, `average_hr`

### Track Model

Tracks are stored in the `tracks` table with:
- `start_date`, `end_date`
- Foreign key to `activities`

### Trackpoint Model

Trackpoints are stored in the `trackpoints` table with:
- `timestamp`, `latitude`, `longitude`
- `elevation`, `heartrate`, `power`, `cadence`
- PostGIS `location` geometry column (for spatial queries)
- Foreign key to `tracks`

## Example Usage

### Web Interface

```ruby
# In ActivitiesController
def create_from_file
  parser = ActivityFileParser.new(params[:activity_file])
  parsed_data = parser.parse

  if parser.errors.any?
    flash.now[:alert] = parser.errors.join(", ")
    return
  end

  activity = current_user.activities.create!(
    activity_type: parsed_data[:activity_type],
    title: parsed_data[:title],
    date: parsed_data[:date],
    distance: parsed_data[:distance],
    duration: parsed_data[:duration],
    elevation: parsed_data[:elevation]
  )

  if parsed_data[:trackpoints].any?
    track = activity.create_track!(
      start_date: parsed_data[:start_time],
      end_date: parsed_data[:end_time]
    )

    trackpoints_to_create = parsed_data[:trackpoints].map do |tp|
      {
        track_id: track.id,
        timestamp: tp[:timestamp],
        latitude: tp[:latitude],
        longitude: tp[:longitude],
        elevation: tp[:elevation],
        # ... other fields
      }
    end

    Trackpoint.insert_all(trackpoints_to_create)
  end
end
```

### Direct Service Usage

```ruby
# Parse a file
file = File.open('activity.gpx')
parser = ActivityFileParser.new(file)
data = parser.parse

# Access parsed data
puts "Activity: #{data[:title]}"
puts "Distance: #{data[:distance]} km"
puts "Trackpoints: #{data[:trackpoints].count}"
```

## Testing

When testing file uploads:

1. Use sample GPX/FIT files from test fixtures
2. Test error handling with invalid files
3. Test bulk uploads with ZIP files containing multiple activities
4. Verify all trackpoints are correctly extracted and stored
5. Verify calculated metrics (distance, elevation) are accurate

## Future Enhancements

Potential improvements to the upload service:

1. **Additional Formats**: Support TCX, KML, and other GPS formats
2. **File Validation**: Pre-validate files before processing
3. **Progress Tracking**: Report upload progress for large files
4. **Duplicate Detection**: Detect and handle duplicate activities
5. **Metadata Extraction**: Extract additional metadata (device info, weather, etc.)
6. **Streaming Upload**: Support streaming uploads for very large files
7. **Background Jobs**: Process large files asynchronously

