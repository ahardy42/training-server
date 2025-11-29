class AddMetricsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ftp, :integer
    add_column :users, :lt_hr, :integer
    add_column :users, :max_hr, :integer
  end
end
