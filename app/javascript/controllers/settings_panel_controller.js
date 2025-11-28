import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    expanded: Boolean
  }
  
  static targets = ["settingsIcon", "closeIcon"]
  
  connect() {
    // Initialize based on expanded value
    this.updatePanelState()
  }
  
  toggle() {
    this.expandedValue = !this.expandedValue
    this.updatePanelState()
  }
  
  updatePanelState() {
    if (this.expandedValue) {
      this.element.classList.remove('collapsed')
      this.element.classList.add('expanded')
      // Show close icon, hide settings icon
      this.settingsIconTarget.classList.add('hidden')
      this.closeIconTarget.classList.remove('hidden')
    } else {
      this.element.classList.remove('expanded')
      this.element.classList.add('collapsed')
      // Show settings icon, hide close icon
      this.settingsIconTarget.classList.remove('hidden')
      this.closeIconTarget.classList.add('hidden')
    }
  }
}

