# Word Ouija - Product Specification

## Overview
Word Ouija is a realtime collaborative writing game where participants collectively author a message one word at a time through anonymous voting. Similar to a Ouija board experience, the group guides the message together without seeing individual contributions until each word is revealed.

## Core Concept
- Players join a shared session
- At each round, every player submits one word they want to add next
- The word with the most votes becomes the next word in the message
- Ties are broken randomly
- The process continues until the message reaches completion

---

## Session Management

### Session Creation
- Any user can create a new session (become the host)
- Host configures session settings:
  - **Max time per round**: Default 5 seconds, configurable or unlimited
  - **Message length limit**: Default haiku length (~17 words), configurable or unlimited
  - **Max players**: Configurable up to system maximum of 100 players
  - **Optional prompt/theme**: Host can provide context for the collaborative message

### Joining a Session
- Host receives a shareable link upon session creation
- Host distributes link to participants (outside the app)
- Players click link to join session
- Upon joining, players enter their display name (no email/login required)
- System assigns each player a unique avatar (from predefined set)

### Player Requirements
- **Minimum players**: 2
- **Maximum players**: Configurable per session, absolute max 100

### Session Lifecycle
- **Active**: Session is ongoing, players can submit words
- **Complete**: Session ends when any of the following occurs:
  - Message reaches configured max length
  - Group collectively submits the end keyword (e.g., `{end}`)
  - Host manually ends the session
  - All players exit or remain idle for 10+ minutes
- Sessions are temporary and not persisted after completion
- No user identity or group identity persists beyond individual sessions

---

## Gameplay Mechanics

### Word Submission Round

**Each round follows this flow:**

1. **Display current message** - All players see the message built so far
2. **Submission phase** - Each player types and submits one word
   - Players only see their own submission
   - Players cannot see what others are typing or have submitted
   - Round advances when EITHER:
     - All players have submitted a word, OR
     - Configured time limit expires (if set)
3. **Word selection** - System determines winning word:
   - Word with most votes wins
   - Ties broken randomly
4. **Reveal** - Winning word is appended to the message and displayed to all players
   - Vote breakdown is NOT shown
   - Individual submissions are NOT revealed
5. **Next round** - Process repeats from step 1

### Message Completion

The message/session ends when:
- **Length limit reached**: Configured max word count is achieved
- **End keyword submitted**: The winning word is `{end}` (or similar keyword)
- **Host ends session**: Host can terminate at any time
- **Inactivity timeout**: All players exit or are idle for 10+ minutes

---

## User Interface Requirements

### Lobby/Waiting Screen
- Display session link for sharing
- Show list of joined players (names + avatars)
- Display session settings (time limit, length limit, prompt)
- Host controls to start session or adjust settings
- Player count indicator

### Active Game Screen
- **Message display**: Large, prominent area showing the collaborative message built so far
- **Word count**: Show progress toward length limit (if applicable)
- **Round timer**: Visual countdown if time limit is enabled
- **Input field**: Single text input for player's word submission
- **Submit button**: Confirms word choice
- **Player list**: Sidebar or compact list showing active participants
- **Host controls**: End session button (visible only to host)

### Completion Screen
- Display final collaborative message
- Option to start a new session
- Share/copy final message (optional enhancement)

---

## Configuration Options

### Host Settings (Set at session creation)
| Setting | Default | Options |
|---------|---------|---------|
| Time per round | 5 seconds | 3s, 5s, 10s, 30s, Unlimited |
| Message length | 17 words (haiku) | 5, 10, 17, 50, 100, Unlimited |
| Max players | 10 | 2-100 |
| Prompt/Theme | None | Freeform text input (optional) |

---

## Technical Considerations

### Realtime Requirements
- WebSocket or similar technology for realtime updates
- All players must see word reveals simultaneously
- Submission status updates (e.g., "3/5 players have submitted")

### Data Storage
- Sessions are temporary (in-memory or short-lived storage)
- No user accounts or persistent data
- Session data deleted after completion or timeout

### Avatar System
- Predefined set of system avatars
- Randomly or sequentially assigned to players
- No user uploads required

---

## Future Enhancements (Out of Scope for V1)
- Moderation features (word filtering, kick players)
- Session history and past messages
- Undo/restart functionality
- Persistent user accounts and groups
- System-suggested prompts or themes
- Vote breakdown display (optional toggle)
- Real-time typing indicators

---

## Success Metrics
- Session completion rate
- Average session duration
- Number of players per session
- Message coherence (qualitative analysis)
- User engagement (repeat session creation)

---

## Open Questions
- What should the end keyword be exactly? `{end}`, `[END]`, `***`?
- Should there be a visual/audio cue when a word is revealed?
- How should the app handle players who disconnect mid-session?
- Should submissions be case-sensitive for voting purposes?