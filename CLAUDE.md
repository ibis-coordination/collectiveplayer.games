# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Approach: Red-Green TDD

Use red-green TDD for all bug fixes and new features:

1. **Red**: Write a failing test first that reproduces the bug (or specifies the new behavior). Run it and confirm it fails for the expected reason.
2. **Green**: Make the minimal change needed to pass the test.
3. **Refactor**: Clean up with the tests staying green.

Every bug fix must include a regression test that fails before the fix and passes after. Do not fix a bug without first demonstrating it with a failing test.

## Build and Run Commands

```bash
# Install dependencies
bundle install

# Database setup
bin/rails db:create db:migrate

# Run development server
bin/rails server

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/game_session_test.rb

# Run a specific test by line number
bin/rails test test/models/game_session_test.rb:25

# Rails console
bin/rails console
```

## Project Overview

Group Group Chat is a real-time collaborative chat game where two groups have a conversation with each other, composing messages one word at a time through anonymous voting. Built with Rails 8, Hotwire (Turbo + Stimulus), and ActionCable for WebSocket communication.

## Architecture

### Core Game Flow
1. Host creates a session, receives a 6-character code (e.g., `ABC123`)
2. Players join via link, enter display name, choose which group to join
3. Each group picks their own name
4. Host starts the game when both groups have 1+ players
5. System randomly picks which group goes first
6. Active group composes a message word-by-word (each player submits secretly, most-voted wins)
7. When "END" wins, message is complete and turn switches to the other group
8. Game ends when a group's entire message is just "END", or host ends it

### Data Models
- **GameSession**: Central entity with code, status (waiting/active/complete), host_token, time_limit_seconds, current_turn_group_id
- **Group**: Belongs to session, has name (player-chosen), has many players and messages
- **Player**: Belongs to session and group (optional until chosen), has name and secret token
- **Message**: Belongs to session and group, has position in conversation, has many words and submissions
- **Word**: Belongs to message, has position and text
- **Submission**: Per-word player votes, belongs to message and player

### Real-time Architecture
- **GameSessionChannel** (ActionCable): Players subscribe by session code
  - Broadcasts: `player_joined`, `player_changed_group`, `group_name_changed`, `game_started`, `word_revealed`, `message_completed`, `turn_switched`, `game_ended`
  - Client action: `submit_word` (sends word + player_token, only active group can submit)
- **game_controller.js** (Stimulus): Handles WebSocket, UI updates, timer, group name editing

### Key Patterns
- Player identity via browser session storing tokens per game code (`session[:player_tokens][code]`)
- Vote tallying is case-insensitive: `submissions.group_by { |s| s.word.downcase.strip }`
- Session codes exclude ambiguous characters (0, O, I, L)
- Turn switching: `switch_turn!` changes to other group, `start_new_message!` creates new message
- `current_message` returns most recent message for active group (or creates one)

## LLM Game Orchestration

The project includes a rake task for running LLM vs LLM games via OpenRouter, which provides access to a variety of models through one API.

### Prerequisites

Set `OPENROUTER_API_KEY` in `.env` at the repo root (loaded via dotenv-rails), or export it in your shell.

### Running LLM Games

```bash
# Basic 1v1 game (uses anthropic/claude-haiku-4.5 by default)
rake game:llm

# 2v2 game (2 LLM players per group)
rake game:llm[2]

# Use any OpenRouter model ID (https://openrouter.ai/models)
rake "game:llm[1,openai/gpt-4o-mini]"

# Multiple models are assigned to players round-robin
rake "game:llm[2,anthropic/claude-haiku-4.5,openai/gpt-4o-mini]"
```

### Key Files

- **lib/openrouter_client.rb**: HTTP client for the OpenRouter API
  - `generate(prompt)`: Send prompt, get response
  - `extract_word(response)`: Parse single word from LLM output
  - `available?`: Check an API key is set and the model exists
  - `list_models`: List all OpenRouter model IDs

- **lib/tasks/llm_game.rake**: Game orchestration
  - Creates game session with two groups ("The Algorithms" vs "Neural Network")
  - Each LLM player gets prompted with conversation context
  - Handles word voting when multiple players per group
  - Caps game length (`MAX_WORDS_PER_MESSAGE`, `MAX_MESSAGES`)
  - Colorized terminal output
  - Ctrl+C to end game early
