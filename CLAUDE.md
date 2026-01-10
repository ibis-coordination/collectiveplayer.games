# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Word Ouija is a real-time collaborative writing game where players collectively author a message one word at a time through anonymous voting. Built with Rails 8, Hotwire (Turbo + Stimulus), and ActionCable for WebSocket communication.

## Architecture

### Core Game Flow
1. Host creates a session, receives a 6-character code (e.g., `ABC123`)
2. Players join via link, enter display name, receive a secret token
3. Host starts the game when 2+ players have joined
4. Each round: all players submit one word secretly, most-voted word wins (ties broken randomly), word appends to message
5. Game ends when: host ends it, or winning word is "END" (case-insensitive)

### Data Models
- **GameSession**: Central entity with code, status (waiting/active/complete), host_token, time_limit_seconds, current_round
- **Player**: Belongs to session, has name and secret token (host's token matches session's host_token)
- **Word**: Belongs to session, has position and text (the built message)
- **Submission**: Per-round player votes, has round_number and word text

### Real-time Architecture
- **GameSessionChannel** (ActionCable): Players subscribe by session code
  - Broadcasts: `player_joined`, `game_started`, `word_revealed`, `game_ended`
  - Client action: `submit_word` (sends word + player_token)
- **game_controller.js** (Stimulus): Handles WebSocket connection, UI updates, timer display

### Key Patterns
- Player identity via browser session storing tokens per game code (`session[:player_tokens][code]`)
- Vote tallying is case-insensitive: `submissions.group_by { |s| s.word.downcase.strip }`
- Session codes exclude ambiguous characters (0, O, I, L)
