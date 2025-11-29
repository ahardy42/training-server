class AddActivityTypeToActivities < ActiveRecord::Migration[8.0]
  def change
    add_reference :activities, :activity_type, null: true, foreign_key: true
  end
end
