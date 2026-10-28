import { useMemo, useState } from 'react'
import { ArrowRight, Search, ShieldCheck, X } from 'lucide-react'
import ActionDialog from './components/ActionDialog.jsx'
import PageHeading from './components/PageHeading.jsx'
import Sidebar from './components/Sidebar.jsx'
import Toast from './components/Toast.jsx'
import Topbar from './components/Topbar.jsx'
import ApplicationsPage from './pages/ApplicationsPage.jsx'
import CollectionsPage from './pages/CollectionsPage.jsx'
import OverviewPage from './pages/OverviewPage.jsx'
import PortfolioPage from './pages/PortfolioPage.jsx'
import { downloadSummary, portfolioTrend, roles, seedApplications, seedCollections } from './data/dashboard.js'

function createAuditEntry({ action, record, role, outcome, method, reason, followUpDate }) {
  const time = new Date()
  const actionLabel = action === 'review' ? outcome : `${method} · ${outcome}`
  const followUp = followUpDate ? ` · Follow-up ${followUpDate}` : ''
  return {
    id: `${time.getTime()}-${record.id}`,
    tone: action === 'review' ? (outcome === 'Recommendation: decline' ? 'warning' : 'review') : 'collection',
    title: `${record.id}: ${actionLabel}`,
    detail: `${role} · ${record.customer} · ${reason}${followUp}`,
    time: time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
  }
}

export default function App() {
  const [roleName, setRoleName] = useState('Executive')
  const [activePage, setActivePage] = useState('Overview')
  const [period, setPeriod] = useState('Last 7 months')
  const [roleOpen, setRoleOpen] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [applications, setApplications] = useState(seedApplications)
  const [collections, setCollections] = useState(seedCollections)
  const [audit, setAudit] = useState([])
  const [dialog, setDialog] = useState(null)
  const [toastMessage, setToastMessage] = useState('')

  const role = roles[roleName]
  const permissions = role.permissions
  const canReview = permissions.includes('reviewApplications')
  const canLogCollections = permissions.includes('logCollections')
  const searchResults = role.nav.filter((page) => page.toLowerCase().includes(searchTerm.toLowerCase()))
  const trend = useMemo(() => {
    const count = period === 'Last 3 months' ? 3 : period === 'Last 12 months' ? portfolioTrend.length : 7
    return portfolioTrend.slice(-count)
  }, [period])

  const notify = (message) => {
    setToastMessage(message)
    window.setTimeout(() => setToastMessage(''), 2600)
  }

  const navigate = (page) => {
    setActivePage(page)
    setMenuOpen(false)
    setSearchTerm('')
  }

  const changeRole = (nextRole) => {
    setRoleName(nextRole)
    setRoleOpen(false)
    setSearchTerm('')
    if (!roles[nextRole].nav.includes(activePage)) navigate('Overview')
  }

  const submitAction = ({ outcome, method, reason, followUpDate, paymentAmount }) => {
    const { type, record } = dialog
    if (type === 'review') {
      setApplications((current) => current.map((item) => item.id === record.id
        ? { ...item, status: outcome, reviewRationale: reason, age: 'Just now' }
        : item))
    } else {
      setCollections((current) => current.map((item) => item.id === record.id
        ? { ...item, lastAction: { method, outcome, reason, followUpDate, paymentAmount, recordedAt: new Date().toISOString() }, age: `${method} · ${outcome}` }
        : item))
    }
    const auditEntry = createAuditEntry({ action: type, record, role: roleName, outcome, method, reason, followUpDate })
    setAudit((current) => [{ ...auditEntry, detail: paymentAmount ? `${auditEntry.detail} · KES ${paymentAmount.toLocaleString()}` : auditEntry.detail }, ...current])
    setDialog(null)
    notify(type === 'review' ? `${record.id} review recorded in this demo session.` : `${method} · ${outcome} logged for ${record.id}.`)
  }

  return <div className="app-shell">
    <Sidebar role={roleName} activePage={activePage} open={menuOpen} onNavigate={navigate} onNotify={notify} />
    <main className="main-area">
      <Topbar
        page={activePage}
        role={roleName}
        roleOpen={roleOpen}
        onRoleOpen={() => setRoleOpen((open) => !open)}
        onRoleChange={changeRole}
        onMenuOpen={() => setMenuOpen(true)}
        onSearch={() => { setSearchTerm(''); setSearchOpen(true) }}
        onNotify={notify}
      />
      <div className="page-content">
        <PageHeading page={activePage} role={role} period={period} onPeriodChange={setPeriod} onExport={downloadSummary} />
        {activePage === 'Overview' && <OverviewPage
          role={{ ...role, name: roleName }}
          period={period}
          trend={trend}
          applications={applications}
          collections={collections}
          audit={audit}
          onNavigate={navigate}
          onNotify={notify}
          canReview={canReview}
          canLogCollections={canLogCollections}
          onReview={(record) => setDialog({ type: 'review', record })}
          onLogCollection={(record) => setDialog({ type: 'collection', record })}
        />}
        {activePage === 'Portfolio' && <PortfolioPage />}
        {activePage === 'Applications' && <ApplicationsPage applications={applications} audit={audit} canReview={canReview} onReview={(record) => setDialog({ type: 'review', record })} />}
        {activePage === 'Collections' && <CollectionsPage accounts={collections} audit={audit} canLog={canLogCollections} onLog={(record) => setDialog({ type: 'collection', record })} />}
        <footer className="page-footer"><span><span className="footer-lock"><ShieldCheck size={13} /></span> Synthetic sample data · no live customer records</span><span>DEMO DATA <i /> Updated just now <button onClick={() => notify('Data refreshed from the local demo dataset.')}>Refresh</button></span></footer>
      </div>
    </main>
    {searchOpen && <div className="search-overlay" role="dialog" aria-modal="true" aria-label="Search workspace" onClick={() => setSearchOpen(false)}>
      <div className="search-dialog" onClick={(event) => event.stopPropagation()}>
        <Search size={18} />
        <input autoFocus value={searchTerm} placeholder="Search your workspace…" onChange={(event) => setSearchTerm(event.target.value)} onKeyDown={(event) => {
          if (event.key === 'Enter' && searchResults.length) { navigate(searchResults[0]); setSearchOpen(false) }
          if (event.key === 'Escape') setSearchOpen(false)
        }} />
        <kbd>ESC</kbd><button aria-label="Close search" onClick={() => setSearchOpen(false)}><X size={17} /></button>
        <div className="search-results">{searchResults.length ? searchResults.map((page) => <button key={page} onClick={() => { navigate(page); setSearchOpen(false) }}><Search size={14} /><span>{page}</span><ArrowRight size={14} /></button>) : <span className="search-empty">No matching workspace pages</span>}</div>
      </div>
    </div>}
    {dialog && <ActionDialog action={dialog.type} record={dialog.record} onClose={() => setDialog(null)} onSubmit={submitAction} />}
    <Toast message={toastMessage} />
  </div>
}
