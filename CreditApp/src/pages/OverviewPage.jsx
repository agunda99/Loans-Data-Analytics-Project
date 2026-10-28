import {
  ArrowDownRight,
  ArrowRight,
  ArrowUpRight,
  HandCoins,
  MoreHorizontal,
  Sparkles,
} from 'lucide-react'
import AuditTrail from '../components/AuditTrail.jsx'
import PortfolioChart from '../components/PortfolioChart.jsx'
import { insights, metrics, segments } from '../data/dashboard.js'

export default function OverviewPage({
  role,
  period,
  trend,
  applications,
  collections,
  audit,
  canReview,
  canLogCollections,
  onNavigate,
  onNotify,
  onReview,
  onLogCollection,
}) {
  const visibleCards = role.cards
  const isCollections = role.name === 'Collections'
  return <>
    <section className="metric-grid" aria-label="Portfolio key metrics">
      {visibleCards.map((name, index) => {
        const metric = metrics[name]
        const Icon = metric.icon
        const TrendIcon = metric.direction === 'down' ? ArrowDownRight : metric.direction === 'flat' ? ArrowRight : ArrowUpRight
        return <article className={`metric-card metric-${index + 1}`} key={name}>
          <div className="metric-top"><span>{name}</span><span className="metric-icon"><Icon size={17} /></span></div>
          <div className="metric-value">{metric.value}</div>
          <div className="metric-foot"><span className={`metric-change ${metric.positive === false ? 'change-neutral' : ''}`}><TrendIcon size={14} />{metric.change}</span><span>{metric.sub}</span></div>
        </article>
      })}
    </section>

    <section className="insight-strip">
      <div className="insight-label"><span className="insight-spark"><Sparkles size={16} /></span><strong>Today’s signals</strong><span className="signal-count">{insights.length}</span></div>
      {insights.map((insight) => <button className="signal" key={insight.title} onClick={() => onNavigate(insight.page)}>
        <span className={`signal-dot signal-${insight.tone}`}><insight.icon size={14} /></span>
        <span className="signal-copy"><strong>{insight.title}</strong><small>{insight.description}</small></span><ArrowRight size={15} className="signal-arrow" />
      </button>)}
    </section>

    <section className="analytics-grid">
      <article className="panel trend-panel">
        <div className="panel-heading">
          <div><span className="panel-kicker">PORTFOLIO HEALTH</span><h2>Steady growth, healthier book</h2></div>
          <button className="icon-button panel-more" aria-label="Chart options" onClick={() => onNotify('Chart options are not available in the demo.')}><MoreHorizontal size={20} /></button>
        </div>
        <div className="trend-legend"><span><i className="legend-principal" />Outstanding principal</span><span><i className="legend-par" />PAR 30+</span><span className="trend-period">{period}</span></div>
        <PortfolioChart data={trend} />
        <div className="chart-insight"><span><Sparkles size={14} /></span><p>PAR 30+ improved by <strong>0.8 percentage points</strong> while principal grew over the last 7 months.</p></div>
      </article>

      <article className="panel mix-panel">
        <div className="panel-heading">
          <div><span className="panel-kicker">EXPOSURE MIX</span><h2>By product</h2></div>
          <button className="text-action" onClick={() => onNavigate('Portfolio')}>View portfolio <ArrowRight size={14} /></button>
        </div>
        <div className="mix-total"><strong>KES 84.6M</strong><span>Total outstanding principal</span></div>
        <div className="mix-bar" aria-label="Portfolio by product">{segments.map((segment) => <span key={segment.name} style={{ width: `${segment.value}%`, backgroundColor: segment.color }} title={`${segment.name}: ${segment.value}%`} />)}</div>
        <div className="segment-list">{segments.map((segment) => <div className="segment-row" key={segment.name}>
          <span className="segment-name"><i style={{ background: segment.color }} />{segment.name}</span>
          <span className="segment-amount">{segment.amount}</span><span className={`segment-par ${parseFloat(segment.par) > 8 ? 'par-alert' : ''}`}>{segment.par}</span>
        </div>)}</div>
        <div className="mix-footer"><span><i /> Exposure</span><span><i /> PAR 30+ by product</span></div>
      </article>
    </section>

    <section className="bottom-grid">
      <article className="panel worklist-panel">
        <div className="panel-heading worklist-heading">
          <div><span className="panel-kicker">{isCollections ? 'COLLECTIONS PRIORITY' : 'YOUR WORK QUEUE'}</span><h2>{isCollections ? 'Accounts to follow up' : 'Applications to review'} <span className="worklist-count">{isCollections ? collections.length : applications.length}</span></h2></div>
          <button className="text-action" onClick={() => onNavigate(isCollections ? 'Collections' : 'Applications')}>View all <ArrowRight size={14} /></button>
        </div>
        {isCollections ? <div className="worklist-table">
          <div className="table-header"><span>ACCOUNT</span><span>PRODUCT</span><span>OUTSTANDING</span><span>PRIORITY</span><span>NEXT ACTION</span><span /></div>
          {collections.slice(0, 3).map((item) => <div className="table-row" key={item.id}>
            <span className="applicant-cell"><span className={`person-avatar avatar-${item.tint}`}>{item.initials}</span><span><strong>{item.customer}</strong><small>{item.id}</small></span></span>
            <span className="table-product">{item.product}</span><strong className="table-amount">{item.amount}</strong><span className="status-pill status-waiting"><i />{item.status}</span><span className="table-age">{item.age}</span>
            <button className="row-action" aria-label={`Log collection action for ${item.id}`} disabled={!canLogCollections} title={canLogCollections ? 'Log a collection action' : 'Switch to the Collections demo role to log actions'} onClick={() => onLogCollection(item)}><ArrowRight size={15} /></button>
          </div>)}
        </div> : <div className="worklist-table">
          <div className="table-header"><span>APPLICANT</span><span>PRODUCT</span><span>REQUESTED</span><span>STATUS</span><span>UPDATED</span><span /></div>
          {applications.slice(0, 3).map((item) => <div className="table-row" key={item.id}>
            <span className="applicant-cell"><span className={`person-avatar avatar-${item.tint}`}>{item.initials}</span><span><strong>{item.customer}</strong><small>{item.id}</small></span></span>
            <span className="table-product">{item.product}</span><strong className="table-amount">{item.amount}</strong>
            <span><span className={`status-pill ${item.status === 'Ready for review' || item.status === 'Recommendation: approve' ? 'status-ready' : item.status === 'Recommendation: decline' ? 'status-critical' : 'status-waiting'}`}><i />{item.status}</span></span>
            <span className="table-age">{item.age}</span><button className="row-action" aria-label={`Review ${item.id}`} disabled={!canReview} title={canReview ? 'Review application' : 'Switch to the Risk officer demo role to review'} onClick={() => onReview(item)}><ArrowRight size={15} /></button>
          </div>)}
        </div>}
      </article>
      <article className="panel collection-card">
        <div className="panel-heading"><div><span className="panel-kicker">COLLECTIONS PULSE</span><h2>Small wins add up.</h2></div><span className="pulse-icon"><HandCoins size={18} /></span></div>
        <p className="collection-description">Recorded positive outcomes — paid or promise to pay — from logged collection actions.</p>
        <div className="collection-score"><strong>72<span>%</span></strong><span className="score-change"><ArrowUpRight size={14} /> 4.6 pp <small>vs last month</small></span></div>
        <div className="score-track"><span /></div>
        <div className="collection-foot"><span>Positive outcome rate</span><button onClick={() => onNavigate('Collections')}>Collections details <ArrowRight size={13} /></button></div>
      </article>
    </section>
    <AuditTrail entries={audit} />
  </>
}
