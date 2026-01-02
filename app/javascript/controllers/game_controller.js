import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messageDisplay", "timer", "timerValue", "wordInput", "wordField", "playerList", "playerCount", "finalMessage"]
  static values = { 
    code: String, 
    playerToken: String, 
    status: String,
    timeLimit: Number,
    roundStartedAt: String
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
        this.addPlayer(data.player_name, data.player_count)
        break
      case "game_started":
        window.location.reload()
        break
      case "word_revealed":
        this.revealWord(data.word, data.message)
        break
      case "game_ended":
        this.endGame(data.message)
        break
    }
  }

  addPlayer(name, count) {
    if (this.hasPlayerListTarget) {
      const li = document.createElement("li")
      li.textContent = name
      this.playerListTarget.appendChild(li)
    }
    if (this.hasPlayerCountTarget) {
      this.playerCountTarget.textContent = count
    }
  }

  revealWord(word, message) {
    if (this.hasMessageDisplayTarget) {
      this.messageDisplayTarget.innerHTML = message || '<span class="placeholder">The message will appear here...</span>'
      
      // Flash effect
      this.messageDisplayTarget.classList.add("flash")
      setTimeout(() => this.messageDisplayTarget.classList.remove("flash"), 500)
    }
    
    // Reset word input
    if (this.hasWordInputTarget) {
      this.wordInputTarget.innerHTML = `
        <input type="text" 
               data-game-target="wordField" 
               data-action="keydown.enter->game#submitWord"
               placeholder="Enter your word..." 
               autofocus>
        <button data-action="click->game#submitWord" class="btn btn-primary">Submit</button>
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

  endGame(message) {
    window.location.reload()
  }

  submitWord() {
    if (!this.hasWordFieldTarget) return
    
    const word = this.wordFieldTarget.value.trim()
    if (!word) return
    
    // Send via ActionCable
    this.subscription.perform("submit_word", {
      word: word,
      player_token: this.playerTokenValue
    })
    
    // Update UI to show submitted
    if (this.hasWordInputTarget) {
      this.wordInputTarget.innerHTML = '<p class="submitted-message">✓ Word submitted! Waiting for others...</p>'
    }
  }

  startTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
    
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
  }
}
