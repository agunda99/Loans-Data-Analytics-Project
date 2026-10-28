import { ShieldCheck } from 'lucide-react'
import { useMemo, useState } from 'react'
import ApplicationEntry from '../components/ApplicationEntry.jsx'
import AuditTrail from '../components/AuditTrail.jsx'
import QueueToolbar from '../components/QueueToolbar.jsx'

export default function ApplicationsPage({ applications, audit, canReview, onReview }) {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('all')
  const filtered = useMemo(() => applications.filter((item) => {
    const matchesSearch = `${item.id} ${item.customer} ${item.product} ${item.status}`.toLowerCase().includes(search.toLowerCase())
    return matchesSearch && (filter === 'all' || item.status === filter)
  }), [applications, filter, search])

  return <section className="detail-page">
    <div className="detail-summary">
      <div className="detail-title"><div className="detail-icon"><ShieldCheck size={20} /></div><div><span className="panel-kicker">APPLICATIONS WORKSPACE</span><h2>Application review queue</h2></div></div>
      <p>Review applications with masked customer details. Every demo disposition requires a human-selected outcome and recorded rationale.</p>
    </div>
    {!canReview && <div className="permission-note"><ShieldCheck size={16} /> Read-only in this demo role. Switch to Risk officer to try the review workflow.</div>}
    <QueueToolbar page="Applications" search={search} onSearch={setSearch} filter={filter} onFilter={setFilter} count={filtered.length} total={applications.length} />
    <section className="detail-queue panel" aria-label="Applications">
      <div className="detail-queue-head"><span>APPLICANT</span><span>PRODUCT</span><span>REQUESTED</span><span>STATUS</span><span>LAST UPDATE / RATIONALE</span><span>ACTION</span></div>
      {filtered.map((item) => <ApplicationEntry key={item.id} item={item} canReview={canReview} onReview={onReview} />)}
      {!filtered.length && <div className="empty-state">No applications match this search and status filter.</div>}
    </section>
    <div className="method-note"><ShieldCheck size={16} /><span><strong>Decision integrity</strong> This prototype demonstrates human review only. It does not calculate credit scores, send decisions, or connect to a lending system. Demo outcomes are local and non-binding.</span></div>
    <AuditTrail entries={audit} />
  </section>
}
