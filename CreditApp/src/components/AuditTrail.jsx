import { Clock3 } from 'lucide-react'

export default function AuditTrail({ entries }) {
  return <section className="audit-panel panel" aria-label="Recent activity">
    <div className="panel-heading"><div><span className="panel-kicker">DEMO ACTIVITY LOG</span><h2>Recent actions</h2></div><Clock3 size={17} className="audit-icon" /></div>
    {entries.length ? <ol className="audit-list">
      {entries.slice(0, 5).map((entry) => <li key={entry.id}>
        <span className={`audit-marker audit-${entry.tone}`} />
        <span className="audit-copy"><strong>{entry.title}</strong><small>{entry.detail}</small></span>
        <time>{entry.time}</time>
      </li>)}
    </ol> : <p className="audit-empty">Completed review and collection actions will appear here for this session.</p>}
    <p className="audit-disclaimer">In-memory demo log only. Production actions require server-side authorization and a durable audit record.</p>
  </section>
}
