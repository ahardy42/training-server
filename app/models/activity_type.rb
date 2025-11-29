# frozen_string_literal: true

class ActivityType < ApplicationRecord
  has_many :activities, dependent: :restrict_with_error
  has_many :trackpoints, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  # Find or create an ActivityType by key
  # If the key doesn't exist, creates it with a humanized name
  # The key is normalized (downcased, spaces/hyphens converted to underscores)
  # @param key [String] The activity type key (e.g., 'running', 'cycling', 'E Biking')
  # @return [ActivityType] The found or created ActivityType
  def self.find_or_create_by_key(key)
    return nil if key.blank?

    normalized_key = normalize_key(key)
    return nil if normalized_key.blank?

    find_or_create_by(key: normalized_key) do |at|
      at.name = normalized_key.humanize
    end
  end

  # Normalize activity type key: downcase and convert spaces/hyphens to underscores
  # @param key [String] The activity type key to normalize
  # @return [String] The normalized key
  def self.normalize_key(key)
    return nil if key.blank?
    key.to_s.downcase.gsub(/[\s-]+/, '_').gsub(/[^a-z0-9_]/, '').gsub(/_+/, '_').gsub(/^_|_$/, '')
  end
end

