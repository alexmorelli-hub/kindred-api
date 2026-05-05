# MatchComputeJob
#
# Background job to compute matches for a user against all other users.
# Triggered when a user submits their Fisher + Soul answers.
#
# Usage:
#   MatchComputeJob.perform_later(user.id)
#
class MatchComputeJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    # Find all other users who have completed their answers
    candidates = User.where.not(id: user.id)
                    .where.not(fisher_primary: nil)
                    .where.not(soul_q1: nil)

    Rails.logger.info "Computing matches for User #{user.id} against #{candidates.count} candidates"

    matches_created = 0

    candidates.find_each do |candidate|
      # Skip if match already exists
      next if Match.exists?(user_a: user, user_b: candidate)

      begin
        Match.compute_for(user, candidate)
        matches_created += 1
      rescue StandardError => e
        Rails.logger.error "Failed to compute match between User #{user.id} and #{candidate.id}: #{e.message}"
      end
    end

    Rails.logger.info "Created #{matches_created} matches for User #{user.id}"
  end
end
