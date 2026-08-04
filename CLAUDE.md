# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this repo is

**Collective Player Games** — a small Rails 8 platform hosting collective-player games (games where several people jointly control a single character rather than each controlling their own). Runs at [collectiveplayer.games](https://collectiveplayer.games). See [danallison.info/writings/collective-player-games](https://danallison.info/writings/collective-player-games) for the concept.

Currently one game ships: **Group Group Chat** at `/ggc` — two groups have a real-time conversation, each composing messages one word at a time by anonymous vote. Future games slot in at their own paths under their own module.

## Development approach: red-green TDD

For every bug fix or new feature:

1. **Red**: write a failing test that reproduces the bug or specifies the new behavior. Run it; confirm it fails for the expected reason.
2. **Green**: make the minimal change needed to pass.
3. **Refactor**: clean up with tests staying green.

Every bug fix must include a regression test that fails before the fix and passes after. Do not fix a bug without first demonstrating it with a failing test.

## Design priorities

Games are primarily played on mobile devices. Prioritize mobile UX in all UI work: touch-friendly targets (44 px minimum, enforced by [test/system/mobile_layout_test.rb](test/system/mobile_layout_test.rb)), small-viewport layouts, and testing at mobile screen sizes first.

## Repo layout

Each game is Ruby-namespaced under its own module so games can coexist without stepping on each other:

```
app/
  channels/ggc/game_session_channel.rb   → Ggc::GameSessionChannel
  controllers/
    home_controller.rb                    → landing page ("/")
    ggc/game_sessions_controller.rb       → Ggc::GameSessionsController
  models/
    ggc.rb                                → Ggc module (sets table_name_prefix "ggc_")
    ggc/{game_session,group,player,message,word,submission}.rb
  views/
    home/index.html.erb                   → concept + game list
    ggc/game_sessions/{new,show,join_form}.html.erb
```

Tables for a game carry the module's prefix (`ggc_game_sessions`, `ggc_groups`, …) via `Ggc.table_name_prefix` — models auto-derive their table name; no per-model `self.table_name` override.

Routes for GGC live under `scope module: :ggc` in [config/routes.rb](config/routes.rb): `/ggc` is the create-session form, `/ggc/:code` is a session, `/ggc/:code/{join,start,end_game,submit_word,…}` are member actions.

## Build and run

```bash
# Install
bundle install
bin/rails db:create db:migrate

# Run
bin/rails server                            # dev server on :3000

# Tests
bin/rails test                              # models, controllers, channels, integration
bin/rails test:system                       # Playwright, mobile viewport by default
bin/rails test:all                          # everything
bin/rails test test/models/foo_test.rb      # single file
bin/rails test test/models/foo_test.rb:25   # single test by line number

# One-time setup for system tests:
npm install
npx playwright install chromium

# Console
bin/rails console
```

## Group Group Chat game flow

1. Host creates a session, receives a 6-character code (e.g., `ABC123`)
2. Players join via `/ggc/:code`, enter display name, choose which group to join
3. Each group picks its own name
4. Host starts the game once both groups have 1+ players
5. System randomly picks which group goes first
6. Active group composes a message word-by-word: each player submits secretly, most-voted word wins (case-insensitive tally, random tiebreaker)
7. When "END" wins, the message is complete and the turn switches to the other group
8. Game ends when a group's next message would be an immediate END, or the host ends it

### Data models (all under `Ggc::`)

- **GameSession** — code, status (waiting/active/complete), host_token, time_limit_seconds, current_turn_group_id
- **Group** — belongs to session, has name (player-chosen), has many players and messages
- **Player** — belongs to session and group (optional until chosen), has name and secret token
- **Message** — belongs to session and group, has position in conversation, has many words and submissions
- **Word** — belongs to message, has position and text
- **Submission** — per-word player vote; belongs to message and player

### Real-time architecture

- **`Ggc::GameSessionChannel`** (ActionCable): clients subscribe by session code. Broadcasts: `player_joined`, `player_changed_group`, `group_name_changed`, `game_started`, `word_revealed`, `message_completed`, `turn_switched`, `round_reset`, `game_ended`. Client action: `submit_word` (word + player_token, only the active group can submit).
- **[app/javascript/controllers/game_controller.js](app/javascript/controllers/game_controller.js)** (Stimulus): WebSocket subscription, UI updates on each broadcast, round timer, group-name editing, split composer (Add Word / Send Message).
- **Production Cable adapter**: `solid_cable` uses Postgres LISTEN/NOTIFY (see [config/cable.yml](config/cable.yml)) — no Redis to run.

### Key patterns to know

- **Player identity**: browser session stores tokens per game code (`session[:player_tokens][code]`); the server matches token → player.
- **Vote tallying** is case-insensitive: `submissions.group_by { |s| s.word.downcase.strip }`; the returned word preserves the first submitter's casing.
- **Session codes** exclude ambiguous characters (0, O, I, L, 1).
- **Turn switching**: `switch_turn!` moves to the other group, `start_new_message!` opens their next message.
- **`current_message`** (no bang) is read-only and returns nil; **`current_message!`** creates on demand.
- **Round processing** is guarded by a process-level `ROUND_PROCESSING_MUTEX` plus a re-check inside; safe for concurrent `complete_round!` / `timeout_round!` calls.

## Adding a new game

Follow the GGC pattern:

1. Pick a short slug (e.g., `cpc` for "collective-player chess").
2. Namespace all game code under `Cpc::` — models in `app/models/cpc/`, controllers in `app/controllers/cpc/`, channel in `app/channels/cpc/`, views in `app/views/cpc/`.
3. Create `app/models/cpc.rb` with `module Cpc; def self.table_name_prefix; "cpc_"; end; end` so tables get a `cpc_` prefix.
4. Migrations live in `db/migrate/` as usual; use the prefixed table names (e.g., `create_table :cpc_matches`).
5. Route inside `scope module: :cpc` in [config/routes.rb](config/routes.rb) so `resources :matches` dispatches to `Cpc::MatchesController` at `/cpc/matches`.
6. Add a card to [app/views/home/index.html.erb](app/views/home/index.html.erb) linking to the game's entry path.
7. Fixtures (if any) go under `test/fixtures/cpc/`.

Nothing else needs to touch existing code.

## Deployment (Kamal to a VPS)

Production is a single VPS running the app container + a Postgres accessory, fronted by Kamal Proxy for TLS. Container images are built by GitHub Actions on version tag pushes and pulled onto the VPS by `bin/kamal ship`. See [config/deploy.yml](config/deploy.yml) and [.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml).

### Environment variables (developer's shell)

Three vars must be in your shell for Kamal commands to work — put them in `~/.zshenv`, direnv, or 1Password. None are committed.

```sh
export COLLECTIVEPLAYER_GAMES_VPS=<VPS IP>
export KAMAL_REGISTRY_PASSWORD=<GitHub PAT with write:packages>
export COLLECTIVEPLAYER_GAMES_DB_PASSWORD=<random string used as Postgres password>
```

### Release flow

Every release bumps `VERSION`, adds a `CHANGELOG.md` entry, and gets a git tag. CI builds the image, then you deploy it:

```sh
# 1. Land the change on main (via a normal commit)
# 2. Bump VERSION and CHANGELOG.md in the same commit
# 3. Tag and push
git tag v0.2.0 && git push --tags
# 4. Wait ~3–5 min for the docker-publish workflow to build + push to ghcr.io
# 5. Deploy
bin/kamal ship --version=0.2.0    # note: no `v` prefix, docker convention
```

`bin/kamal ship` is an alias for `deploy --skip-push` — it doesn't build locally, just tells the VPS to pull the specified image tag.

### One-time setup on a fresh VPS (`bin/kamal setup`)

`bin/kamal setup` installs Docker on the VPS, boots the Postgres accessory, and does the first build+push+deploy. Takes ~15 minutes on a fresh VPS. After the first successful setup, only `bin/kamal ship` is needed.

### Useful ops shortcuts

```sh
bin/kamal app logs -f            # follow app logs
bin/kamal accessory logs db      # Postgres logs
bin/kamal console                # rails console in the app container
bin/kamal dbc                    # psql shell
bin/kamal shell                  # bash in the app container
bin/kamal app exec --reuse 'CMD' # ad-hoc command
```

### Production config gotchas (learned the hard way — see CHANGELOG 0.1.0–0.1.3)

- Everything under `app/` and `lib/` must eager-load cleanly. If a file's constant name doesn't match Zeitwerk's default camelize (e.g., `openrouter_client.rb` → `Openrouter` vs `OpenRouter`), register the inflection in [config/initializers/inflections.rb](config/initializers/inflections.rb). Dev doesn't catch this; production eager-loads on boot and crashes.
- CI-built images need `labels: service=collectiveplayer-games` in the docker-publish workflow. `bin/kamal deploy` adds this automatically for local builds; `docker/build-push-action` does not.
- `env.clear` values in `config/deploy.yml` pass through literally — no `${VAR}` expansion. Build composite values (like `DATABASE_URL`) in Rails config from individual env vars, or shell-interpolate them in `.kamal/secrets`.
- `bin/docker-entrypoint` must recognize the Thruster invocation (`./bin/thrust ./bin/rails server`) so `db:prepare` runs on every deploy.

## LLM vs LLM (Group Group Chat only)

A rake task runs an entire GGC game with LLM players via OpenRouter, which fronts many models behind one API.

### Setup

Set `OPENROUTER_API_KEY` in `.env` at the repo root (loaded via dotenv-rails in dev/test) or export it in your shell.

### Running

```bash
rake game:llm                                     # 1v1, Claude Haiku by default
rake game:llm[2]                                  # 2v2
rake "game:llm[1,openai/gpt-4o-mini]"             # any OpenRouter model
rake "game:llm[3,anthropic/claude-haiku-4.5,openai/gpt-4o-mini,google/gemini-2.5-flash]"  # mix models round-robin
```

`Ctrl+C` ends the game early.

### Key files

- [lib/openrouter_client.rb](lib/openrouter_client.rb) — HTTP client for the OpenRouter API
  - `generate(prompt)` — send prompt, return response
  - `extract_word(response)` — parse a single word from LLM output
  - `available?` — check the API key is set and the model exists
  - `list_models` — enumerate all OpenRouter model IDs
- [lib/tasks/llm_game.rake](lib/tasks/llm_game.rake) — game orchestration
  - Creates a session with two groups ("The Algorithms" vs "Neural Network")
  - Prompts each LLM player with conversation context
  - Handles voting when multiple players per group
  - Caps length via `MAX_WORDS_PER_MESSAGE` and `MAX_MESSAGES`
  - Colorized terminal output
