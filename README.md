# Word Ouija (Group Group Chat)

A real-time collaborative chat game where two groups have a conversation with each other, composing messages one word at a time through anonymous voting.

## How It Works

1. **Create a Game**: Host creates a session and shares the 6-character code
2. **Join Groups**: Players join via link and choose which team to join
3. **Name Your Team**: Each group picks their own name
4. **Play**: Teams take turns composing messages word-by-word
   - Each player secretly submits a word
   - Most-voted word wins (random tiebreaker)
   - Type "END" to finish your message and pass to the other team
5. **End**: Game ends when a team's entire message is just "END"

## Setup

```bash
# Install dependencies
bundle install

# Create and setup database
bin/rails db:create db:migrate

# Start the server
bin/rails server
```

Visit `http://localhost:3000` to play.

## Running Tests

```bash
bin/rails test
```

## LLM vs LLM Mode

Watch AI players battle it out using Ollama.

### Prerequisites

```bash
# Install Ollama (macOS)
brew install ollama

# Start Ollama server
ollama serve

# Pull a model
ollama pull llama3.2
```

### Run an LLM Battle

```bash
# Basic 1v1 game
rake game:llm_battle

# 2v2 game (2 LLM players per team)
rake game:llm_battle[2]

# Use a different model
rake game:llm_battle[1,mistral]
```

Press `Ctrl+C` to end the game early.

## Tech Stack

- Ruby on Rails 8
- SQLite
- Hotwire (Turbo + Stimulus)
- ActionCable (WebSockets)
- Ollama (for LLM integration)
