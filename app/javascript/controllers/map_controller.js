import { Controller } from "@hotwired/stimulus"

// Leaflet will be loaded as a global script, accessed via window.L

export default class extends Controller {
  static targets = ["mapContainer", "startDate", "endDate"]
  
  connect() {
    this.map = null
    this.heatLayer = null
    // Wait for Leaflet to be available before initializing
    this.waitForLeaflet().then(() => {
      this.initializeMap()
      this.loadTrackpoints()
    })
  }
  
  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
  
  initializeMap() {
    const L = window.L
    // Initialize map centered on a default location (you can adjust this)
    this.map = L.map(this.mapContainerTarget).setView([37.7749, -122.4194], 2)
    
    // Fix for default marker icons in Leaflet
    delete L.Icon.Default.prototype._getIconUrl
    L.Icon.Default.mergeOptions({
      iconRetinaUrl: 'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-icon-2x.png',
      iconUrl: 'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-icon.png',
      shadowUrl: 'https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-shadow.png',
    })
    
    // Add OpenStreetMap tile layer
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 19
    }).addTo(this.map)
  }
  
  async loadTrackpoints() {
    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value
    
    // Wait for heat plugin to be available
    await this.waitForHeatPlugin()
    
    try {
      const response = await fetch(`/maps/trackpoints?start_date=${startDate}&end_date=${endDate}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error('Failed to load trackpoints')
      }
      
      const data = await response.json()
      
      // Remove existing heat layer if it exists
      if (this.heatLayer) {
        this.map.removeLayer(this.heatLayer)
      }
      
      // Add new heat layer
      if (data.trackpoints && data.trackpoints.length > 0) {
        const L = window.L
        // Check if heat plugin is available
        if (typeof L === 'undefined' || typeof L.heatLayer === 'undefined') {
          console.error('Leaflet.heat plugin not loaded')
          const infoElement = document.getElementById('map-info')
          if (infoElement) {
            infoElement.textContent = 'Error: Heat map plugin not loaded. Please refresh the page.'
            infoElement.className = 'text-sm text-red-400'
          }
          return
        }
        
        this.heatLayer = L.heatLayer(data.trackpoints, {
          radius: 10,
          blur: 10,
          maxZoom: 17,
          max: 1.0,
          gradient: {
            0.0: 'blue',
            0.5: 'cyan',
            0.7: 'lime',
            0.9: 'yellow',
            1.0: 'red'
          }
        }).addTo(this.map)
        
        // Fit map to bounds of all points
        const bounds = data.trackpoints.map(tp => [tp[0], tp[1]])
        if (bounds.length > 0) {
          this.map.fitBounds(bounds, { padding: [50, 50] })
        }
        
        // Update info
        const infoElement = document.getElementById('map-info')
        if (infoElement) {
          infoElement.textContent = `Showing ${data.count.toLocaleString()} trackpoints from ${new Date(data.date_range.start).toLocaleDateString()} to ${new Date(data.date_range.end).toLocaleDateString()}`
        }
      } else {
        // Update info for no data
        const infoElement = document.getElementById('map-info')
        if (infoElement) {
          infoElement.textContent = `No trackpoints found for the selected date range`
        }
      }
    } catch (error) {
      console.error('Error loading trackpoints:', error)
      const infoElement = document.getElementById('map-info')
      if (infoElement) {
        infoElement.textContent = `Error loading trackpoints: ${error.message}`
        infoElement.className = 'text-sm text-red-400'
      }
    }
  }
  
  updateMap() {
    this.loadTrackpoints()
  }
  
  waitForLeaflet() {
    return new Promise((resolve, reject) => {
      // Check if already available
      if (typeof window.L !== 'undefined') {
        resolve()
        return
      }
      
      // Wait for it to load (max 10 seconds)
      let attempts = 0
      const maxAttempts = 100
      const checkInterval = setInterval(() => {
        attempts++
        if (typeof window.L !== 'undefined') {
          clearInterval(checkInterval)
          resolve()
        } else if (attempts >= maxAttempts) {
          clearInterval(checkInterval)
          reject(new Error('Leaflet failed to load'))
        }
      }, 100)
    })
  }
  
  waitForHeatPlugin() {
    return new Promise((resolve, reject) => {
      // Check if already available
      if (typeof window.L !== 'undefined' && typeof window.L.heatLayer !== 'undefined') {
        resolve()
        return
      }
      
      // Wait for it to load (max 10 seconds)
      let attempts = 0
      const maxAttempts = 100
      const checkInterval = setInterval(() => {
        attempts++
        if (typeof window.L !== 'undefined' && typeof window.L.heatLayer !== 'undefined') {
          clearInterval(checkInterval)
          resolve()
        } else if (attempts >= maxAttempts) {
          clearInterval(checkInterval)
          reject(new Error('Heat plugin failed to load'))
        }
      }, 100)
    })
  }
}

