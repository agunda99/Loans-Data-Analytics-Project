import { ArrowRight, FileCheck2 } from 'lucide-react'

export default function ApplicationEntry({ item, canReview, onReview }) {
  const reviewed = item.status.startsWith('Recommendation:')
  const statusClass = item.status === 'Ready for review' || item.status === 'Recommendation: approve' ? 'status-ready' : item.status === 'Recommendation: decline' ? 'status-critical' : 'status-waiting'
  return <div className="detail-queue-row">
    <span className="applicant-cell"><span className={`person-avatar avatar-${item.tint}`}>{item.initials}</span><span><strong>{item.customer}</strong><small>{item.id}</small></span></span>
    <span>{item.product}</span><strong>{item.amount}</strong>
    <span className={`status-pill ${statusClass}`}><i />{item.status}</span>
    <span className="collection-next">{item.reviewRationale ? `Rationale: ${item.reviewRationale}` : item.age}</span>
    <button className={`action-button ${canReview ? '' : 'action-disabled'}`} disabled={!canReview} title={canReview ? (reviewed ? 'Record another review' : 'Review application') : 'Switch to the Risk officer demo role to review'} onClick={() => onReview(item)}><FileCheck2 size={14} /><span>Review</span><ArrowRight size={14} /></button>
  </div>
}
