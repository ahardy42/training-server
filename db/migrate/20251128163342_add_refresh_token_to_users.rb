class AddRefreshTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :refresh_token, :string
    add_index :users, :refresh_token, where: "refresh_token IS NOT NULL"
  end
end
