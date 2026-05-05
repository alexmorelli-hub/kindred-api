class UsersController < ApplicationController
  # POST /users/:id/answers
  #
  # Submit Fisher + Soul answers for a user.
  # Triggers background match computation.
  #
  # Params:
  #   fisher_answers: { q1: 3, q2: 4, q3: 2, ... q16: 3 }
  #   soul_answers: { q1: "curious", q2: "show_up", q3: "close", q4: "say_it_once", q5: "ready" }
  #   world_tags: ["jazz", "swimming", "coffee"]
  #
  def submit_answers
    user = User.find(params[:id])

    # Update Fisher answers
    fisher_params = params.require(:fisher_answers).permit(
      :q1, :q2, :q3, :q4, :q5, :q6, :q7, :q8,
      :q9, :q10, :q11, :q12, :q13, :q14, :q15, :q16
    )
    fisher_params.each do |key, value|
      user.send(:"fisher_#{key}=", value.to_i)
    end

    # Update Soul answers
    soul_params = params.require(:soul_answers).permit(:q1, :q2, :q3, :q4, :q5, :q5b)
    soul_params.each do |key, value|
      user.send(:"soul_#{key}=", value)
    end

    # Update World tags
    if params[:world_tags].present?
      user.world_tags = params[:world_tags]
    end

    if user.save
      # Trigger background match computation
      MatchComputeJob.perform_later(user.id)

      render json: {
        success: true,
        user: {
          id: user.id,
          fisher_primary: user.fisher_primary,
          fisher_secondary: user.fisher_secondary,
          fisher_scores: user.fisher_scores,
          soul_tags: user.soul_tags,
          world_tags: user.world_tags
        },
        message: 'Answers submitted. Computing matches in background.'
      }, status: :ok
    else
      render json: {
        success: false,
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /users/:id/matches
  #
  # Fetch matches for a user, ordered by score.
  #
  def matches
    user = User.find(params[:id])
    matches = Match.where(user_a: user)
                   .viable
                   .by_score
                   .includes(:user_b)
                   .limit(50)

    render json: {
      matches: matches.map do |match|
        {
          id: match.id,
          user: {
            id: match.user_b.id,
            name: match.user_b.name,
            age: match.user_b.age,
            location: match.user_b.location,
            fisher_primary: match.user_b.fisher_primary,
            soul_tags: match.user_b.soul_tags.first(3)
          },
          scores: match.breakdown,
          scout_verdict: match.scout_metadata['verdict'],
          strong: match.strong?,
          status: match.status
        }
      end
    }
  end
end
