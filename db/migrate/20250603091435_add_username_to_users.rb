class AddUsernameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :username, :string
     add_index :users, :username, unique: true 
  end
end
