# frozen_string_literal: true

class CreateTracks < ActiveRecord::Migration[8.0]
  def change
    create_table :tracks do |t|
      t.references :activity, null: false, foreign_key: true
      t.datetime :start_date
      t.datetime :end_date

      t.timestamps null: false
    end
  end
end

