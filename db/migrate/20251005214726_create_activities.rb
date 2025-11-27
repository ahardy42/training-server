# frozen_string_literal: true

class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity_type
      t.date :date
      t.string :title
      t.text :description
      t.decimal :distance
      t.integer :duration
      t.decimal :elevation
      t.decimal :average_power
      t.decimal :average_hr

      t.timestamps null: false
    end
  end
end

