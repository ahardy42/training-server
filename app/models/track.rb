# frozen_string_literal: true

class Track < ApplicationRecord
  belongs_to :activity
  has_many :trackpoints, dependent: :destroy
end

