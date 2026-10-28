import { ShieldCheck } from 'lucide-react'
import { useMemo, useState } from 'react'
import AuditTrail from '../components/AuditTrail.jsx'
import CollectionEntry from '../components/CollectionEntry.jsx'
import QueueToolbar from '../components/QueueToolbar.jsx'

function isPriority(item, filter) {
  if (filter === 'all') return true
  if (filter === 'critical') return item.status.includes('91+')
  if (filter === 'elevated') return item.status.includes('31–60')
  return filter === 'monitor' && item.status.includes('1–30')
}

export default function CollectionsPage({ accounts, audit, canLog, onLog }) {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('all')
  const filtered = useMemo(() => accounts.filter((item) =>
    `${item.id} ${item.customer} ${item.product} ${item.status} ${item.lastAction?.outcome ?? ''}`.toLowerCase().includes(search.toLowerCase())
    && isPriority(item, filter),
  ), [accounts, filter, search])

  return <section className="detail-page">
    <div className="detail-summary">
      <div className="detail-title"><div className="detail-icon"><ShieldCheck size={20} /></div><div><span className="panel-kicker">COLLECTIONS WORKSPACE</span><h2>Prioritized follow-ups</h2></div></div>
      <p>Work the highest-priority overdue accounts first. Log contact attempts and outcomes; this sample has no contact details or direct-dial actions.</p>
    </div>
    {!canLog && <div className="permission-note"><ShieldCheck size={16} /> Read-only in this demo role. Switch to Collections to try logging an interaction.</div>}
    <QueueToolbar page="Collections" search={search} onSearch={setSearch} filter={filter} onFilter={setFilter} count={filtered.length} total={accounts.length} />
    <section className="detail-queue panel" aria-label="Collections accounts">
      <div className="detail-queue-head"><span>ACCOUNT</span><span>PRODUCT</span><span>OUTSTANDING</span><span>PRIORITY</span><span>NEXT ACTION</span><span>ACTION</span></div>
      {filtered.map((item) => <CollectionEntry key={item.id} item={item} canLog={canLog} onLog={onLog} />)}
      {!filtered.length && <div className="empty-state">No accounts match this search and priority filter.</div>}
    </section>
    <div className="method-note"><ShieldCheck size={16} /><span><strong>Customer privacy</strong> Names are masked synthetic examples. Logged actions remain in memory for this session and do not send a message or contact a customer.</span></div>
    <AuditTrail entries={audit} />
  </section>
}
