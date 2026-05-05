class User < ApplicationRecord
  has_many :matches_as_a, class_name: 'Match', foreign_key: 'user_a_id', dependent: :destroy
  has_many :matches_as_b, class_name: 'Match', foreign_key: 'user_b_id', dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  # Fisher validations
  (1..16).each do |i|
    validates :"fisher_q#{i}", inclusion: { in: 1..4 }, allow_nil: false
  end

  # Soul validations
  validates :soul_q1, inclusion: { in: %w[curious loyal decisive thoughtful] }
  validates :soul_q2, inclusion: { in: %w[show_up selective fix_it need_context] }
  validates :soul_q3, inclusion: { in: %w[close complicated own_family functional] }
  validates :soul_q4, inclusion: { in: %w[say_it_once let_it_build understand_first absorb] }
  validates :soul_q5, inclusion: { in: %w[ready working] }

  before_save :compute_fisher_scores, if: :fisher_answers_changed?
  before_save :compute_soul_tags, if: :soul_answers_changed?

  # Build Fisher answers hash for FisherScorer
  def fisher_answers
    (1..16).each_with_object({}) do |i, hash|
      hash[:"q#{i}"] = send(:"fisher_q#{i}")
    end
  end

  # Build Soul answers hash for SoulScorer
  def soul_answers
    {
      q1: soul_q1&.to_sym,
      q2: soul_q2&.to_sym,
      q3: soul_q3&.to_sym,
      q4: soul_q4&.to_sym,
      q5: soul_q5&.to_sym,
      q5b: soul_q5b&.to_sym
    }.compact
  end

  # Compute Fisher scores using FisherScorer
  def compute_fisher_scores
    result = FisherScorer.call(fisher_answers)
    self.fisher_primary = result.primary.to_s
    self.fisher_secondary = result.secondary.to_s
    self.fisher_scores = result.scores.stringify_keys
  end

  # Compute Soul tags using SoulScorer
  def compute_soul_tags
    result = SoulScorer.call(soul_answers, fisher_type: fisher_primary&.to_sym)
    self.soul_tags = result.tags.map(&:to_s)
  end

  # Get cached FisherScorer::Result
  def fisher_result
    @fisher_result ||= FisherScorer::Result.new(
      scores: fisher_scores.symbolize_keys,
      raw: nil,
      primary: fisher_primary.to_sym,
      secondary: fisher_secondary.to_sym
    )
  end

  # Get cached SoulScorer::Result
  def soul_result
    @soul_result ||= SoulScorer::Result.new(
      tags: soul_tags.map(&:to_sym),
      fisher_type: fisher_primary&.to_sym,
      raw_answers: soul_answers
    )
  end

  private

  def fisher_answers_changed?
    (1..16).any? { |i| send(:"fisher_q#{i}_changed?") }
  end

  def soul_answers_changed?
    %w[soul_q1 soul_q2 soul_q3 soul_q4 soul_q5 soul_q5b].any? { |attr| send(:"#{attr}_changed?") }
  end
end
