# CreditBook dashboard

Responsive React dashboard prototype for CreditBook. Start the development server from this directory:

```sh
npm install
npm run dev
```

`npm run build` produces the static production bundle in `dist/`.

## CreditBook metric alignment

The dashboard reflects the definitions in `../CreditBook/METRICS.md`: outstanding principal is open-loan exposure at default (EAD); PAR 30+ is overdue open-loan principal divided by total open-loan principal; approval rate includes pending applications in its denominator; and collection outcome rate represents recorded paid or promise-to-pay actions, not causal recovery. The ECL display is explicitly illustrative and must not be used for reporting or credit decisions.

The UI uses synthetic demonstration values, and KES is a demonstration currency assumption; it is not connected to PostgreSQL or the SQL reporting views. Replace the demo data with a backend API that runs the CreditBook queries and returns pre-aggregated data at the documented reporting grains.

## Roles and security

The role picker demonstrates how executive, risk, collections, and analyst views can differ. It is a client-side preview only and is **not authentication or authorization**. In a real deployment, enforce identity, least-privilege access, row-level permissions, and action authorization on the server; audit sensitive reads and every decision; keep personal data out of logs and exports unless specifically authorized; use TLS and managed secrets; and apply retention, session timeout, CSRF protection, and rate limits. Do not treat the masked synthetic queue as a substitute for data minimization controls.

## Source structure and demo actions

- `src/App.jsx` owns session-level demo state, page selection, role preview, and action dispatch.
- `src/pages/` contains the overview, portfolio, application-review, and collections pages.
- `src/components/` contains the shared navigation, chart, queues, action dialog, and activity log.
- `src/data/dashboard.js` holds the synthetic dashboard data and demo role capabilities.

Risk-officer preview users can record a human-selected application disposition with a rationale. Collections preview users can log a synthetic contact method/outcome, notes, a promise date, and a payment amount. These actions update React state for the current browser session and are listed in an in-memory activity log; they do not call a backend, send messages, post a payment, or persist after a reload. Role-based disabled controls are UX only.

A production workflow must authorize each operation on the server, validate and persist it transactionally, enforce the current application/loan state, and create a tamper-resistant audit record with the authenticated actor, policy/version where relevant, timestamp, rationale, and before/after state. A decision flow should show permitted evidence, clear rationale, and human review/override. Collections actions must integrate with an approved contact/payment system rather than treating a UI log as proof of contact or payment. Keep ECL assumptions versioned, governed, and visibly distinct from regulatory estimates.
