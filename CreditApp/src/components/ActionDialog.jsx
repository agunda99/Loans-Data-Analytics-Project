import { useEffect, useState } from 'react'
import { AlertTriangle, X } from 'lucide-react'
import { applicationReviewOptions } from '../data/dashboard.js'

function todayString() {
  const date = new Date()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

export default function ActionDialog({ action, record, onClose, onSubmit }) {
  const [outcome, setOutcome] = useState('')
  const [method, setMethod] = useState('')
  const [contactOutcome, setContactOutcome] = useState('')
  const [paymentAmount, setPaymentAmount] = useState('')
  const [reason, setReason] = useState('')
  const [followUpDate, setFollowUpDate] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    setOutcome('')
    setMethod('')
    setContactOutcome('')
    setPaymentAmount('')
    setReason('')
    setFollowUpDate('')
    setError('')
  }, [action, record])

  useEffect(() => {
    const handleKeyDown = (event) => {
      if (event.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [onClose])

  if (!action || !record) return null

  const isReview = action === 'review'
  const submit = (event) => {
    event.preventDefault()
    if (isReview && !outcome) {
      setError(isReview ? 'Choose a review outcome before continuing.' : 'Choose the contact outcome before continuing.')
      return
    }
    if (!isReview && (!method || !contactOutcome)) {
      setError('Choose a contact method and its outcome before continuing.')
      return
    }
    if (reason.trim().length < 8) {
      setError(isReview ? 'Add a rationale of at least 8 characters.' : 'Add a brief interaction note of at least 8 characters.')
      return
    }
    if (!isReview && contactOutcome === 'Promise to pay' && !followUpDate) {
      setError('Set a follow-up date for a promise to pay.')
      return
    }
    if (!isReview && contactOutcome === 'Paid' && (!Number.isFinite(Number(paymentAmount)) || Number(paymentAmount) <= 0)) {
      setError('Enter a payment amount greater than zero.')
      return
    }
    if (!isReview && contactOutcome === 'Paid' && Number(paymentAmount) > Number(record.amount.replace(/[^\d.]/g, ''))) {
      setError('The payment amount cannot exceed the displayed outstanding balance.')
      return
    }
    if (followUpDate && followUpDate < todayString()) {
      setError('The follow-up date cannot be in the past.')
      return
    }
    onSubmit({ outcome: isReview ? outcome : contactOutcome, method, reason: reason.trim(), followUpDate, paymentAmount: paymentAmount ? Number(paymentAmount) : null })
  }

  return <div className="action-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}>
    <section className="action-dialog" role="dialog" aria-modal="true" aria-labelledby="action-title">
      <div className="action-dialog-heading">
        <div><span className="panel-kicker">{isReview ? 'HUMAN REVIEW · DEMO' : 'COLLECTION ACTIVITY · DEMO'}</span><h2 id="action-title">{isReview ? 'Review application' : 'Log a collection action'}</h2></div>
        <button className="icon-button" aria-label="Close dialog" onClick={onClose}><X size={19} /></button>
      </div>
      <div className="action-record">
        <span className={`person-avatar avatar-${record.tint}`}>{record.initials}</span>
        <span><strong>{record.customer} · {record.id}</strong><small>{record.product} · {record.amount}</small></span>
      </div>
      <div className="action-notice"><AlertTriangle size={15} /><p>Demo only: this action changes local sample data. It does not send communications, approve a real loan, or persist to a server.</p></div>
      <form className="action-form" onSubmit={submit}>
        <label>{isReview ? 'Review outcome' : 'Contact method'}
          <select value={isReview ? outcome : method} onChange={(event) => { isReview ? setOutcome(event.target.value) : setMethod(event.target.value); setError('') }}>
            <option value="">{isReview ? 'Choose a review outcome' : 'Choose a contact method'}</option>
            {isReview
              ? applicationReviewOptions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)
              : ['Call', 'SMS', 'Email', 'Visit'].map((method) => <option value={method} key={method}>{method}</option>)}
          </select>
        </label>
        {!isReview && <label>Contact outcome
          <select value={contactOutcome} onChange={(event) => { setContactOutcome(event.target.value); setError('') }}>
            <option value="">Choose an outcome</option>
            {['Promise to pay', 'Paid', 'No answer', 'Escalated'].map((result) => <option value={result} key={result}>{result}</option>)}
          </select>
        </label>}
        {!isReview && contactOutcome && <label>Interaction notes
          <textarea rows="3" value={reason} onChange={(event) => { setReason(event.target.value); setError('') }} placeholder="Briefly record what happened (minimum 8 characters)." required />
        </label>}
        {!isReview && contactOutcome === 'Paid' && <label>Payment amount (KES)
          <input type="number" min="0.01" step="0.01" value={paymentAmount} onChange={(event) => { setPaymentAmount(event.target.value); setError('') }} placeholder="Enter amount received" required />
        </label>}
        {isReview && <label>Decision rationale
          <textarea rows="3" value={reason} onChange={(event) => { setReason(event.target.value); setError('') }} placeholder="Record the human reviewer’s rationale (minimum 8 characters)." required />
        </label>}
        {!isReview && contactOutcome === 'Promise to pay' && <label>Promised follow-up date
          <input type="date" min={todayString()} value={followUpDate} onChange={(event) => { setFollowUpDate(event.target.value); setError('') }} required />
        </label>}
        {error && <p className="action-error" role="alert">{error}</p>}
        <div className="action-dialog-footer"><button type="button" className="cancel-button" onClick={onClose}>Cancel</button><button type="submit" className="confirm-button">{isReview ? 'Record review' : 'Log action'}</button></div>
      </form>
    </section>
  </div>
}
