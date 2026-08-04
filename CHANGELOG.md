# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-08-04

### Fixed

- **Automatic migrations on deploy** — `bin/docker-entrypoint` only ran `db:prepare` when the container's CMD was exactly `./bin/rails server`, but production runs `./bin/thrust ./bin/rails server` so the check missed and no migrations ran. Ships with an empty database on first deploy → every session-creating action 500'd on `relation "ggc_game_sessions" does not exist`. The entrypoint now recognizes either invocation.

## [0.1.2] - 2026-08-04

### Fixed

- **Production Postgres connection** — `DATABASE_URL` was set under `env.clear` in `config/deploy.yml` with a `${POSTGRES_PASSWORD}` interpolation, but Kamal passes `env.clear` values literally, so Rails saw the URL with the literal string `${POSTGRES_PASSWORD}` as the password and `pg` reported "no password supplied". Rebuilt so `config/database.yml` composes the connection from an accessory-known host/database/user plus a `POSTGRES_PASSWORD` env var injected as a Kamal secret.

## [0.1.1] - 2026-08-04

### Fixed

- **CI-built images now carry the `service=collectiveplayer-games` label** so Kamal can find and manage its containers. `bin/kamal deploy` (local build) added the label automatically; `docker/build-push-action` did not, and `bin/kamal ship --version=0.1.0` refused to deploy the pulled image.

## [0.1.0] - 2026-08-03

Initial release. Ships the **Collective Player Games** platform with one game (**Group Group Chat**), deployable to a VPS via Kamal.

### Added

- **Landing page at `/`** — concept explainer for collective-player games and a list of playable games. Room for more games to slot in under their own paths without touching the landing view.
- **Group Group Chat at `/ggc`** — real-time two-group chat where each group composes its messages one word at a time by anonymous vote. Host creates a session with a 6-character code, players join a team, each turn everyone secretly submits a word, the most-voted word (case-insensitive tally, random tiebreaker) is appended, "END" completes the message and swaps turns. Sessions live at `/ggc/:code`.
- **Mobile-first iOS-styled UI** — iMessage-like chat bubbles (fit-content, sender-aligned, tail radii), full-height chat layout with pinned composer and scroll-only transcript, split "Add Word" (round ↑ button) + "Send Message" pill composer, light/dark mode following the device's appearance setting, 44px minimum touch targets throughout.
- **LLM vs LLM mode** — rake task (`rake game:llm[players_per_group,model1,model2,...]`) runs an entire game with LLM players via OpenRouter, colorized terminal output, models assigned round-robin.
- **System-test rig** — Playwright-driven Capybara at an iPhone-class mobile viewport; covers touch-target sizes, no-horizontal-overflow, stacked group columns, chat layout, bubble alignment, light/dark styling, and the Send Message flow.
- **Kamal deploy** — production runs on Postgres (with `solid_cable` for ActionCable pub/sub, so no Redis to operate), fronted by Kamal Proxy for Let's Encrypt TLS. Postgres runs as an accessory on the same VPS. VPS host and secrets are pulled from environment variables, never committed.
- **CI-built images on `v*` tags** — GitHub Actions builds and pushes a `linux/amd64` image to `ghcr.io/ibis-coordination/collectiveplayer.games` when a version tag is pushed; local deploys use `bin/kamal ship --version=v…` to fetch and swap without a local build.
