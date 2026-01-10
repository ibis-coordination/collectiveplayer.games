# Group Group Chat - Refactor Plan

## Concept
Transform Word Ouija from a single group writing one message into two groups having a conversation with each other. Each group collaboratively authors messages one word at a time, taking turns in a back-and-forth chat.

---

## Design Decisions

| Aspect | Decision |
|--------|----------|
| Group assignment | Player choice - players pick which group to join |
| Visibility | Real-time - other group watches words appear as they're voted on |
| Turn end | END keyword - group votes "END" to finish their message |
| Game end | Either group votes just "END" as entire message to end conversation |
| Player list | Show all players and which group they're in |
| Waiting turn | Just watch - observe other group's message being built |
| Group names | Player-chosen - each group picks their own name |
| Min players | 1 per group to start |
| First turn | Random selection |
| Solo player | Auto-wins - their word automatically becomes the message word |
| Transcript | Labels + color coding for group attribution |

---

## Game Flow

### Lobby Phase
1. Host creates session, gets shareable link
2. Players join and enter display name
3. Players choose which group to join (or create new group if < 2 groups exist)
4. Each group chooses their group name
5. Host starts game when both groups have 1+ players
6. System randomly picks which group goes first

### Active Game Phase
1. **Active group's turn:**
   - All players in active group see word input
   - Each player submits one word secretly
   - Most-voted word wins (ties broken randomly)
   - If only 1 player, their word auto-wins
   - Word appends to current message (visible to all in real-time)
   - Repeat until "END" wins → message complete, turn switches

2. **Waiting group's turn:**
   - Watch words appear in real-time
   - No input allowed
   - When active group finishes message, roles swap

3. **Turn alternates** until game ends

### Game End
- Triggered when a group's complete message is just "END" (i.e., "END" is first and only word)
- Final screen shows full conversation transcript with group labels and colors

---

## Data Model Changes

### GameSession
```diff
  code: string
  status: enum (waiting, active, complete)
  host_token: string
  time_limit_seconds: integer
- current_round: integer
+ current_turn_group_id: integer (FK to Group)
  round_started_at: datetime
```

### New: Group
```
id: integer (PK)
game_session_id: integer (FK)
name: string (player-chosen)
created_at: datetime
```

### Player
```diff
  id: integer (PK)
  game_session_id: integer (FK)
+ group_id: integer (FK, nullable until player chooses)
  name: string
  token: string
```

### Message (rename from Word, now represents full messages)
```
id: integer (PK)
game_session_id: integer (FK)
group_id: integer (FK) -- which group authored this
position: integer (order in conversation)
created_at: datetime
```

### Word (now belongs to Message)
```diff
  id: integer (PK)
- game_session_id: integer (FK)
+ message_id: integer (FK)
  position: integer (order within message)
  text: string
```

### Submission
```diff
  id: integer (PK)
- game_session_id: integer (FK)
+ message_id: integer (FK) -- current message being composed
  player_id: integer (FK)
- round_number: integer
  word: string
```

---

## UI Changes

### Lobby Screen
- Two columns/sections for Group A and Group B
- "Join Group" buttons for each
- Group name input field (editable by group members)
- Player list shows under each group
- Host sees "Start Game" when both groups have players

### Active Game Screen
- Chat transcript area (top) - shows completed messages with group labels/colors
- Current message area (middle) - shows message being built word-by-word
- Input area (bottom) - only visible to active group
- "Waiting for [Group Name]..." shown to inactive group
- Player lists for both groups (sidebar)

### Completion Screen
- Full conversation transcript
- Group labels and color coding
- "New Game" button

---

## ActionCable Changes

### Broadcasts
- `player_joined` - include group_id
- `player_changed_group` - player switched groups
- `group_name_changed` - group renamed
- `game_started` - include which group goes first
- `word_revealed` - include group_id, message context
- `message_completed` - group finished their message, turn switches
- `game_ended` - final transcript

### Client Actions
- `join_group` - player selects a group
- `set_group_name` - group name update
- `submit_word` - same as before, scoped to active group

---

## Implementation Phases

### Phase 1: Data Model Migration
- [ ] Create Group model and migration
- [ ] Add group_id to Player
- [ ] Create Message model (group's complete message)
- [ ] Update Word to belong to Message instead of GameSession
- [ ] Update Submission to reference Message
- [ ] Update GameSession: replace current_round with current_turn_group_id

### Phase 2: Lobby - Group Selection
- [ ] UI for two group columns
- [ ] Join group functionality
- [ ] Group name input/editing
- [ ] Update player list to show group membership
- [ ] Start game validation (both groups have players)

### Phase 3: Turn-Based Game Loop
- [ ] Track active group (whose turn it is)
- [ ] Only accept submissions from active group
- [ ] Create new Message when turn starts
- [ ] Append words to current Message
- [ ] Detect "END" → complete message, switch turns
- [ ] Detect conversation-ending "END" (message is just "END")

### Phase 4: Real-Time UI Updates
- [ ] Update game_controller.js for two-group display
- [ ] Chat transcript with completed messages
- [ ] Current message builder (visible to all)
- [ ] Conditional input (only active group)
- [ ] Group labels and color coding

### Phase 5: Polish
- [ ] Completion screen with full transcript
- [ ] Handle edge cases (player leaves, group becomes empty)
- [ ] Update tests for new flow

---

## Open Items / Future Considerations
- What if a group becomes empty mid-conversation? (Auto-forfeit? Pause?)
- Should there be a time limit per message (not just per word)?
- Spectator mode for non-players?
