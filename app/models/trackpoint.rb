# frozen_string_literal: true

class Trackpoint < ApplicationRecord
  belongs_to :track
  belongs_to :activity_type, optional: true
end

