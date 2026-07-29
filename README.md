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

Watch AI players play the game via [OpenRouter](https://openrouter.ai), which gives access to a variety of models through one API.

```bash
# Add your API key (get one at https://openrouter.ai/keys) to .env:
cp .env.example .env  # then fill in OPENROUTER_API_KEY

# Basic 1v1 game (uses Claude Haiku by default)
rake game:llm

# 2v2 game (2 LLM players per team)
rake game:llm[2]

# Use any OpenRouter model (see https://openrouter.ai/models)
rake "game:llm[1,openai/gpt-4o-mini]"
rake "game:llm[2,meta-llama/llama-3.3-70b-instruct]"

# Mix models: list several and they're assigned to players round-robin
# (3v3 where each of the 6 players is a different model)
rake "game:llm[3,anthropic/claude-haiku-4.5,openai/gpt-4o-mini,google/gemini-2.5-flash,meta-llama/llama-3.3-70b-instruct,mistralai/mistral-nemo,deepseek/deepseek-chat]"
```

Press `Ctrl+C` to end the game early.

## Tech Stack

- Ruby on Rails 8
- SQLite
- Hotwire (Turbo + Stimulus)
- ActionCable (WebSockets)
- OpenRouter (for LLM integration)
