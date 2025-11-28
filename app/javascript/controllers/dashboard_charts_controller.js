import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    monthlyHours: Object,
    weeklyDailyTime: Object,
    year: Number
  }

  static targets = ["monthlyChart", "weeklyChart"]

  connect() {
    // Wait for Plotly to be available
    if (!window.Plotly) {
      setTimeout(() => this.connect(), 100)
      return
    }

    this.renderMonthlyChart()
    this.renderWeeklyChart()
  }

  renderMonthlyChart() {
    if (!this.monthlyChartTarget || !this.monthlyHoursValue) {
      return
    }

    const monthlyData = this.monthlyHoursValue
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    const hours = months.map((_, index) => monthlyData[index + 1] || 0)

    // Check if we have any data
    const hasData = hours.some(h => h > 0)
    if (!hasData) {
      const chartCard = this.monthlyChartTarget.closest('.bg-shadow-grey-700')
      if (chartCard) {
        chartCard.style.display = 'none'
      }
      return
    }

    // Ensure chart is visible
    const chartCard = this.monthlyChartTarget.closest('.bg-shadow-grey-700')
    if (chartCard) {
      chartCard.style.display = ''
    }

    const trace = {
      x: months,
      y: hours,
      type: 'bar',
      marker: {
        color: '#6899ca', // rich-cerulean-400
        line: {
          color: '#1f2937',
          width: 1
        }
      }
    }

    const layout = {
      title: {
        text: `Activity Hours per Month - ${this.yearValue}`,
        font: { color: '#ffffff', size: 18 }
      },
      xaxis: {
        title: { text: 'Month', font: { color: '#ffffff' } },
        gridcolor: '#374151',
        color: '#9ca3af',
        showgrid: true
      },
      yaxis: {
        title: { text: 'Hours', font: { color: '#ffffff' } },
        gridcolor: '#374151',
        color: '#9ca3af',
        showgrid: true
      },
      plot_bgcolor: '#1f2937',
      paper_bgcolor: '#111827',
      font: { color: '#ffffff' },
      margin: { l: 60, r: 40, t: 80, b: 60 },
      hovermode: 'x unified',
      legend: {
        orientation: 'h',
        x: 0.5,
        xanchor: 'center',
        y: 1.1,
        yanchor: 'top',
        font: { color: '#ffffff' },
        bgcolor: 'rgba(0,0,0,0)',
        bordercolor: '#374151'
      }
    }

    const config = {
      displaylogo: false
    }

    Plotly.newPlot(this.monthlyChartTarget, [trace], layout, config)
  }

  renderWeeklyChart() {
    if (!this.weeklyChartTarget || !this.weeklyDailyTimeValue) {
      return
    }

    const weeklyData = this.weeklyDailyTimeValue
    const weekKeys = Object.keys(weeklyData).sort()
    
    if (weekKeys.length === 0) {
      const chartCard = this.weeklyChartTarget.closest('.bg-shadow-grey-700')
      if (chartCard) {
        chartCard.style.display = 'none'
      }
      return
    }

    // Prepare data for heatmap
    // Rows = days of week (Sunday = 0 to Saturday = 6)
    // Columns = weeks
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    const z = []

    // Build z matrix: rows are days (0-6), columns are weeks
    dayNames.forEach((_, dayIndex) => {
      const row = []
      weekKeys.forEach(weekKey => {
        const dayValue = weeklyData[weekKey][dayIndex]
        row.push(dayValue || 0)
      })
      z.push(row)
    })

    // Find max value for color scale
    const allValues = z.flat().filter(v => v !== null && v !== undefined)
    const maxVal = allValues.length > 0 ? Math.max(...allValues) : 0

    // Check if we have any data
    if (maxVal === 0) {
      const chartCard = this.weeklyChartTarget.closest('.bg-shadow-grey-700')
      if (chartCard) {
        chartCard.style.display = 'none'
      }
      return
    }

    // Ensure chart is visible
    const chartCard = this.weeklyChartTarget.closest('.bg-shadow-grey-700')
    if (chartCard) {
      chartCard.style.display = ''
    }

    // Build colorscale with cerulean blue and opacity based on value
    // rich-cerulean-400: #6899ca (RGB: 104, 153, 202)
    // Background: #111827 (RGB: 17, 24, 39)
    // To show opacity in colorbar, we blend cerulean blue with background
    // Opacity ranges from 0.1 (low) to 1.0 (high)
    // Blend formula: color = cerulean * opacity + background * (1 - opacity)
    const colorscale = []
    for (let i = 0; i <= 10; i++) {
      const ratio = i / 10
      const opacity = 0.1 + (ratio * 0.9) // 0.1 to 1.0
      // Blend cerulean blue (#6899ca = rgb(104, 153, 202)) with background (#111827 = rgb(17, 24, 39))
      const r = Math.round(104 * opacity + 17 * (1 - opacity))
      const g = Math.round(153 * opacity + 24 * (1 - opacity))
      const b = Math.round(202 * opacity + 39 * (1 - opacity))
      colorscale.push([ratio, `rgb(${r}, ${g}, ${b})`])
    }

    const trace = {
      z: z,
      x: weekKeys,
      y: dayNames,
      type: 'heatmap',
      colorscale: colorscale,
      colorbar: {
        title: {
          text: 'Hours',
          font: { color: '#ffffff' }
        },
        tickfont: { color: '#ffffff' },
        tickcolor: '#ffffff',
        outlinecolor: '#374151',
        bordercolor: '#374151',
        bgcolor: 'rgba(0,0,0,0)'
      },
      hovertemplate: 'Week: %{x}<br>Day: %{y}<br>Hours: %{z:.2f}<extra></extra>'
    }

    const layout = {
      title: {
        text: `Activity Heatmap - ${this.yearValue}`,
        font: { color: '#ffffff', size: 18 }
      },
      xaxis: {
        title: { text: 'Week', font: { color: '#ffffff' } },
        gridcolor: '#374151',
        color: '#9ca3af',
        showgrid: false,
        side: 'bottom'
      },
      yaxis: {
        title: { text: 'Day of Week', font: { color: '#ffffff' } },
        gridcolor: '#374151',
        color: '#9ca3af',
        showgrid: false
      },
      plot_bgcolor: '#1f2937',
      paper_bgcolor: '#111827',
      font: { color: '#ffffff' },
      margin: { l: 80, r: 40, t: 80, b: 100 },
      hovermode: 'closest',
      legend: {
        orientation: 'h',
        x: 0.5,
        xanchor: 'center',
        y: 1.1,
        yanchor: 'top',
        font: { color: '#ffffff' },
        bgcolor: 'rgba(0,0,0,0)',
        bordercolor: '#374151'
      }
    }

    const config = {
      displaylogo: false
    }

    Plotly.newPlot(this.weeklyChartTarget, [trace], layout, config)
  }
}

