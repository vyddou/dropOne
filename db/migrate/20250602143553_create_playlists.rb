class CreatePlaylists < ActiveRecord::Migration[7.1]
  def change
    create_table :playlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :type
      t.boolean :is_public
      t.text :ai_prompt_details

      t.timestamps
    end
  end
end
