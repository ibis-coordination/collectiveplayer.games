# Collective Player Games

A small platform for collective-player games — games where several people jointly control a single character, rather than each person controlling their own. Each game uses some mechanism (voting, aggregation, sampling) to combine individual inputs into a single group action. See [danallison.info/writings/collective-player-games](https://danallison.info/writings/collective-player-games) for the concept.

Runs at [collectiveplayer.games](https://collectiveplayer.games). The landing page lists the available games; each game lives at its own path.

## Games

### Group Group Chat — `/ggc`

Two groups have a real-time conversation. Each group composes its messages one word at a time by anonymous vote.

1. Host creates a session, shares the 6-character code
2. Players join via the link and pick a team
3. Each group names itself
4. Teams take turns composing messages word-by-word
   - Each player secretly submits a word
   - Most-voted word wins (random tiebreaker)
   - Tap **Send Message** (or vote for "END") to finish a message and pass to the other team
5. Game ends when a team's next message would be empty (an immediate END)

## Development

```bash
bundle install
bin/rails db:create db:migrate
bin/rails server
```

Visit `http://localhost:3000`. The landing page links to Group Group Chat at `/ggc`.

### Tests

```bash
bin/rails test          # models, controllers, channels, integration
bin/rails test:system   # real-browser mobile viewport via Playwright
bin/rails test:all      # everything
```

One-time Playwright setup (system tests):

```bash
npm install
npx playwright install chromium
```

## Group Group Chat: LLM vs LLM

Watch AI players play a game via [OpenRouter](https://openrouter.ai), which fronts many models behind one API.

```bash
cp .env.example .env  # then fill in OPENROUTER_API_KEY

# Basic 1v1 (Claude Haiku by default)
rake game:llm

# 2v2 (2 LLM players per team)
rake game:llm[2]

# Use any OpenRouter model (see https://openrouter.ai/models)
rake "game:llm[1,openai/gpt-4o-mini]"

# Mix models: they're assigned to players round-robin
rake "game:llm[3,anthropic/claude-haiku-4.5,openai/gpt-4o-mini,google/gemini-2.5-flash]"
```

Press `Ctrl+C` to end the game early.

## Adding a new game

Group Group Chat is Ruby-namespaced under `Ggc::` (models, controllers, channel, views under `app/views/ggc/`, tables prefixed `ggc_`, mounted at `/ggc/*`). A new game follows the same pattern under its own module: pick a short slug, namespace the code under `MyGame::`, mount its routes under `/mygame`, and add a card to `app/views/home/index.html.erb`. See [CLAUDE.md](CLAUDE.md) for the architectural details of the existing game.

## Deploy

Production runs on a single VPS via [Kamal](https://kamal-deploy.org): app container + Postgres accessory, fronted by Kamal Proxy for TLS. Container images are built by GitHub Actions on `v*` tag pushes; deploys pull them onto the VPS. See [CLAUDE.md § Deployment](CLAUDE.md#deployment-kamal-to-a-vps) for the full release flow and the env vars you need to set locally.

## Tech stack

- Ruby on Rails 8
- SQLite (dev/test); PostgreSQL + `solid_cable` for ActionCable pub/sub (production)
- Hotwire (Turbo + Stimulus)
- Playwright (system tests, mobile viewport)
- OpenRouter (LLM integration)
- Kamal + GitHub Container Registry (deploy)
