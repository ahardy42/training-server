# frozen_string_literal: true

class ActivityType < ApplicationRecord
  has_many :activities, dependent: :restrict_with_error
  has_many :trackpoints, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end

