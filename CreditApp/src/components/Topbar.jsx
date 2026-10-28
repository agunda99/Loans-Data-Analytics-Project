import { Bell, Check, ChevronDown, Menu, Search } from 'lucide-react'
import { roles } from '../data/dashboard.js'

export default function Topbar({ page, role, roleOpen, onRoleOpen, onRoleChange, onMenuOpen, onSearch, onNotify }) {
  const CurrentRoleIcon = roles[role].icon
  return <header className="topbar">
    <button className="mobile-menu icon-button" aria-label="Open navigation" onClick={onMenuOpen}><Menu size={21} /></button>
    <div className="breadcrumb">Workspace <span>/</span> <strong>{page}</strong></div>
    <div className="topbar-actions">
      <span className="secure-status"><span /> Demo workspace</span>
      <button className="icon-button workspace-search" aria-label="Search workspace" onClick={onSearch}><Search size={17} /></button>
      <div className="role-wrap">
        <button className="role-switch" aria-expanded={roleOpen} onClick={onRoleOpen}>
          <CurrentRoleIcon size={16} /><span>{role}</span><ChevronDown size={14} />
        </button>
        {roleOpen && <div className="role-menu">
          {Object.entries(roles).map(([name, config]) => <button key={name} onClick={() => onRoleChange(name)}>
            <config.icon size={16} /><span>{name}<small>{config.description}</small></span>{name === role && <Check size={15} />}
          </button>)}
        </div>}
      </div>
      <button className="icon-button notification-button" aria-label="Notifications" onClick={() => onNotify('You’re all caught up.')}><Bell size={18} /><i /></button>
      <div className="top-avatar">AA</div>
    </div>
  </header>
}
