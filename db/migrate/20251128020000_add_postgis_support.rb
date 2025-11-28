# frozen_string_literal: true

# Migration to add PostGIS support for efficient spatial queries
# 
# Prerequisites:
# - PostGIS must be installed on your PostgreSQL server
# - On macOS: brew install postgis
# - On Ubuntu/Debian: sudo apt-get install postgresql-postgis
# - On production: Ensure PostGIS is available in your PostgreSQL installation
#
# This migration:
# 1. Enables the PostGIS extension
# 2. Adds a geometry column (POINT) to trackpoints
# 3. Creates a GIST spatial index for fast bounding box queries
# 4. Populates the geometry column from existing lat/lng data
# 5. Creates a trigger to auto-update geometry when lat/lng changes

class AddPostgisSupport < ActiveRecord::Migration[8.0]
  def up
    # Enable PostGIS extension
    # This will raise an error if PostGIS is not installed
    enable_extension 'postgis' unless extension_enabled?('postgis')
    
    # Add geometry column to trackpoints for spatial indexing
    # Using POINT type with SRID 4326 (WGS84 - standard GPS coordinates)
    add_column :trackpoints, :location, :geometry, limit: { type: 'point', srid: 4326 }
    
    # Create spatial index (GIST) on the geometry column
    # This is much faster than B-tree indexes for spatial queries
    add_index :trackpoints, :location, using: :gist, name: 'index_trackpoints_on_location_gist'
    
    # Populate the geometry column from existing latitude/longitude
    # Using ST_MakePoint(longitude, latitude) - note: PostGIS uses (lon, lat) order
    execute <<-SQL.squish
      UPDATE trackpoints
      SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
    SQL
    
    # Create a trigger to automatically update the geometry column when lat/lng changes
    # This ensures the geometry stays in sync
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION update_trackpoint_location()
      RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
          NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
        ELSE
          NEW.location = NULL;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      
      CREATE TRIGGER trackpoint_location_trigger
      BEFORE INSERT OR UPDATE ON trackpoints
      FOR EACH ROW
      EXECUTE FUNCTION update_trackpoint_location();
    SQL
  end

  def down
    # Remove trigger and function
    execute "DROP TRIGGER IF EXISTS trackpoint_location_trigger ON trackpoints"
    execute "DROP FUNCTION IF EXISTS update_trackpoint_location()"
    
    # Remove index and column
    remove_index :trackpoints, name: 'index_trackpoints_on_location_gist' if index_exists?(:trackpoints, :location, name: 'index_trackpoints_on_location_gist')
    remove_column :trackpoints, :location if column_exists?(:trackpoints, :location)
    
    # Disable extension (optional - you might want to keep it enabled)
    # disable_extension 'postgis' if extension_enabled?('postgis')
  end
end

