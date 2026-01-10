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
