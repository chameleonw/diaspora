class CreateRecommendations < ActiveRecord::Migration
  def change
    create_table :recommendations do |t|
      t.string :guid
      t.integer :author_id
      t.integer :recipient_id
      t.string :user_handle
      t.decimal :rating

      t.timestamps
    end
  end

  def self.down
    drop_table :recommendations
  end
end
