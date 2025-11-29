import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-upload-status"
export default class extends Controller {
  static targets = ["message", "spinner"]
  static values = { 
    checkUrl: String,
    pollInterval: { type: Number, default: 5000 }
  }

  connect() {
    // Start polling if we're on the activities page
    if (this.hasCheckUrlValue) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    // Check immediately
    this.checkStatus()
    
    // Then poll every 5 seconds
    this.pollTimer = setInterval(() => {
      this.checkStatus()
    }, this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.checkUrlValue, {
        method: "GET",
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      
      if (data.bulk_upload_in_progress) {
        this.showMessage()
      } else {
        this.hideMessage()
        // Stop polling once job is complete
        this.stopPolling()
      }
    } catch (error) {
      console.error("Error checking bulk upload status:", error)
      // Don't stop polling on error, just log it
    }
  }

  showMessage() {
    if (this.hasMessageTarget) {
      this.messageTarget.classList.remove("hidden")
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
  }

  hideMessage() {
    if (this.hasMessageTarget) {
      this.messageTarget.classList.add("hidden")
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden")
    }
  }
}

