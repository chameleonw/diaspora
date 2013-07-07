class CreateProposals < ActiveRecord::Migration
  def change
    create_table :proposals do |t|
      t.integer :recommendation_id
      t.string :handle
      t.decimal :rating
      t.string :guid

      t.timestamps
    end
  end

  def self.down
    drop_table :proposals
  end
end
