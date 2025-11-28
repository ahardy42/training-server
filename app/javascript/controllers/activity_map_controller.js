import { Controller } from "@hotwired/stimulus"

// Leaflet will be loaded as a global script, accessed via window.L

export default class extends Controller {
  static values = {
    trackpoints: Array
  }
  
  connect() {
    this.map = null
    this.routeLine = null
    // Wait for Leaflet to be available before initializing
    this.waitForLeaflet().then(() => {
      this.initializeMap()
      this.drawRoute()
    })
  }
  
  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
  
  initializeMap() {
    const L = window.L
    const trackpoints = this.trackpointsValue
    
    if (!trackpoints || trackpoints.length === 0) {
      return
    }
    
    // Calculate center and bounds from trackpoints
    const bounds = trackpoints.map(tp => [tp[0], tp[1]])
    const center = this.calculateCenter(trackpoints)
    
    // Initialize map
    this.map = L.map(this.element).setView(center, 13)
    
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
    
    // Fit map to bounds with padding
    if (bounds.length > 0) {
      this.map.fitBounds(bounds, { padding: [50, 50] })
    }
  }
  
  drawRoute() {
    const L = window.L
    const trackpoints = this.trackpointsValue
    
    if (!trackpoints || trackpoints.length === 0 || !this.map) {
      return
    }
    
    // Remove existing route line if it exists
    if (this.routeLine) {
      this.map.removeLayer(this.routeLine)
    }
    
    // Create polyline from trackpoints
    const latlngs = trackpoints.map(tp => [tp[0], tp[1]])
    
    // Draw the route line
    this.routeLine = L.polyline(latlngs, {
      color: '#3b82f6', // cobalt-blue-500
      weight: 4,
      opacity: 0.8,
      smoothFactor: 1
    }).addTo(this.map)
    
    // Add start marker
    if (trackpoints.length > 0) {
      const startPoint = trackpoints[0]
      const startMarker = L.marker([startPoint[0], startPoint[1]], {
        icon: L.divIcon({
          className: 'custom-div-icon',
          html: "<div style='background-color:#10b981;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3);'></div>",
          iconSize: [12, 12],
          iconAnchor: [6, 6]
        })
      }).addTo(this.map)
      startMarker.bindPopup('Start')
    }
    
    // Add end marker
    if (trackpoints.length > 1) {
      const endPoint = trackpoints[trackpoints.length - 1]
      const endMarker = L.marker([endPoint[0], endPoint[1]], {
        icon: L.divIcon({
          className: 'custom-div-icon',
          html: "<div style='background-color:#ef4444;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3);'></div>",
          iconSize: [12, 12],
          iconAnchor: [6, 6]
        })
      }).addTo(this.map)
      endMarker.bindPopup('End')
    }
  }
  
  calculateCenter(trackpoints) {
    if (!trackpoints || trackpoints.length === 0) {
      return [37.7749, -122.4194] // Default to San Francisco
    }
    
    const sum = trackpoints.reduce(
      (acc, tp) => [acc[0] + tp[0], acc[1] + tp[1]],
      [0, 0]
    )
    
    return [sum[0] / trackpoints.length, sum[1] / trackpoints.length]
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
}

