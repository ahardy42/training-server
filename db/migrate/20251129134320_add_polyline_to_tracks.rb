class AddPolylineToTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :tracks, :polyline, :string
  end
end
