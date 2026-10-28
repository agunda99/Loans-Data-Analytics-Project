import { CalendarDays, ChevronDown, Download } from 'lucide-react'

export default function PageHeading({ page, role, period, onPeriodChange, onExport }) {
  const overview = page === 'Overview'
  return <section className="page-heading">
    <div>
      <div className="eyebrow"><span className="eyebrow-line" /> PORTFOLIO INTELLIGENCE <span className="eyebrow-dot">·</span> MONDAY, 26 OCTOBER 2026</div>
      <h1>{overview ? 'Good morning, Agunda' : page}<span className="heading-period">.</span></h1>
      <p className="heading-subtitle">{overview ? 'Here’s the pulse of your credit portfolio today.' : role.description + ' · a clear view of what needs your attention.'}</p>
    </div>
    <div className="heading-actions">
      <label className="period-select"><CalendarDays size={16} /><select aria-label="Reporting period" value={period} onChange={(event) => onPeriodChange(event.target.value)}>
        <option>Last 3 months</option><option>Last 7 months</option><option>Last 12 months</option>
      </select><ChevronDown size={14} /></label>
      <button className="export-button" onClick={onExport}><Download size={16} /><span>Export</span></button>
    </div>
  </section>
}
