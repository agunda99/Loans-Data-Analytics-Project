import {
  Activity,
  BriefcaseBusiness,
  FileCheck2,
  HandCoins,
  LayoutDashboard,
  ShieldCheck,
  WalletCards,
  Check,
  Clock3,
  UsersRound,
} from 'lucide-react'

export const roles = {
  Executive: {
    icon: BriefcaseBusiness,
    description: 'Portfolio overview',
    nav: ['Overview', 'Portfolio', 'Applications', 'Collections'],
    cards: ['Outstanding principal', 'PAR 30+', 'Applications', 'Approval rate'],
    permissions: [],
  },
  'Risk officer': {
    icon: ShieldCheck,
    description: 'Risk & credit quality',
    nav: ['Overview', 'Portfolio', 'Applications', 'Collections'],
    cards: ['Outstanding principal', 'PAR 30+', 'Illustrative ECL', 'Loans 30+ DPD'],
    permissions: ['reviewApplications'],
  },
  Collections: {
    icon: HandCoins,
    description: 'Collections workspace',
    nav: ['Overview', 'Portfolio', 'Collections'],
    cards: ['Outstanding principal', 'PAR 30+', 'Overdue accounts', 'Promises to pay'],
    permissions: ['logCollections'],
  },
  Analyst: {
    icon: Activity,
    description: 'Portfolio analytics',
    nav: ['Overview', 'Portfolio', 'Applications', 'Collections'],
    cards: ['Outstanding principal', 'PAR 30+', 'Applications', 'Approval rate'],
    permissions: [],
  },
}

export const navigationIcons = {
  Overview: LayoutDashboard,
  Portfolio: WalletCards,
  Applications: FileCheck2,
  Collections: HandCoins,
}

export const metrics = {
  'Outstanding principal': { value: 'KES 84.6M', change: '+8.2%', direction: 'up', positive: true, sub: 'vs. previous period', icon: WalletCards },
  'PAR 30+': { value: '6.42%', change: '−0.8 pp', direction: 'down', positive: true, sub: 'vs. previous period', icon: Activity },
  Applications: { value: '1,284', change: '+12.6%', direction: 'up', positive: true, sub: 'this reporting period', icon: FileCheck2 },
  'Approval rate': { value: '68.4%', change: '+2.1 pp', direction: 'up', positive: true, sub: 'of all applications', icon: Check },
  'Illustrative ECL': { value: 'KES 2.18M', change: '2.58% of EAD', direction: 'flat', positive: null, sub: 'demonstration assumptions', icon: ShieldCheck },
  'Loans 30+ DPD': { value: '143', change: '−9.4%', direction: 'down', positive: true, sub: 'of open portfolio', icon: Clock3 },
  'Overdue accounts': { value: '218', change: '−6.1%', direction: 'down', positive: true, sub: 'accounts to prioritize', icon: UsersRound },
  'Promises to pay': { value: '74', change: '+11.2%', direction: 'up', positive: true, sub: 'recorded this month', icon: HandCoins },
}

export const portfolioTrend = [
  { month: "Nov '25", principal: 47, par: 9.4 },
  { month: "Dec '25", principal: 49, par: 9.0 },
  { month: "Jan '26", principal: 53, par: 8.8 },
  { month: "Feb '26", principal: 56, par: 8.6 },
  { month: "Mar '26", principal: 58, par: 8.4 },
  { month: "Apr '26", principal: 59, par: 8.2 },
  { month: "May '26", principal: 61, par: 8.1 },
  { month: "Jun '26", principal: 65, par: 7.8 },
  { month: "Jul '26", principal: 67, par: 7.4 },
  { month: "Aug '26", principal: 70, par: 7.5 },
  { month: "Sep '26", principal: 76, par: 7.1 },
  { month: "Oct '26", principal: 84.6, par: 6.42 },
]

export const segments = [
  { name: 'Personal', amount: 'KES 34.2M', value: 40, par: '5.1%', color: '#4f8975' },
  { name: 'SME working capital', amount: 'KES 27.8M', value: 33, par: '8.7%', color: '#dfad58' },
  { name: 'Auto', amount: 'KES 14.3M', value: 17, par: '3.4%', color: '#7596d2' },
  { name: 'Micro', amount: 'KES 8.3M', value: 10, par: '9.2%', color: '#d58772' },
]

export const seedApplications = [
  { id: 'AP-2084', customer: 'A. Mwangi', product: 'SME working capital', amount: 'KES 420,000', status: 'Ready for review', age: '12 min ago', initials: 'AM', tint: 'mint' },
  { id: 'AP-2083', customer: 'J. Ochieng', product: 'Personal standard', amount: 'KES 85,000', status: 'Documents needed', age: '38 min ago', initials: 'JO', tint: 'blue' },
  { id: 'AP-2081', customer: 'M. Wanjiku', product: 'Auto loan', amount: 'KES 1,200,000', status: 'Ready for review', age: '1 hr ago', initials: 'MW', tint: 'rose' },
  { id: 'AP-2079', customer: 'P. Otieno', product: 'Micro loan', amount: 'KES 18,000', status: 'In assessment', age: '2 hrs ago', initials: 'PO', tint: 'amber' },
]

export const seedCollections = [
  { id: 'LN-10482', customer: 'S. Kamau', product: 'Personal premium', amount: 'KES 246,800', status: '91+ days overdue', age: 'Promise due today', initials: 'SK', tint: 'rose' },
  { id: 'LN-10217', customer: 'F. Achieng', product: 'SME working capital', amount: 'KES 184,200', status: '31–60 days overdue', age: 'Follow-up due', initials: 'FA', tint: 'amber' },
  { id: 'LN-10863', customer: 'D. Kiptoo', product: 'Auto loan', amount: 'KES 92,600', status: '1–30 days overdue', age: 'Last contact 3d ago', initials: 'DK', tint: 'blue' },
  { id: 'LN-10091', customer: 'R. Hassan', product: 'Personal standard', amount: 'KES 63,400', status: '31–60 days overdue', age: 'Promise due tomorrow', initials: 'RH', tint: 'mint' },
]

export const insights = [
  { icon: Activity, title: 'SME PAR 30+ is above average', description: '8.7% this month, 1.4 pp above the portfolio average.', tone: 'warning', page: 'Portfolio' },
  { icon: HandCoins, title: 'Repayment momentum is improving', description: 'Recorded payment outcomes rose 11% month over month.', tone: 'success', page: 'Collections' },
  { icon: ShieldCheck, title: '143 loans need a closer look', description: 'Open accounts at 30+ days past due across all products.', tone: 'neutral', page: 'Portfolio' },
]

export const applicationReviewOptions = [
  { value: 'Recommendation: approve', label: 'Recommend approval' },
  { value: 'Recommendation: decline', label: 'Recommend decline' },
  { value: 'Documents needed', label: 'Request documents' },
]

export function formatCurrency(value) {
  return `KES ${value.toFixed(1)}M`
}

export function downloadSummary() {
  const rows = [
    ['Metric', 'Value', 'Definition'],
    ['Outstanding principal', 'KES 84.6M', 'Open-loan principal exposure (EAD)'],
    ['PAR 30+', '6.42%', 'Outstanding principal on open loans at 30+ DPD / total open principal'],
    ['Applications', '1284', 'Applications in the selected demonstration period'],
    ['Approval rate', '68.4%', 'Approved applications / all applications including pending'],
  ]
  const csv = rows.map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(',')).join('\r\n')
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
  const link = document.createElement('a')
  link.href = url
  link.download = 'creditbook-portfolio-summary.csv'
  link.click()
  URL.revokeObjectURL(url)
}
