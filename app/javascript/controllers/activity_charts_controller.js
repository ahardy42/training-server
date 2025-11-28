import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    chartData: Object,
    distanceUnit: String,
    elevationUnit: String,
    speedUnit: String,
    paceUnit: String
  }

  static targets = ["heartrateChart", "powerChart", "cadenceChart", "speedChart", "paceChart", "basisSelector"]

  connect() {
    this.basis = "distance" // default to distance
    this.renderAllCharts()
  }

  basisChanged(event) {
    this.basis = event.target.value
    this.renderAllCharts()
  }

  renderAllCharts() {
    if (!this.chartDataValue) {
      console.error("Chart data not available")
      return
    }
    
    // Wait for Plotly to be available (loaded via script tag)
    if (!window.Plotly) {
      // Retry after a short delay if Plotly hasn't loaded yet
      setTimeout(() => this.renderAllCharts(), 100)
      return
    }

    const data = this.chartDataValue
    let xAxis
    let xAxisTitle
    
    if (this.basis === "distance") {
      xAxis = data.distance || []
      xAxisTitle = `Distance (${this.distanceUnitValue})`
    } else {
      // Convert seconds to hours for better display
      xAxis = (data.time_seconds || []).map(seconds => seconds / 3600.0)
      xAxisTitle = "Time (hours)"
    }

    // If x-axis data is empty, don't render any charts
    if (!xAxis || xAxis.length === 0) {
      return
    }

    // Render each chart
    this.renderChart(this.heartrateChartTarget, {
      title: "Heart Rate",
      yAxisTitle: "Heart Rate (bpm)",
      data: data.heartrate,
      color: "#ef4444"
    }, xAxis, xAxisTitle)

    this.renderChart(this.powerChartTarget, {
      title: "Power",
      yAxisTitle: "Power (W)",
      data: data.power,
      color: "#f59e0b"
    }, xAxis, xAxisTitle)

    this.renderChart(this.cadenceChartTarget, {
      title: "Cadence",
      yAxisTitle: "Cadence (rpm)",
      data: data.cadence,
      color: "#10b981"
    }, xAxis, xAxisTitle)

    this.renderChart(this.speedChartTarget, {
      title: "Speed",
      yAxisTitle: `Speed (${this.speedUnitValue})`,
      data: data.speed,
      color: "#3b82f6"
    }, xAxis, xAxisTitle)

    this.renderChart(this.paceChartTarget, {
      title: "Pace",
      yAxisTitle: `Pace (${this.paceUnitValue})`,
      data: data.pace,
      color: "#8b5cf6"
    }, xAxis, xAxisTitle)
  }

  renderChart(container, config, xAxis, xAxisTitle) {
    if (!container) {
      return
    }

    // Get the chart card wrapper
    const chartCard = container.closest('.bg-shadow-grey-700')

    // Check if data exists and is an array
    if (!config.data || !Array.isArray(config.data) || config.data.length === 0) {
      // Hide the chart container's parent (the card wrapper)
      if (chartCard) {
        chartCard.style.display = 'none'
      }
      return
    }

    // Filter out null values and create corresponding x-axis values
    const filteredData = []
    const filteredX = []
    
    config.data.forEach((value, index) => {
      if (value !== null && value !== undefined) {
        filteredData.push(value)
        filteredX.push(xAxis[index])
      }
    })

    // If no valid data points after filtering, hide the chart
    if (filteredData.length === 0) {
      if (chartCard) {
        chartCard.style.display = 'none'
      }
      return
    }

    // Ensure the chart card is visible if we have data
    if (chartCard) {
      chartCard.style.display = ''
    }

    const elevationData = this.chartDataValue.elevation
    const filteredElevation = []
    const filteredElevationX = []
    
    elevationData.forEach((value, index) => {
      if (config.data[index] !== null && config.data[index] !== undefined) {
        filteredElevation.push(value || 0)
        filteredElevationX.push(xAxis[index])
      }
    })

    const trace1 = {
      x: filteredX,
      y: filteredData,
      name: config.title,
      type: "scatter",
      mode: "lines",
      line: { color: config.color, width: 2 },
      yaxis: "y"
    }

    const trace2 = {
      x: filteredElevationX,
      y: filteredElevation,
      name: "Elevation",
      type: "scatter",
      mode: "lines",
      line: { color: "#6b7280", width: 1.5 },
      yaxis: "y2",
      fill: "tozeroy",
      fillcolor: "rgba(107, 114, 128, 0.1)"
    }

    const layout = {
      title: {
        text: config.title,
        font: { color: "#ffffff", size: 16 }
      },
      xaxis: {
        title: { text: xAxisTitle, font: { color: "#ffffff" } },
        gridcolor: "#374151",
        color: "#9ca3af",
        showgrid: true
      },
      yaxis: {
        title: { text: config.yAxisTitle, font: { color: "#ffffff" } },
        gridcolor: "#374151",
        color: "#9ca3af",
        showgrid: true
      },
      yaxis2: {
        title: { text: `Elevation (${this.elevationUnitValue})`, font: { color: "#9ca3af" } },
        overlaying: "y",
        side: "right",
        gridcolor: "#374151",
        color: "#9ca3af",
        showgrid: false
      },
      plot_bgcolor: "#1f2937",
      paper_bgcolor: "#111827",
      font: { color: "#ffffff" },
      margin: { l: 60, r: 60, t: 80, b: 60 },
      hovermode: "x unified",
      legend: {
        orientation: "h",
        x: 0.5,
        xanchor: "center",
        y: 1.1,
        yanchor: "top",
        font: { color: "#ffffff" },
        bgcolor: "rgba(0,0,0,0)",
        bordercolor: "#374151"
      }
    }

    const config_plotly = {
      displaylogo: false
    }

    Plotly.newPlot(container, [trace1, trace2], layout, config_plotly)
  }
}

