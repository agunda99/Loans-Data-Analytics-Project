import { ArrowRight, HandCoins } from 'lucide-react'

export default function CollectionEntry({ item, canLog, onLog }) {
  const statusClass = item.status.includes('91+') ? 'status-critical' : item.status.includes('31') ? 'status-waiting' : 'status-ready'
  return <div className="detail-queue-row">
    <span className="applicant-cell"><span className={`person-avatar avatar-${item.tint}`}>{item.initials}</span><span><strong>{item.customer}</strong><small>{item.id}</small></span></span>
    <span>{item.product}</span><strong>{item.amount}</strong>
    <span className={`status-pill ${statusClass}`}><i />{item.status}</span>
    <span className="collection-next">{item.lastAction ? `${item.lastAction.method} · ${item.lastAction.outcome}` : item.age}{item.lastAction?.paymentAmount && <small>Received KES {item.lastAction.paymentAmount.toLocaleString()}</small>}{item.lastAction?.followUpDate && <small>Follow up {item.lastAction.followUpDate}</small>}</span>
    <button className={`action-button ${canLog ? '' : 'action-disabled'}`} disabled={!canLog} title={canLog ? 'Log a collection action' : 'Switch to the Collections demo role to log actions'} onClick={() => onLog(item)}><HandCoins size={14} /><span>Log action</span><ArrowRight size={14} /></button>
  </div>
}
