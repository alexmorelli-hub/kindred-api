# SoulScorer
#
# Layer 2 of Kindred's matching system.
# Soul questions reveal values, readiness, and emotional orientation.
#
# There are 5 Soul questions. Questions 1–4 are universal.
# Question 5 (readiness fork) has two paths:
#   :ready     → straight to scoring
#   :working   → one additional MBS (Mind/Body/Soul) question
#
# Soul scores are categorical, not numeric.
# Each answer maps to one or more value tags.
# Compatibility is measured by tag overlap between two Soul profiles.
#
# Usage:
#   answers = { q1: :curious, q2: :show_up, q3: :close, q4: :say_it_once, q5: :ready }
#   result  = SoulScorer.call(answers, fisher_type: :explorer)
#   result.tags               # => [:depth_seeker, :reliable, :family_anchored, :boundaried, :ready]
#   result.compatibility_with(other_result)  # => 0..100

class SoulScorer

  # ---------- question definitions ----------
  #
  # Each question key maps to an array of valid answer keys.
  # Answers are mapped to value tags below.

  QUESTIONS = {
    # Q1 — "How would you describe yourself?"
    q1: %i[curious loyal decisive thoughtful],

    # Q2 — "Your mate calls at 2am — what do you do?"
    q2: %i[show_up selective fix_it need_context],

    # Q3 — "What's your relationship with the family you grew up with?"
    q3: %i[close complicated own_family functional],

    # Q4 — "Someone keeps pushing past something you've made clear — what happens?"
    q4: %i[say_it_once let_it_build understand first absorb],

    # Q5 — Readiness fork
    q5: %i[ready working],

    # Q5b — MBS question (only shown if q5 == :working)
    q5b: %i[mind body soul all_three],
  }.freeze

  # Value tags assigned per answer
  ANSWER_TAGS = {
    # q1 — self-concept
    curious:      %i[depth_seeker novelty_driven open],
    loyal:        %i[committed reliable steady],
    decisive:     %i[action_oriented self_assured],
    thoughtful:   %i[depth_seeker empathetic introspective],

    # q2 — loyalty in action
    show_up:      %i[reliable unconditional present],
    selective:    %i[boundaried earned_trust],
    fix_it:       %i[problem_solver practical],
    need_context: %i[cautious considered],

    # q3 — family blueprint
    close:        %i[family_anchored grounded],
    complicated:  %i[self_aware independent repair_work],
    own_family:   %i[chosen_family independent],
    functional:   %i[private_processor low_drama],

    # q4 — limit enforcement
    say_it_once:  %i[boundaried direct self_respecting],
    let_it_build: %i[patience conflict_averse],
    understand_first: %i[empathetic curious considered],
    absorb:       %i[peace_keeper conflict_averse],

    # q5 — readiness
    ready:        %i[present stable arrived],
    working:      %i[self_aware growth_oriented],

    # q5b — growth focus
    mind:         %i[intellectual_growth],
    body:         %i[physical_growth],
    soul:         %i[emotional_growth spiritual],
    all_three:    %i[holistic_growth ambitious],
  }.freeze

  # Tags that strongly indicate compatibility when shared
  HIGH_VALUE_TAGS = %i[
    depth_seeker reliable boundaried self_respecting
    self_aware empathetic present committed
  ].freeze

  # Tags that indicate potential friction when both users share them
  # (not dealbreakers — but Scout weights these)
  FRICTION_TAGS = %i[
    conflict_averse peace_keeper
  ].freeze

  # ---------- Fisher-type question tailoring ----------
  #
  # The phrasing of q1 changes per Fisher type, but the answer
  # keys stay the same — just the language presented to the user differs.
  # This hash provides the tailored prompt text for each type.

  TAILORED_Q1 = {
    explorer:   "How would you describe yourself?",
    builder:    "What do people who know you well say about you?",
    director:   "What drives the decisions you make?",
    negotiator: "What do you bring to the people closest to you?",
  }.freeze

  # ---------- public API ----------

  def self.call(answers, fisher_type: nil)
    new(answers, fisher_type: fisher_type).score
  end

  def initialize(answers, fisher_type: nil)
    @answers     = answers.transform_keys(&:to_sym)
    @fisher_type = fisher_type&.to_sym
    validate!
  end

  def score
    tags = collect_tags
    Result.new(tags: tags, fisher_type: @fisher_type, raw_answers: @answers)
  end

  # ---------- private ----------

  private

  def validate!
    required = [:q1, :q2, :q3, :q4, :q5]
    required << :q5b if @answers[:q5] == :working

    missing = required - @answers.keys
    raise ArgumentError, "Missing answers: #{missing.join(', ')}" if missing.any?

    @answers.each do |key, val|
      valid = QUESTIONS[key]
      next unless valid
      unless valid.include?(val.to_sym)
        raise ArgumentError, "Invalid answer #{val.inspect} for #{key}. Valid: #{valid.join(', ')}"
      end
    end
  end

  def collect_tags
    relevant_keys = [:q1, :q2, :q3, :q4, :q5]
    relevant_keys << :q5b if @answers[:q5] == :working

    tags = relevant_keys.flat_map do |key|
      answer = @answers[key]&.to_sym
      ANSWER_TAGS[answer] || []
    end

    tags.uniq
  end

  # ---------- Result value object ----------

  Result = Struct.new(:tags, :fisher_type, :raw_answers, keyword_init: true) do

    # Core compatibility: tag overlap, weighted by tag importance.
    # Returns 0..100.
    def compatibility_with(other)
      return 50 if tags.empty? || other.tags.empty?

      shared = tags & other.tags

      # Base score from percentage overlap
      max_possible = [tags.length, other.tags.length].min.to_f
      base = (shared.length / max_possible * 100).round

      # Bonus for high-value shared tags
      hv_shared  = shared & HIGH_VALUE_TAGS
      hv_bonus   = hv_shared.length * 4

      # Friction penalty — if both share conflict-averse tags,
      # they may struggle to surface problems
      friction  = shared & FRICTION_TAGS
      friction_penalty = friction.length * 10

      raw = base + hv_bonus - friction_penalty
      raw.clamp(0, 100)
    end

    # Key character signals Scout uses in introductions
    def character_signals
      signal_map = {
        depth_seeker:     "Goes deep — prefers one real conversation to ten surface ones.",
        reliable:         "Shows up. Doesn't track the ledger, just delivers.",
        boundaried:       "Knows their limits and holds them. Says it once.",
        self_respecting:  "Doesn't stay in things that don't work. Knows their worth.",
        self_aware:       "Working on themselves — not finished, but honest about it.",
        empathetic:       "Reads people well. Notices things others miss.",
        family_anchored:  "Comes back to where they started. Knows what that's worth.",
        independent:      "Built their own version of what matters. Doesn't need approval.",
        committed:        "Once in, fully in. Loyalty is a decision, not a feeling.",
        present:          "Here. Ready. Not carrying too much from before.",
        growth_oriented:  "Actively building — knows exactly what chapter they're in.",
      }

      tags.filter_map { |t| signal_map[t] }.first(3)
    end

    # Readable summary for Scout's introduction narrative
    def narrative_fragment
      signals = character_signals
      return nil if signals.empty?
      signals.join(" ")
    end
  end

end
