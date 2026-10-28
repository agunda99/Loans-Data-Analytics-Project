import { Search, SlidersHorizontal, ChevronDown, X } from 'lucide-react'

export default function QueueToolbar({ page, search, onSearch, filter, onFilter, count, total }) {
  const filters = page === 'Collections'
    ? [['all', 'All priorities'], ['critical', 'Critical · 90+ DPD'], ['elevated', 'Elevated · 31–60 DPD'], ['monitor', 'Monitor · 1–30 DPD']]
    : [['all', 'All statuses'], ['Ready for review', 'Ready for review'], ['Documents needed', 'Documents needed'], ['In assessment', 'In assessment'], ['Recommendation: approve', 'Recommendation: approve'], ['Recommendation: decline', 'Recommendation: decline']]
  return <div className="queue-controls">
    <label className="search-box"><Search size={16} /><input value={search} onChange={(event) => onSearch(event.target.value)} placeholder={`Search ${page.toLowerCase()}…`} aria-label={`Search ${page}`} />{search && <button aria-label="Clear search" onClick={() => onSearch('')}><X size={14} /></button>}</label>
    <label className="filter-button"><SlidersHorizontal size={15} /><select aria-label={`Filter ${page}`} value={filter} onChange={(event) => onFilter(event.target.value)}>
      {filters.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
    </select><ChevronDown size={14} /></label>
    <span className="queue-total">{count} of {total} records</span>
  </div>
}
