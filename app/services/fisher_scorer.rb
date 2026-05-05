# FisherScorer
#
# Implements Helen Fisher's Temperament Inventory scoring.
# Four neurochemical systems: Explorer, Builder, Director, Negotiator.
#
# Each of the 16 questions maps to one of the four types.
# Answers are scored 1–4:
#   1 = strongly disagree
#   2 = disagree
#   3 = agree
#   4 = strongly agree
#
# Raw scores are normalised to percentages so all four sum to 100.
# The primary type is the highest scorer.
# Secondary type is the second highest.
#
# Usage:
#   answers = { q1: 4, q2: 2, q3: 3, ... q16: 4 }
#   result  = FisherScorer.call(answers)
#   result.primary_type        # => :explorer
#   result.scores              # => { explorer: 72, negotiator: 58, director: 38, builder: 22 }
#   result.compatibility_with(other_result)  # => 0..100

class FisherScorer

  # ---------- question → type mapping ----------
  #
  # Questions are numbered 1–16 as they appear in the onboarding quiz.
  # Each maps to one of the four Fisher types.
  #
  # Explorer  → dopamine-dominant  → novelty, curiosity, spontaneity
  # Builder   → serotonin-dominant → loyalty, routine, caution
  # Director  → testosterone-dom  → direct, decisive, systematic
  # Negotiator→ estrogen-dominant  → empathy, idealism, intuition

  QUESTION_TYPE_MAP = {
    q1:  :explorer,
    q2:  :builder,
    q3:  :director,
    q4:  :negotiator,
    q5:  :explorer,
    q6:  :builder,
    q7:  :director,
    q8:  :negotiator,
    q9:  :explorer,
    q10: :builder,
    q11: :director,
    q12: :negotiator,
    q13: :explorer,
    q14: :builder,
    q15: :director,
    q16: :negotiator
  }.freeze

  TYPES = %i[explorer builder director negotiator].freeze

  MIN_SCORE = 1
  MAX_SCORE = 4
  QUESTIONS_PER_TYPE = 4
  MAX_RAW_PER_TYPE   = MAX_SCORE * QUESTIONS_PER_TYPE  # 16
  MAX_RAW_TOTAL      = MAX_RAW_PER_TYPE * TYPES.length  # 64

  # ---------- compatibility matrix ----------
  #
  # Fisher's research identifies four pairing dynamics:
  #
  # Explorer + Explorer  → high energy, mutual spontaneity, can be unstable long-term
  # Explorer + Builder   → complementary — stability meets curiosity (very common good pairing)
  # Explorer + Director  → passionate but volatile
  # Explorer + Negotiator→ excellent — depth meets adventure
  # Builder  + Builder   → very stable, shared routine, can lack spark
  # Builder  + Director  → solid — structure meets decisiveness
  # Builder  + Negotiator→ warm and secure
  # Director + Director  → power dynamic risk, respect-driven
  # Director + Negotiator→ excellent — logic meets empathy (Fisher's best pairing)
  # Negotiator+Negotiator→ deep emotional bond, can be indecisive together

  COMPATIBILITY_MATRIX = {
    explorer:   { explorer: 72, builder: 80, director: 65, negotiator: 88 },
    builder:    { explorer: 80, builder: 70, director: 78, negotiator: 75 },
    director:   { explorer: 65, builder: 78, director: 68, negotiator: 92 },
    negotiator: { explorer: 88, builder: 75, director: 92, negotiator: 74 }
  }.freeze

  # ---------- public API ----------

  def self.call(answers)
    new(answers).score
  end

  def initialize(answers)
    @answers = answers.transform_keys(&:to_sym)
    validate!
  end

  def score
    raw   = compute_raw_scores
    pct   = normalise(raw)
    primary, secondary = pct.sort_by { |_, v| -v }.first(2).map(&:first)

    Result.new(
      scores:    pct,
      raw:       raw,
      primary:   primary,
      secondary: secondary
    )
  end

  # ---------- private ----------

  private

  def validate!
    missing = QUESTION_TYPE_MAP.keys - @answers.keys
    raise ArgumentError, "Missing answers for: #{missing.join(', ')}" if missing.any?

    invalid = @answers.select { |k, v| !QUESTION_TYPE_MAP.key?(k) }
    raise ArgumentError, "Unknown question keys: #{invalid.keys.join(', ')}" if invalid.any?

    out_of_range = @answers.select { |_, v| !v.between?(MIN_SCORE, MAX_SCORE) }
    raise ArgumentError, "Scores must be #{MIN_SCORE}–#{MAX_SCORE}. Bad values: #{out_of_range}" if out_of_range.any?
  end

  def compute_raw_scores
    TYPES.each_with_object({}) do |type, acc|
      questions = QUESTION_TYPE_MAP.select { |_, t| t == type }.keys
      acc[type] = questions.sum { |q| @answers[q] }
    end
  end

  # Normalise raw scores to percentages that sum to 100.
  # Each type's percentage is its proportion of the total raw score.
  def normalise(raw)
    total_raw = raw.values.sum.to_f
    return TYPES.each_with_object({}) { |t, h| h[t] = 25 } if total_raw.zero?

    # Calculate each as percentage of the actual total
    percentages = raw.transform_values do |v|
      ((v.to_f / total_raw) * 100).round
    end

    # Handle rounding errors - adjust the largest value to make sum exactly 100
    diff = 100 - percentages.values.sum
    if diff != 0
      max_key = percentages.max_by { |_, v| v }.first
      percentages[max_key] += diff
    end

    percentages
  end

  # ---------- Result value object ----------

  Result = Struct.new(:scores, :raw, :primary, :secondary, keyword_init: true) do
    # Returns 0..100 compatibility score between two Result objects.
    # Uses the base matrix for primary×primary then boosts by secondary alignment.
    def compatibility_with(other)
      base = COMPATIBILITY_MATRIX.dig(primary, other.primary) || 50

      # Secondary type modifier: ±5 based on secondary alignment
      secondary_bonus = COMPATIBILITY_MATRIX.dig(secondary, other.secondary) || 50
      modifier = ((secondary_bonus - 70) / 10.0).round  # –3..+3 roughly

      # Score magnitude modifier: stronger primaries → stronger signal
      # If both are overwhelmingly one type, weight that more
      primary_strength      = scores[primary].to_f       / 100
      other_primary_strength = other.scores[other.primary].to_f / 100
      strength_factor = ((primary_strength + other_primary_strength) / 2 * 10).round - 4

      raw_score = base + modifier + strength_factor
      raw_score.clamp(0, 100)
    end

    # Human-readable description of the primary type.
    def primary_description
      DESCRIPTIONS[primary]
    end

    def secondary_description
      DESCRIPTIONS[secondary]
    end

    # Returns the type percentages sorted high → low for display.
    def sorted_scores
      scores.sort_by { |_, v| -v }.to_h
    end

    DESCRIPTIONS = {
      explorer:   "Curious, spontaneous, and novelty-seeking. Dopamine-driven — you're energised by new ideas, experiences, and possibilities. Restless in the best way.",
      builder:    "Loyal, conscientious, and steady. Serotonin-driven — you value tradition, routine, and reliability. People count on you because you deliver.",
      director:   "Direct, decisive, and analytical. Testosterone-influenced — you think in systems, move fast, and lead without needing approval.",
      negotiator: "Empathetic, intuitive, and idealistic. Estrogen-influenced — you read people well, think long-term, and bring depth to every connection."
    }.freeze
  end

end
