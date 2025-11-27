# frozen_string_literal: true

class CreateTrackpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :trackpoints do |t|
      t.references :track, null: false, foreign_key: true
      t.datetime :timestamp
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8
      t.decimal :heartrate
      t.decimal :power
      t.decimal :cadence
      t.decimal :elevation

      t.timestamps null: false
    end
  end
end

