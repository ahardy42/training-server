import { Controller } from "@hotwired/stimulus"

// Leaflet will be loaded as a global script, accessed via window.L

export default class extends Controller {
  static targets = ["mapContainer", "startDate", "endDate", "activityType"]
  
  connect() {
    this.map = null
    this.heatLayer = null
    this.boundsUpdateTimeout = null
    this.initialLoad = true
    // Wait for Leaflet to be available before initializing
    this.waitForLeaflet().then(() => {
      this.initializeMap()
      this.loadTrackpoints()
      this.setupMapEventListeners()
    })
  }
  
  disconnect() {
    if (this.boundsUpdateTimeout) {
      clearTimeout(this.boundsUpdateTimeout)
    }
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
  
  setupMapEventListeners() {
    // Debounce map move/zoom events to avoid too many API calls
    this.map.on('moveend', () => {
      this.debouncedUpdateMap()
    })
    
    this.map.on('zoomend', () => {
      this.debouncedUpdateMap()
    })
  }
  
  debouncedUpdateMap() {
    // Clear existing timeout
    if (this.boundsUpdateTimeout) {
      clearTimeout(this.boundsUpdateTimeout)
    }
    
    // Set new timeout - wait 300ms after user stops moving/zooming
    this.boundsUpdateTimeout = setTimeout(() => {
      this.loadTrackpoints()
    }, 300)
  }
  
  async loadTrackpoints() {
    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value
    const activityType = this.activityTypeTarget.value || 'all'
    
    // Get current map bounds if map is initialized and this is not the initial load
    // On initial load, don't filter by bounds so we can fit to all data
    let bounds = null
    if (this.map && !this.initialLoad) {
      const mapBounds = this.map.getBounds()
      bounds = {
        north: mapBounds.getNorth(),
        south: mapBounds.getSouth(),
        east: mapBounds.getEast(),
        west: mapBounds.getWest()
      }
    }
    
    // Wait for heat plugin to be available
    await this.waitForHeatPlugin()
    
    try {
      const url = new URL('/maps/trackpoints', window.location.origin)
      url.searchParams.set('start_date', startDate)
      url.searchParams.set('end_date', endDate)
      if (activityType && activityType !== 'all') {
        url.searchParams.set('activity_type', activityType)
      }
      
      // Add map bounds to filter by visible area
      if (bounds) {
        url.searchParams.set('north', bounds.north)
        url.searchParams.set('south', bounds.south)
        url.searchParams.set('east', bounds.east)
        url.searchParams.set('west', bounds.west)
      }
      
      const response = await fetch(url.toString(), {
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
          radius: 20,
          blur: 15,
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
        
        // Only fit bounds on initial load
        // Don't auto-fit on subsequent loads to preserve user's zoom/pan
        if (this.initialLoad && data.trackpoints.length > 0) {
          const pointBounds = data.trackpoints.map(tp => [tp[0], tp[1]])
          if (pointBounds.length > 0) {
            this.map.fitBounds(pointBounds, { padding: [50, 50] })
          }
          this.initialLoad = false
        }
        
        // Update info
        const infoElement = document.getElementById('map-info')
        if (infoElement) {
          const activityType = this.activityTypeTarget.value || 'all'
          const activityTypeText = activityType !== 'all' ? ` (${activityType})` : ''
          const sampledText = data.sampled_count && data.sampled_count < data.count 
            ? ` (showing ${data.sampled_count.toLocaleString()} sampled points)` 
            : ''
          const boundsText = bounds ? ' in visible area' : ''
          infoElement.textContent = `Showing ${data.count.toLocaleString()} trackpoints${activityTypeText}${sampledText}${boundsText} from ${new Date(data.date_range.start).toLocaleDateString()} to ${new Date(data.date_range.end).toLocaleDateString()}`
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
    // When user manually updates filters, treat it like initial load
    // so we fit to bounds of the new filtered data
    this.initialLoad = true
    // Clear any pending bounds updates
    if (this.boundsUpdateTimeout) {
      clearTimeout(this.boundsUpdateTimeout)
    }
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

