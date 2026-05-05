class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      # Fisher answers — 16 questions, stored as integers 1-4
      t.integer :fisher_q1, null: false
      t.integer :fisher_q2, null: false
      t.integer :fisher_q3, null: false
      t.integer :fisher_q4, null: false
      t.integer :fisher_q5, null: false
      t.integer :fisher_q6, null: false
      t.integer :fisher_q7, null: false
      t.integer :fisher_q8, null: false
      t.integer :fisher_q9, null: false
      t.integer :fisher_q10, null: false
      t.integer :fisher_q11, null: false
      t.integer :fisher_q12, null: false
      t.integer :fisher_q13, null: false
      t.integer :fisher_q14, null: false
      t.integer :fisher_q15, null: false
      t.integer :fisher_q16, null: false

      # Fisher computed scores (cached from FisherScorer)
      t.string :fisher_primary
      t.string :fisher_secondary
      t.jsonb :fisher_scores, default: {}

      # Soul answers — stored as strings (symbolic answer keys)
      t.string :soul_q1
      t.string :soul_q2
      t.string :soul_q3
      t.string :soul_q4
      t.string :soul_q5
      t.string :soul_q5b  # Optional: only if q5 == 'working'

      # Soul computed results (cached from SoulScorer)
      t.string :soul_tags, array: true, default: []

      # World layer — interests/activities
      t.string :world_tags, array: true, default: []

      # Basic profile
      t.string :name
      t.string :email
      t.integer :age
      t.string :location

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :fisher_primary
    add_index :users, :soul_tags, using: :gin
    add_index :users, :world_tags, using: :gin
  end
end
