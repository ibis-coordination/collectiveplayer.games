import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messageDisplay", "timer", "timerValue", "wordInput", "wordField", "playerList", "playerCount", "finalMessage", "hostControls", "chatTranscript", "currentMessage", "messageText", "turnIndicator"]
  static values = {
    code: String,
    playerToken: String,
    status: String,
    timeLimit: Number,
    roundStartedAt: String,
    isHost: Boolean,
    playerGroupId: Number,
    activeGroupId: Number
  }

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "GameSessionChannel", code: this.codeValue },
      {
        received: (data) => this.handleMessage(data),
        connected: () => console.log("Connected to game session"),
        disconnected: () => console.log("Disconnected from game session")
      }
    )

    if (this.statusValue === "active" && this.timeLimitValue > 0) {
      this.startTimer()
    }

    // Show the most recent messages if the transcript already overflows
    this.scrollTranscriptToBottom()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
  }

  handleMessage(data) {
    switch(data.type) {
      case "player_joined":
        // Reload to show updated player list
        window.location.reload()
        break
      case "player_changed_group":
        // Reload to show updated group membership
        window.location.reload()
        break
      case "group_name_changed":
        this.updateGroupNameDisplay(data.group_id, data.name)
        break
      case "game_started":
        window.location.reload()
        break
      case "word_revealed":
        this.revealWord(data.word, data.message_text, data.group_id)
        break
      case "message_completed":
        this.messageCompleted(data.group_id, data.group_name, data.message_text)
        break
      case "turn_switched":
        this.switchTurn(data.active_group_id, data.active_group_name)
        break
      case "round_reset":
        // Round timed out with no submissions; server restarted the timer
        if (this.timeLimitValue > 0) {
          this.roundStartedAtValue = data.round_started_at
          this.startTimer()
        }
        break
      case "game_ended":
        window.location.reload()
        break
    }
  }

  updateGroupNameDisplay(groupId, name) {
    // Update group name displays on the page
    const groupColumns = document.querySelectorAll(`[data-group-id="${groupId}"]`)
    groupColumns.forEach(col => {
      const nameEl = col.querySelector('.group-name')
      if (nameEl) nameEl.textContent = name
    })
  }

  revealWord(word, messageText, groupId) {
    // Update the current message text
    if (this.hasMessageTextTarget) {
      this.messageTextTarget.textContent = messageText || "..."

      // Flash effect
      this.messageTextTarget.classList.add("flash")
      setTimeout(() => this.messageTextTarget.classList.remove("flash"), 500)
    }

    // Reset word input if it's our turn
    if (this.playerGroupIdValue === groupId && this.hasWordInputTarget) {
      this.wordInputTarget.innerHTML = `
        <button type="button" class="btn-send-message" data-action="click->game#sendMessage">Send Message &#9654;</button>
        <div class="word-input-row">
          <input type="text"
                 data-game-target="wordField"
                 data-action="keydown.enter->game#submitWord"
                 placeholder="Add a word..."
                 autofocus>
          <button data-action="click->game#submitWord" class="btn btn-primary btn-send" aria-label="Add word">&uarr;</button>
        </div>
      `
      // Focus the new input
      const newInput = this.wordInputTarget.querySelector("input")
      if (newInput) newInput.focus()
    }

    // Restart timer
    if (this.timeLimitValue > 0) {
      this.roundStartedAtValue = new Date().toISOString()
      this.startTimer()
    }
  }

  messageCompleted(groupId, groupName, messageText) {
    // Add completed message to chat transcript
    if (this.hasChatTranscriptTarget && messageText) {
      const isOwnGroup = this.playerGroupIdValue === groupId
      const div = document.createElement("div")
      div.className = `chat-message ${isOwnGroup ? 'own-group' : 'other-group'}`

      // Build with textContent: group names and words are player-controlled
      // and must never be injected as HTML
      const label = document.createElement("span")
      label.className = "group-label"
      label.textContent = groupName

      const text = document.createElement("span")
      text.className = "message-text"
      text.textContent = messageText

      const bubble = document.createElement("div")
      bubble.className = "bubble"
      bubble.appendChild(text)

      // Only snap to the new message if the user was already at the bottom;
      // don't yank them away while they're scrolled up reading history
      const wasAtBottom = this.transcriptNearBottom()
      div.append(label, bubble)
      this.chatTranscriptTarget.appendChild(div)
      if (wasAtBottom) this.scrollTranscriptToBottom()
    }
  }

  transcriptNearBottom() {
    if (!this.hasChatTranscriptTarget) return false

    const el = this.chatTranscriptTarget
    return el.scrollHeight - el.scrollTop - el.clientHeight < 40
  }

  scrollTranscriptToBottom() {
    if (this.hasChatTranscriptTarget) {
      this.chatTranscriptTarget.scrollTop = this.chatTranscriptTarget.scrollHeight
    }
  }

  switchTurn(activeGroupId, activeGroupName) {
    this.activeGroupIdValue = activeGroupId
    const isOurTurn = this.playerGroupIdValue === activeGroupId

    // Update turn indicator (group names are player-controlled: never
    // inject them as HTML)
    if (this.hasTurnIndicatorTarget) {
      if (isOurTurn) {
        this.turnIndicatorTarget.innerHTML = `<strong>Your group's turn!</strong> Compose a message together.`
      } else {
        const strong = document.createElement("strong")
        strong.textContent = activeGroupName
        this.turnIndicatorTarget.replaceChildren("Waiting for ", strong, " to compose their message...")
      }
    }

    // Update current message label and realign its bubble to the
    // now-composing group's side
    if (this.hasCurrentMessageTarget) {
      const labelEl = this.currentMessageTarget.querySelector('.group-label')
      if (labelEl) labelEl.textContent = `${activeGroupName}:`

      const area = this.currentMessageTarget.closest('.current-message-area')
      if (area) {
        area.classList.toggle('own-group', isOurTurn)
        area.classList.toggle('other-group', !isOurTurn)
      }
    }

    // Clear current message text
    if (this.hasMessageTextTarget) {
      this.messageTextTarget.textContent = "..."
    }

    // Show/hide word input
    if (this.hasWordInputTarget) {
      if (isOurTurn) {
        this.wordInputTarget.innerHTML = `
          <input type="text"
                 data-game-target="wordField"
                 data-action="keydown.enter->game#submitWord"
                 placeholder="Enter your word..."
                 autofocus>
          <button data-action="click->game#submitWord" class="btn btn-primary btn-send" aria-label="Send word">&uarr;</button>
          <p class="hint">Type "END" to finish your message</p>
        `
        const newInput = this.wordInputTarget.querySelector("input")
        if (newInput) newInput.focus()
      } else {
        this.wordInputTarget.innerHTML = `
          <div class="waiting-turn">
            <p>Watch the other group compose their message...</p>
          </div>
        `
      }
    }

    // Restart timer
    if (this.timeLimitValue > 0) {
      this.roundStartedAtValue = new Date().toISOString()
      this.startTimer()
    }
  }

  submitWord() {
    if (!this.hasWordFieldTarget) return

    const word = this.wordFieldTarget.value.trim()
    if (!word) return

    this.sendVote(word)
  }

  // Send Message is a labeled shortcut for submitting END. On an empty
  // in-progress message, that would end the whole game, so confirm first.
  sendMessage() {
    if (this.currentMessageIsEmpty()) {
      if (!window.confirm("The message is still empty. Sending it now will end the game. Are you sure?")) {
        return
      }
    }
    this.sendVote("END")
  }

  sendVote(word) {
    this.subscription.perform("submit_word", {
      word: word,
      player_token: this.playerTokenValue
    })

    if (this.hasWordInputTarget) {
      this.wordInputTarget.innerHTML = '<p class="submitted-message">Word submitted! Waiting for teammates...</p>'
    }
  }

  currentMessageIsEmpty() {
    if (!this.hasMessageTextTarget) return true
    const text = this.messageTextTarget.textContent.trim()
    return text === "" || text === "..."
  }

  updateGroupName(event) {
    // Prevent form submission on enter
    if (event.type === "keydown") {
      event.target.blur()
      return
    }

    const groupId = event.target.dataset.groupId
    const newName = event.target.value.trim()
    if (!newName) return

    // Send update via fetch
    fetch(`/game_sessions/${this.codeValue}/update_group_name`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: `group_id=${groupId}&name=${encodeURIComponent(newName)}`
    })
  }

  startTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }

    this.timeoutRequested = false
    this.updateTimerDisplay()
    this.timerInterval = setInterval(() => this.updateTimerDisplay(), 100)
  }

  updateTimerDisplay() {
    if (!this.hasTimerValueTarget || !this.roundStartedAtValue) return

    const roundStartedAt = new Date(this.roundStartedAtValue)
    const now = new Date()
    const elapsed = (now - roundStartedAt) / 1000
    const remaining = Math.max(0, this.timeLimitValue - elapsed)

    this.timerValueTarget.textContent = Math.ceil(remaining)

    if (remaining <= 3) {
      this.timerValueTarget.classList.add("urgent")
    } else {
      this.timerValueTarget.classList.remove("urgent")
    }

    // Time's up: ask the server to resolve the round (it re-checks expiry,
    // so it's safe for every client to send this once)
    if (remaining <= 0 && !this.timeoutRequested) {
      this.timeoutRequested = true
      this.subscription.perform("check_timeout", {})
    }
  }
}
