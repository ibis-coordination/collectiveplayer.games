# Group Group Chat - Implementation Plan (original build)

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Backend | Ruby on Rails 8 (latest stable) | Full-featured, batteries included |
| Frontend | Stimulus + Turbo (Hotwire) | Ships with Rails, minimal JS |
| Realtime | ActionCable | Built into Rails |
| Database | SQLite | Simple, no setup, fine for ephemeral data |
| CSS | Vanilla CSS | Minimal custom styles |
| Ruby | 3.3 (latest stable) | Current stable version |

## Technical Decisions

| Decision | Choice |
|----------|--------|
| Session IDs | 6-character random alphanumeric codes (e.g., `ABC123`) |
| End keyword | `END` (case-insensitive) |
| Disconnect handling | Remove player after 30s, game continues |
| Vote case sensitivity | Case-insensitive ("Hello" = "hello") |
| Avatars | Deferred to post-MVP |

---

## MVP Scope

### Included in MVP
- Create session (host only configures round time limit)
- Join session via shareable link
- Enter display name to join
- Basic game loop:
  - See current message
  - Submit one word
  - Round ends when all players submit OR time expires
  - Winning word revealed and appended
  - Repeat
- Host can end session manually
- Show final message on completion

### Deferred to Post-MVP
- Message length limit configuration
- Max players configuration
- Prompt/theme feature
- Avatar system
- Player submission status indicator ("3/5 submitted")
- Inactivity timeout auto-end
- Share/copy final message button

---

## Data Models

### Session
```
id: integer (primary key)
code: string (6 chars, unique, indexed)
host_token: string (secret token to identify host)
time_limit_seconds: integer (nullable for unlimited)
status: enum (waiting, active, complete)
created_at: datetime
updated_at: datetime
```

### Player
```
id: integer (primary key)
session_id: foreign key
name: string
token: string (secret token stored in browser)
connected: boolean
created_at: datetime
updated_at: datetime
```

### Word (the collaborative message)
```
id: integer (primary key)
session_id: foreign key
position: integer (word order)
text: string
created_at: datetime
```

### Submission (votes for current round)
```
id: integer (primary key)
session_id: foreign key
player_id: foreign key
round_number: integer
word: string
created_at: datetime
```

---

## Implementation Phases

### Phase 1: Project Setup ✅
- [x] Initialize Rails 8 app with SQLite
- [x] Configure Hotwire (Turbo + Stimulus)
- [x] Set up ActionCable
- [x] Create basic layout and minimal CSS

### Phase 2: Session Management ✅
- [x] Session model with code generation
- [x] Create session page (host sets time limit)
- [x] Session lobby page (shows join link, player list)
- [x] Join session flow (enter name, get token)
- [x] Player model and association

### Phase 3: Game Loop - Backend ✅
- [x] Word and Submission models
- [x] Round management logic:
  - Track current round number
  - Accept submissions
  - Detect round completion (all submitted or timeout)
  - Tally votes (case-insensitive)
  - Break ties randomly
  - Append winning word
- [x] End game logic (host ends or `END` wins)
- [x] ActionCable channels for realtime updates

### Phase 4: Game Loop - Frontend ✅
- [x] Active game view with Turbo Frames/Streams
- [x] Display current message
- [x] Word input form with Stimulus controller
- [x] Round timer display (Stimulus)
- [x] Realtime word reveal updates
- [x] Host "End Session" button

### Phase 5: Completion & Polish
- [ ] Completion screen with final message
- [ ] "Create New Session" button
- [ ] Basic error handling
- [ ] Input validation (non-empty words, no spaces)
- [ ] Handle edge cases (last player leaves, etc.)

---

## ActionCable Channels

### SessionChannel
Subscribed to by all players in a session.

**Broadcasts:**
- `player_joined` - New player joined the lobby
- `player_left` - Player disconnected
- `game_started` - Host started the game
- `round_started` - New round begins (includes current message)
- `word_revealed` - Winning word for round (append to message)
- `game_ended` - Session complete (includes final message)

**Client actions:**
- `submit_word` - Player submits their word for current round

---

## Routes

```
GET  /                     -> Home (create session form)
POST /sessions             -> Create session, redirect to lobby
GET  /sessions/:code       -> Join/lobby page
POST /sessions/:code/join  -> Join session (set name, get token)
POST /sessions/:code/start -> Host starts the game
POST /sessions/:code/end   -> Host ends the game
```

WebSocket: `/cable` (ActionCable default)

---

## File Structure (Key Files)

```
app/
├── channels/
│   └── session_channel.rb
├── controllers/
│   ├── sessions_controller.rb
│   └── home_controller.rb
├── models/
│   ├── session.rb
│   ├── player.rb
│   ├── word.rb
│   └── submission.rb
├── views/
│   ├── home/
│   │   └── index.html.erb
│   └── sessions/
│       ├── show.html.erb (lobby + game + complete)
│       └── _message.html.erb
├── javascript/
│   └── controllers/
│       ├── game_controller.js
│       └── timer_controller.js
└── assets/
    └── stylesheets/
        └── application.css
```

---

## Key Implementation Details

### Session Code Generation
```ruby
# 6 uppercase alphanumeric characters, excluding ambiguous (0, O, I, L)
CHARS = ('A'..'Z').to_a + ('2'..'9').to_a - ['O', 'I']
code = 6.times.map { CHARS.sample }.join
```

### Vote Tallying
```ruby
def determine_winner(submissions)
  votes = submissions.group_by { |s| s.word.downcase }
  max_votes = votes.values.map(&:size).max
  winners = votes.select { |_, v| v.size == max_votes }.keys
  winners.sample # Random tie-breaker
end
```

### Round Timer
- Server tracks round start time
- Client displays countdown via Stimulus
- Server job/process checks for timeout and forces round completion
- Use `after_commit` callbacks or a simple polling approach for MVP

### Player Token Storage
- Store player token in browser `localStorage`
- Send token with each request to identify player
- No cookies/sessions needed for players

---

## Open Items / Decisions During Implementation

- Exact UI layout and styling
- Error message wording
- Whether to use Turbo Streams or full page refreshes for updates
- Timer implementation: client-side only vs server-enforced

---

## Next Steps

1. Run `rails new word-ouija` with appropriate flags
2. Begin Phase 1: Project Setup
