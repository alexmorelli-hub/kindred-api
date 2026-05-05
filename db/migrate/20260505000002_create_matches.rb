class CreateMatches < ActiveRecord::Migration[7.2]
  def change
    create_table :matches do |t|
      # The two users being matched
      t.references :user_a, null: false, foreign_key: { to_table: :users }
      t.references :user_b, null: false, foreign_key: { to_table: :users }

      # Layer scores (0-100)
      t.integer :fisher_score, null: false
      t.integer :soul_score, null: false
      t.integer :world_score, null: false
      t.integer :total_score, null: false

      # Match status
      # pending: computed but not yet shown
      # shown: displayed to user_a
      # liked: user_a liked user_b
      # matched: mutual like
      # passed: user_a passed on user_b
      t.string :status, default: 'pending', null: false

      # Scout metadata
      t.jsonb :scout_metadata, default: {}

      t.timestamps
    end

    add_index :matches, [:user_a_id, :user_b_id], unique: true
    add_index :matches, [:user_b_id, :user_a_id]
    add_index :matches, :total_score
    add_index :matches, :status
    add_index :matches, [:user_a_id, :status, :total_score]
  end
end
