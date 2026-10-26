# CreditBook metric definitions

All currency measures use the database's numeric units. The seed data is synthetic and does not specify a production currency; label units before presenting values. Current-state measures use `CURRENT_DATE`, and historical measures use the explicit month-end `as_of_date`.

| Metric | Definition in this project | SQL source / caveat |
|---|---|---|
| Loans disbursed | Count of loan records with disbursement in the period | `rpt_disbursements.sql`; principal is original funded amount |
| Total disbursed | Sum of original loan principal | `rpt_portfolio_summary.sql`; lifetime total, not current exposure |
| Outstanding principal / EAD | Sum of unpaid principal after FIFO payment allocation | `fn_loan_state()`; principal exposure excludes future interest |
| Outstanding receivable | Remaining scheduled principal + interest across the full schedule | `v_loan_balance`; not the denominator for PAR |
| DPD | Days from the oldest due date with a remaining unpaid installment to the report date; 0 if none | `fn_loan_state()`; due-today installments are not overdue |
| DPD bucket | Current, 1–30, 31–60, 61–90, 90+ | `v_loan_dpd`; 90+ means 91 or more elapsed days |
| PAR n balance | Outstanding principal on loans with a positive as-of balance and DPD at least n | `fn_portfolio_par()`; current snapshots exclude written-off/closed statuses, historical states are reconstructed from dated payments |
| PAR n % | PAR n balance / total outstanding principal for the same open-loan population × 100 | `rpt_par.sql`; guard against zero denominator |
| Approval rate | Approved applications / all applications × 100 | `rpt_portfolio_summary.sql`; includes pending applications in the denominator |
| Vintage | Disbursement month cohort | `rpt_vintage.sql`; current vintage is not age-adjusted |
| Six-month vintage | Each eligible loan's state on its six-month anniversary | `rpt_vintage.sql`; excludes loans not yet six months old |
| Roll rate | Prior month-end bucket → next month-end bucket counts and transition percentage | `rpt_roll_rate.sql`; snapshots are reconstructed from payment history and include a Paid off destination |
| ECL (illustrative) | EAD × assumed PD × assumed LGD, aggregated by product | `rpt_ecl.sql`; parameters are demonstration-only, not IFRS 9/regulatory estimates |
| Collection outcome rate | Recorded `paid` or `promise_to_pay` actions / all recorded actions | `rpt_collections_effectiveness.sql`; not causal recovery attribution |

## Payment allocation assumptions

1. Only `completed` payments posted on or before the as-of date count.
2. Completed payment amounts are pooled per loan and applied FIFO to installments in due/sequence order.
3. Each installment is paid interest-first, then principal. Payments beyond scheduled amounts are capped at the schedule; excess/advance-payment accounting is not modeled.
4. Partial allocations reduce principal only after the installment's interest has been covered. An installment remains overdue until its due amount is fully allocated.
5. The source data has no `schedule_id` on `payments`; the allocation is a clear analytic assumption, not a booked accounting ledger.

## ECL scenario assumptions

`rpt_ecl.sql` uses the following editable demonstration defaults:

| DPD bucket | Assumed PD | Assumed LGD |
|---|---:|---:|
| Current–30 | 1% | 45% |
| 31–60 | 5% | 45% |
| 61–90 | 20% | 45% |
| 90+ | 50% | 45% |

These assumptions are not empirically estimated from the seed data. Replace them with documented, approved, forward-looking PD/LGD methodology and appropriate discounting, scenarios, write-offs, recoveries, and governance before making financial or regulatory claims.

## Dashboard grains

- Portfolio KPIs: one row per reporting date.
- Product/region PAR: one row per reporting date and segment.
- Vintage: one row per disbursement-month vintage.
- Roll rate: one row per transition month; matrix form is one row per prior bucket.
- Originations: one row per calendar month.
- Payment activity: one row per payment date, channel, and status.
- Watchlist: one row per overdue loan.
- Collection activity: one row per action, or aggregate by date/action type/outcome.

Pre-aggregate each fact to its visual grain before joining it to another one-to-many fact. Otherwise, a loan with multiple payments and collection actions can be multiplied and overstate money and counts.
