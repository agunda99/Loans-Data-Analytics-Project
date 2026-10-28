import { useState } from 'react'
import { formatCurrency } from '../data/dashboard.js'

export default function PortfolioChart({ data }) {
  const [activePoint, setActivePoint] = useState(null)
  const points = data.map((point, index) => {
    const x = data.length === 1 ? 413 : 47 + index * (733 / (data.length - 1))
    return {
      ...point,
      x,
      principalY: 160 - ((point.principal - 40) / 50) * 130,
      parY: 160 - (point.par / 12) * 130,
    }
  })
  const makeLine = (key) => points.map((point, index) => `${index ? 'L' : 'M'}${point.x},${point[key]}`).join(' ')
  const principalLine = makeLine('principalY')
  const parLine = makeLine('parY')
  const principalArea = `${principalLine} L${points.at(-1).x},160 L${points[0].x},160 Z`
  const parArea = `${parLine} L${points.at(-1).x},160 L${points[0].x},160 Z`
  const tooltipPoint = points.find((point) => point.month === activePoint)

  return <div className="chart-wrap">
    {tooltipPoint && <div className="chart-tooltip" style={{ left: `${Math.min(Math.max(tooltipPoint.x / 8, 12), 88)}%`, top: `${Math.max((tooltipPoint.principalY / 1.9) - 31, 1)}%` }}>
      <strong>{tooltipPoint.month.slice(0, 3)} 20{tooltipPoint.month.slice(-2)}</strong><span>Outstanding principal <b>{formatCurrency(tooltipPoint.principal)}</b></span><span>PAR 30+ <b>{tooltipPoint.par}%</b></span>
    </div>}
    <svg viewBox="0 0 800 190" preserveAspectRatio="none" role="img" aria-label="Outstanding principal increased while PAR 30 plus improved over the reporting period" onMouseLeave={() => setActivePoint(null)}>
      <defs>
        <linearGradient id="principalFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#4d927a" stopOpacity=".20" /><stop offset="100%" stopColor="#4d927a" stopOpacity=".015" /></linearGradient>
        <linearGradient id="parFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#e3b15f" stopOpacity=".13" /><stop offset="100%" stopColor="#e3b15f" stopOpacity=".01" /></linearGradient>
      </defs>
      {[30, 95, 160].map((y) => <line key={y} x1="42" x2="790" y1={y} y2={y} stroke="#eef1ed" strokeDasharray="3 4" />)}
      <text x="1" y="34" className="chart-axis-label">90M</text><text x="1" y="99" className="chart-axis-label">65M</text><text x="1" y="164" className="chart-axis-label">40M</text>
      <path d={principalArea} fill="url(#principalFill)" /><path d={parArea} fill="url(#parFill)" />
      <path d={principalLine} fill="none" stroke="#4d927a" strokeWidth="2.5" vectorEffect="non-scaling-stroke" />
      <path d={parLine} fill="none" stroke="#dfa84e" strokeWidth="2" strokeDasharray="5 4" vectorEffect="non-scaling-stroke" />
      {points.map((point) => <g key={point.month} onMouseEnter={() => setActivePoint(point.month)} onFocus={() => setActivePoint(point.month)} tabIndex="0" role="button" aria-label={`${point.month}: principal ${formatCurrency(point.principal)}, PAR 30 plus ${point.par}%`}>
        <circle cx={point.x} cy={point.principalY} r="11" fill="transparent" /><circle cx={point.x} cy={point.parY} r="11" fill="transparent" />
        <circle cx={point.x} cy={point.principalY} r={activePoint === point.month ? 4 : 2.5} fill="#4d927a" stroke="white" strokeWidth="1.5" />
        <circle cx={point.x} cy={point.parY} r={activePoint === point.month ? 4 : 2.5} fill="#dfa84e" stroke="white" strokeWidth="1.5" />
        <text x={point.x} y="185" textAnchor="middle" className="chart-month-label">{point.month.slice(0, 3)}</text>
      </g>)}
    </svg>
  </div>
}
