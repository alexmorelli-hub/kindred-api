class Match < ApplicationRecord
  belongs_to :user_a, class_name: 'User'
  belongs_to :user_b, class_name: 'User'

  validates :fisher_score, :soul_score, :world_score, :total_score,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :status, inclusion: { in: %w[pending shown liked matched passed] }
  validates :user_a_id, uniqueness: { scope: :user_b_id }

  validate :users_are_different

  scope :for_user, ->(user) { where(user_a: user).or(where(user_b: user)) }
  scope :viable, -> { where('total_score >= 50') }
  scope :strong, -> { where('total_score >= 70') }
  scope :pending, -> { where(status: 'pending') }
  scope :by_score, -> { order(total_score: :desc) }

  # Compute match scores using MatchScorer
  def self.compute_for(user_a, user_b)
    result = MatchScorer.call(
      fisher_a: user_a.fisher_result,
      fisher_b: user_b.fisher_result,
      soul_a: user_a.soul_result,
      soul_b: user_b.soul_result,
      world_a: user_a.world_tags,
      world_b: user_b.world_tags
    )

    create!(
      user_a: user_a,
      user_b: user_b,
      fisher_score: result.fisher,
      soul_score: result.soul,
      world_score: result.world,
      total_score: result.total,
      status: 'pending',
      scout_metadata: {
        verdict: result.scout_verdict,
        viable: result.viable?,
        strong: result.strong?,
        world_enriches: result.world_enriches?,
        soul_tags_shared: result.soul_tags_shared.map(&:to_s),
        world_shared: result.world_shared.map(&:to_s)
      }
    )
  end

  def viable?
    total_score >= 50
  end

  def strong?
    total_score >= 70
  end

  def breakdown
    {
      fisher: fisher_score,
      soul: soul_score,
      world: world_score,
      total: total_score
    }
  end

  private

  def users_are_different
    if user_a_id == user_b_id
      errors.add(:base, 'Cannot match a user with themselves')
    end
  end
end
