# Kindred API - Setup Complete

## What's Built

### ✅ Matching Engine (Tested - All 53 tests pass)
- **FisherScorer** — Helen Fisher's 4-type personality system (Explorer/Builder/Director/Negotiator)
- **SoulScorer** — Values-based compatibility with tag matching
- **MatchScorer** — Weighted combination: Fisher 55%, Soul 35%, World 10%

### ✅ Rails API Structure
- **User Model** — Stores Fisher answers (16 questions), Soul answers (5-6 questions), World tags
- **Match Model** — Stores fisher_score, soul_score, world_score, total_score, status
- **MatchComputeJob** — Sidekiq background job to compute matches
- **UsersController** — API endpoints for submitting answers and fetching matches

## Project Structure

```
kindred-api/
├── app/
│   ├── controllers/
│   │   └── users_controller.rb          # POST /users/:id/answers, GET /users/:id/matches
│   ├── jobs/
│   │   └── match_compute_job.rb         # Background matching computation
│   ├── models/
│   │   ├── user.rb                      # Fisher + Soul + World storage
│   │   └── match.rb                     # Match scores and status
│   └── services/
│       ├── fisher_scorer.rb             # 16-question Fisher scoring
│       ├── soul_scorer.rb               # 5-question Soul scoring
│       └── match_scorer.rb              # Combined 3-layer scoring
├── db/
│   └── migrate/
│       ├── 20260505000001_create_users.rb
│       └── 20260505000002_create_matches.rb
└── config/
    └── routes.rb                        # API routes
```

## Database Schema

### Users Table
```ruby
# Fisher answers — 16 integers (1-4)
fisher_q1, fisher_q2, ..., fisher_q16

# Fisher computed scores (cached)
fisher_primary, fisher_secondary, fisher_scores (jsonb)

# Soul answers — strings (symbolic keys)
soul_q1, soul_q2, soul_q3, soul_q4, soul_q5, soul_q5b

# Soul computed tags (cached)
soul_tags (array)

# World layer
world_tags (array)

# Profile
name, email, age, location
```

### Matches Table
```ruby
user_a_id, user_b_id
fisher_score, soul_score, world_score, total_score (0-100)
status (pending/shown/liked/matched/passed)
scout_metadata (jsonb) — verdict, shared tags, etc.
```

## API Endpoints

### POST /users/:id/submit_answers
Submit Fisher + Soul answers, trigger background matching.

**Request:**
```json
{
  "fisher_answers": {
    "q1": 3, "q2": 4, "q3": 2, ..., "q16": 3
  },
  "soul_answers": {
    "q1": "curious",
    "q2": "show_up",
    "q3": "close",
    "q4": "say_it_once",
    "q5": "ready"
  },
  "world_tags": ["jazz", "swimming", "coffee"]
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "fisher_primary": "explorer",
    "fisher_secondary": "negotiator",
    "fisher_scores": {"explorer": 37, "negotiator": 27, ...},
    "soul_tags": ["depth_seeker", "reliable", "boundaried"],
    "world_tags": ["jazz", "swimming", "coffee"]
  },
  "message": "Answers submitted. Computing matches in background."
}
```

### GET /users/:id/matches
Fetch top 50 viable matches (score >= 50), ordered by total_score.

**Response:**
```json
{
  "matches": [
    {
      "id": 123,
      "user": {
        "id": 2,
        "name": "Maya",
        "age": 28,
        "location": "Brooklyn",
        "fisher_primary": "negotiator",
        "soul_tags": ["depth_seeker", "empathetic", "present"]
      },
      "scores": {
        "fisher": 73,
        "soul": 100,
        "world": 60,
        "total": 81
      },
      "scout_verdict": "Strong match. Fisher and Soul carry it.",
      "strong": true,
      "status": "pending"
    }
  ]
}
```

## Matching Logic (Do Not Change Weights)

- **Fisher Layer (55%)** — Primary + secondary type compatibility matrix
- **Soul Layer (35%)** — Tag overlap + high-value tag bonuses - friction penalties
- **World Layer (10%)** — Shared interests (enrichment only)
- **Floor Rule** — If Fisher + Soul combined < 45, World cannot rescue the match

## Next Steps

### 1. Complete Bundle Install
```bash
# In WSL terminal
cd "/mnt/c/Users/morel/OneDrive/Desktop/Projects/Dating app/kindred-api"

# Install system dependencies
sudo apt-get update
sudo apt-get install -y build-essential patch ruby-dev zlib1g-dev liblzma-dev libxml2-dev libxslt1-dev pkg-config

# Complete bundle install
bundle install
```

### 2. Setup PostgreSQL
```bash
# Install PostgreSQL + pgvector extension
sudo apt-get install -y postgresql postgresql-contrib

# Create database
rails db:create
rails db:migrate
```

### 3. Setup Redis + Sidekiq
```bash
# Install Redis
sudo apt-get install -y redis-server

# Add to Gemfile
gem 'sidekiq'

# Start Sidekiq
bundle exec sidekiq
```

### 4. Test the API
```bash
# Start Rails server
rails server

# Create a test user in Rails console
rails console
> user = User.create!(name: "Alex", email: "alex@test.com", age: 28, location: "NYC")

# Submit answers via API
curl -X POST http://localhost:3000/users/1/submit_answers \
  -H "Content-Type: application/json" \
  -d '{
    "fisher_answers": {"q1": 4, "q2": 3, "q3": 2, "q4": 3, "q5": 4, "q6": 2, "q7": 3, "q8": 4, "q9": 4, "q10": 2, "q11": 3, "q12": 4, "q13": 4, "q14": 2, "q15": 3, "q16": 4},
    "soul_answers": {"q1": "curious", "q2": "show_up", "q3": "close", "q4": "say_it_once", "q5": "ready"},
    "world_tags": ["jazz", "swimming", "coffee"]
  }'
```

## Deployment (Render.com)

1. **PostgreSQL** — Render managed PostgreSQL with pgvector
2. **Redis** — Render managed Redis
3. **Web Service** — Rails API (Puma)
4. **Background Worker** — Sidekiq instance
5. **Environment Variables**:
   - `DATABASE_URL`
   - `REDIS_URL`
   - `RAILS_MASTER_KEY`

## Tech Stack Summary

- **Rails 7.2** — API-only mode
- **PostgreSQL + pgvector** — User/match storage with array indexing
- **Redis** — Sidekiq job queue
- **Sidekiq** — Background match computation
- **Ruby 3.1.2** — Matching engine (Fisher, Soul, Match scorers)

All 53 matching engine tests pass. Ready for database setup and deployment.
