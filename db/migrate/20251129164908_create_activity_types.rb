class CreateActivityTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_types do |t|
      t.string :key, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :activity_types, :key, unique: true
  end
end
