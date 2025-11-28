class OptimizeTrackpointsStorage < ActiveRecord::Migration[8.0]
  def up
    # Change DECIMAL to REAL (float4) for coordinates and elevation
    # REAL uses 4 bytes vs DECIMAL which uses variable length (up to 17 bytes)
    # REAL precision (6-7 decimal digits) is sufficient for GPS coordinates
    change_column :trackpoints, :latitude, :real
    change_column :trackpoints, :longitude, :real
    change_column :trackpoints, :elevation, :real
    
    # Change DECIMAL to SMALLINT for heartrate and cadence
    # These are typically 0-255, so SMALLINT (2 bytes) is perfect
    change_column :trackpoints, :heartrate, :smallint
    change_column :trackpoints, :cadence, :smallint
    
    # Change DECIMAL to INTEGER for power
    # Power values are typically integers, INTEGER (4 bytes) is better than DECIMAL
    change_column :trackpoints, :power, :integer
    
    # Remove created_at and updated_at if not needed
    # These add 16 bytes per row (8 bytes each)
    # Uncomment the following lines if you don't need these timestamps:
    # remove_column :trackpoints, :created_at
    # remove_column :trackpoints, :updated_at
  end

  def down
    # Revert to DECIMAL types
    change_column :trackpoints, :latitude, :decimal, precision: 10, scale: 8
    change_column :trackpoints, :longitude, :decimal, precision: 11, scale: 8
    change_column :trackpoints, :elevation, :decimal
    change_column :trackpoints, :heartrate, :decimal
    change_column :trackpoints, :cadence, :decimal
    change_column :trackpoints, :power, :decimal
    
    # Re-add timestamps if they were removed
    # add_column :trackpoints, :created_at, :datetime, null: false
    # add_column :trackpoints, :updated_at, :datetime, null: false
  end
end
