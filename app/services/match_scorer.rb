# MatchScorer
#
# Combines all three matching layers into a single compatibility score.
#
# Weights (tunable — these are v1 defaults):
#   Fisher (Layer 1) → 55%  — neurochemical compatibility, primary engine
#   Soul   (Layer 2) → 35%  — values alignment, secondary engine
#   World  (Layer 3) → 10%  — shared interests, enrichment/texture only
#
# The World layer can never rescue a poor Fisher+Soul match.
# A combined Fisher+Soul < 40 returns a low overall score regardless of World.
#
# Usage:
#   score = MatchScorer.call(
#     fisher_a: fisher_result_a,  fisher_b: fisher_result_b,
#     soul_a:   soul_result_a,    soul_b:   soul_result_b,
#     world_a:  %i[jazz swimming coffee],
#     world_b:  %i[jazz vinyl wine]
#   )
#   score.total          # => 78
#   score.breakdown      # => { fisher: 88, soul: 74, world: 60, total: 78 }
#   score.strong?        # => true (>= 70)
#   score.viable?        # => true (>= 50)
#   score.scout_verdict  # => String

class MatchScorer

  # Minimum combined Fisher+Soul for a match to be viable,
  # regardless of world score.
  MINIMUM_FISHER_SOUL = 45

  WEIGHTS = {
    fisher: 0.55,
    soul:   0.35,
    world:  0.10
  }.freeze

  STRONG_THRESHOLD  = 70
  VIABLE_THRESHOLD  = 50

  def self.call(**kwargs)
    new(**kwargs).score
  end

  def initialize(fisher_a:, fisher_b:, soul_a:, soul_b:,
                 world_a: [], world_b: [])
    @fisher_a = fisher_a
    @fisher_b = fisher_b
    @soul_a   = soul_a
    @soul_b   = soul_b
    @world_a  = Array(world_a).map(&:to_sym)
    @world_b  = Array(world_b).map(&:to_sym)
  end

  def score
    fisher_score = @fisher_a.compatibility_with(@fisher_b)
    soul_score   = @soul_a.compatibility_with(@soul_b)
    world_score  = world_overlap_score

    # Weighted total
    weighted = (
      fisher_score * WEIGHTS[:fisher] +
      soul_score   * WEIGHTS[:soul]   +
      world_score  * WEIGHTS[:world]
    ).round

    # Floor enforcement — poor Fisher+Soul cannot be rescued by World
    fisher_soul_combined = (
      fisher_score * (WEIGHTS[:fisher] / (WEIGHTS[:fisher] + WEIGHTS[:soul])) +
      soul_score   * (WEIGHTS[:soul]   / (WEIGHTS[:fisher] + WEIGHTS[:soul]))
    ).round

    total = if fisher_soul_combined < MINIMUM_FISHER_SOUL
      # Cap the total at the combined Fisher+Soul score
      [weighted, fisher_soul_combined].min
    else
      weighted
    end

    Result.new(
      fisher: fisher_score,
      soul:   soul_score,
      world:  world_score,
      total:  total.clamp(0, 100),
      fisher_primary_a: @fisher_a.primary,
      fisher_primary_b: @fisher_b.primary,
      soul_tags_shared: (@soul_a.tags & @soul_b.tags),
      world_shared:     (@world_a & @world_b),
    )
  end

  private

  def world_overlap_score
    return 50 if @world_a.empty? || @world_b.empty?
    shared = (@world_a & @world_b).length
    max    = [@world_a.length, @world_b.length].min.to_f
    ((shared / max) * 100).round.clamp(0, 100)
  end

  # ---------- Result ----------

  Result = Struct.new(
    :fisher, :soul, :world, :total,
    :fisher_primary_a, :fisher_primary_b,
    :soul_tags_shared, :world_shared,
    keyword_init: true
  ) do

    def strong?  = total >= STRONG_THRESHOLD
    def viable?  = total >= VIABLE_THRESHOLD

    def breakdown
      { fisher: fisher, soul: soul, world: world, total: total }
    end

    # One-line Scout verdict for internal use
    def scout_verdict
      case total
      when 85..100 then "Exceptional alignment. Fisher, Soul, and World all pointing the same direction."
      when 70..84  then "Strong match. Fisher and Soul carry it. #{world_context}"
      when 55..69  then "Solid foundation. Worth a proper introduction. #{tension_note}"
      when 40..54  then "Moderate compatibility. Scout is cautious. Needs more context."
      else              "Below threshold. Not a match Scout would introduce."
      end
    end

    # Whether the world layer added meaningful signal
    def world_enriches?
      world >= 60 && !world_shared.empty?
    end

    # Human-readable world context for Scout's narrative
    def world_context
      return "" if world_shared.empty?
      "Both flagged: #{world_shared.first(3).map(&:to_s).join(', ')}."
    end

    def tension_note
      low_soul = soul < 60
      low_soul ? "Some values divergence — Scout will note it." : ""
    end
  end

end
