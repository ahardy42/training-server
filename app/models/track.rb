# frozen_string_literal: true

require 'polylines'

class Track < ApplicationRecord
  belongs_to :activity
  has_many :trackpoints, dependent: :destroy

  # Generate and save an encoded polyline from trackpoints
  # This should be called after trackpoints are created or updated
  def generate_polyline!
    # Get all trackpoints with valid coordinates, ordered by timestamp
    points = trackpoints
      .where.not(latitude: nil, longitude: nil)
      .order(:timestamp)
      .pluck(:latitude, :longitude)

    # If no valid points, clear the polyline
    if points.empty?
      update_column(:polyline, nil)
      return
    end

    # Encode the points using the polylines gem
    # The gem expects an array of [lat, lon] pairs
    encoded = Polylines::Encoder.encode_points(points)

    # Save the encoded polyline
    update_column(:polyline, encoded)
  end
end

