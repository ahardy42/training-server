# frozen_string_literal: true

class Activity < ApplicationRecord
  belongs_to :user
  has_one :track, dependent: :destroy
end

