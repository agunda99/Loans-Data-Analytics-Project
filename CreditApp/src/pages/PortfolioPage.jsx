import { ShieldCheck } from 'lucide-react'
import { segments } from '../data/dashboard.js'

const portfolioMetrics = [
  ['KES 84.6M', 'Outstanding principal', 'Open-loan principal exposure'],
  ['6.42%', 'PAR 30+', '30+ DPD / open principal'],
  ['143', 'Loans 30+ DPD', 'Accounts needing attention'],
  ['KES 2.18M', 'Illustrative ECL', 'Demonstration assumptions'],
]

export default function PortfolioPage() {
  return <section className="detail-page">
    <div className="detail-summary">
      <div className="detail-title"><div className="detail-icon"><ShieldCheck size={20} /></div><div><span className="panel-kicker">PORTFOLIO EXPLORER</span><h2>Portfolio at a glance</h2></div></div>
      <p>Monitor principal exposure, delinquency, and product concentration. PAR is measured against open-loan principal exposure.</p>
    </div>
    <section className="detail-kpis">
      {portfolioMetrics.map(([value, name, note]) => <div className="detail-kpi" key={name}><span>{name}</span><strong>{value}</strong><small>{note}</small></div>)}
    </section>
    <section className="detail-segments panel">
      <div className="panel-heading"><div><span className="panel-kicker">PRODUCT PERFORMANCE</span><h2>Exposure and portfolio quality</h2></div><span className="as-of"><span /> As of today</span></div>
      <div className="detail-segment-head"><span>PRODUCT</span><span>PRINCIPAL</span><span>PORTFOLIO SHARE</span><span>PAR 30+</span><span>STATUS</span></div>
      {segments.map((segment) => <div className="detail-segment-row" key={segment.name}>
        <strong>{segment.name}</strong><span>{segment.amount}</span><div className="mini-progress"><i style={{ width: `${segment.value}%`, background: segment.color }} /></div>
        <strong className={parseFloat(segment.par) > 8 ? 'par-alert' : ''}>{segment.par}</strong><span className={`quality-label ${parseFloat(segment.par) > 8 ? 'quality-watch' : ''}`}><i />{parseFloat(segment.par) > 8 ? 'Watch' : 'On track'}</span>
      </div>)}
    </section>
    <div className="method-note"><ShieldCheck size={16} /><span><strong>Metric note</strong> PAR 30+ is outstanding principal on open loans with 30 or more days past due, divided by total outstanding principal for the same population.</span></div>
    <div className="method-note"><ShieldCheck size={16} /><span><strong>Illustrative ECL</strong> Shown values use demonstration assumptions only; they are not approved IFRS 9 or regulatory estimates.</span></div>
  </section>
}
