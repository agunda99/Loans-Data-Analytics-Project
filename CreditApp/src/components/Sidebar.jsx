import { CircleHelp, MoreHorizontal, ShieldCheck } from 'lucide-react'
import { navigationIcons, roles } from '../data/dashboard.js'

export default function Sidebar({ role, activePage, open, onNavigate, onNotify }) {
  const isCollections = role === 'Collections'
  return <>
    {open && <button className="mobile-backdrop" aria-label="Close navigation" onClick={() => onNavigate(activePage)} />}
    <aside className={`sidebar ${open ? 'sidebar-open' : ''}`}>
      <a className="brand" href="#" aria-label="CreditBook home" onClick={(event) => { event.preventDefault(); onNavigate('Overview') }}>
        <span className="brand-mark"><span /><span /><span /></span>
        <span className="brand-name">creditbook<span>.</span></span>
      </a>
      <div className="workspace-label">WORKSPACE</div>
      <nav className="main-nav" aria-label="Main navigation">
        {roles[role].nav.map((page) => {
          const Icon = navigationIcons[page]
          return <button className={`nav-link ${activePage === page ? 'nav-active' : ''}`} key={page} onClick={() => onNavigate(page)}>
            <Icon size={18} strokeWidth={1.8} /><span>{page}</span>
            {page === 'Applications' && <span className="nav-count">18</span>}
            {page === 'Collections' && <span className="nav-count">{isCollections ? '24' : ''}</span>}
          </button>
        })}
      </nav>
      <div className="sidebar-spacer" />
      <div className="sidebar-note">
        <span className="note-icon"><ShieldCheck size={17} /></span>
        <p><strong>Privacy first</strong><br />Customer details are masked in this workspace.</p>
        <button aria-label="About privacy" onClick={() => onNotify('This demo uses masked, synthetic customer details.')}><CircleHelp size={15} /></button>
      </div>
      <div className="user-profile">
        <div className="user-avatar">AA</div>
        <div className="user-info"><strong>Austine Agunda</strong><span>{role}</span></div>
        <button className="icon-button profile-menu" aria-label="Profile options" onClick={() => onNotify('Profile settings are available in the connected workspace.')}><MoreHorizontal size={20} /></button>
      </div>
    </aside>
  </>
}
