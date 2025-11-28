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
        color: hours.map(h => {
          // Color gradient based on value
          if (h === 0) return '#374151'
          if (h < 10) return '#3b82f6'
          if (h < 20) return '#8b5cf6'
          if (h < 30) return '#ec4899'
          return '#ef4444'
        }),
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
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
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

    const trace = {
      z: z,
      x: weekKeys,
      y: dayNames,
      type: 'heatmap',
      colorscale: [
        [0, '#1f2937'],      // No activity - dark gray
        [0.1, '#3b82f6'],    // Low activity - blue
        [0.3, '#8b5cf6'],    // Medium activity - purple
        [0.6, '#ec4899'],    // High activity - pink
        [1.0, '#ef4444']     // Very high activity - red
      ],
      colorbar: {
        title: {
          text: 'Hours',
          font: { color: '#ffffff' }
        },
        tickfont: { color: '#ffffff' },
        tickcolor: '#ffffff'
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
        showgrid: true,
        side: 'bottom'
      },
      yaxis: {
        title: { text: 'Day of Week', font: { color: '#ffffff' } },
        gridcolor: '#374151',
        color: '#9ca3af',
        showgrid: true
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

