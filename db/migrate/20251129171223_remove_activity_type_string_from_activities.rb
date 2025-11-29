class RemoveActivityTypeStringFromActivities < ActiveRecord::Migration[8.0]
  def up
    # Remove indexes that reference activity_type column
    remove_index :activities, name: "index_activities_on_activity_type" if index_exists?(:activities, :activity_type, name: "index_activities_on_activity_type")
    remove_index :activities, name: "index_activities_on_user_id_and_activity_type" if index_exists?(:activities, [:user_id, :activity_type], name: "index_activities_on_user_id_and_activity_type")
    
    # Remove the activity_type string column
    remove_column :activities, :activity_type, :string
  end

  def down
    # Re-add the column
    add_column :activities, :activity_type, :string
    
    # Re-add the indexes
    add_index :activities, :activity_type, name: "index_activities_on_activity_type"
    add_index :activities, [:user_id, :activity_type], name: "index_activities_on_user_id_and_activity_type"
  end
end
