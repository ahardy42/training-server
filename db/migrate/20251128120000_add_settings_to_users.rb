# frozen_string_literal: true

class AddSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :units, :string
    add_column :users, :name, :string
    add_column :users, :date_of_birth, :date
    add_column :users, :height, :decimal, precision: 5, scale: 2
    add_column :users, :weight, :decimal, precision: 5, scale: 2
  end
end

