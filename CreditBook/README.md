# CreditBook | Credit Portfolio Analytics

CreditBook is a PostgreSQL portfolio analytics project built around a synthetic lending book. It follows loans from application and approval through disbursement, scheduled repayments, cash receipts, delinquency monitoring, and collections. The SQL reporting layer is designed to feed Power BI now and a small React dashboard later.

The project is a learning and portfolio demonstration, not a production lending system. The seed data is generated and contains no real customer records. ECL assumptions are illustrative, and all account and credit decisions require institution-approved policy and validation.

## What this project demonstrates

- A normalized credit data model with applications, loans, schedules, payments, and collections.
- Re-runnable synthetic data generation and data-quality checks.
- FIFO payment allocation for installment-level DPD and principal balances.
- DPD aging, PAR30/60/90, vintage, roll-rate, disbursement, and collections reporting.
- Equal-payment and equal-principal amortization schedules.
- PostgreSQL views, a materialized view, functions, triggers, indexes, and least-privilege roles.
- Business definitions and a report-to-file map for presentation and dashboard design.

## Requirements and setup

- PostgreSQL 14 or newer (`FILTER`, `generate_series`, materialized views, and the role features used here are PostgreSQL features).
- `psql` installed and available to PowerShell.
- Permission to create tables, functions, roles, indexes, and views in the target database. The full build's role/grant steps normally require a database administrator.

Create the database once, for example:

```powershell
psql -U postgres -h localhost -d postgres -c "CREATE DATABASE creditbook_modular_db;"
```

Then run the complete build from this folder:

```powershell
.\build.ps1 -Database creditbook_modular_db -Username postgres -Server localhost
```

On Linux/macOS with `psql` on `PATH`, the equivalent is `./build.sh creditbook_modular_db`.

The build loads schema, indexes, roles, seed data, functions, triggers, reporting views, the materialized view, grants, and checks in dependency order. **The seed step truncates and regenerates all project data**; rerunning the build resets the synthetic dataset. Build with an authorized admin account because the role scripts create group roles and apply grants.

If you prefer manual execution, use `psql -X -v ON_ERROR_STOP=1 -d creditbook_modular_db -f "<path>"` in the same order listed in [`build.ps1`](./build.ps1). On an existing installation, refresh the dashboard cache with:

```powershell
psql -U postgres -d creditbook_modular_dbb -f "04_views_mv\refresh_all.sql"
```

For a non-blocking refresh (after the unique index is present), run [`refresh_mv_portfolio_par.sql`](./04_views_mv/refresh_mv_portfolio_par.sql) outside an explicit transaction.

## Project structure

| Folder | Purpose |
|---|---|
| [`00_schema/`](./00_schema) | Tables, indexes, and non-login role definitions |
| [`01_seed/`](./01_seed) | Repeatable synthetic product, customer, application, loan, schedule, payment, and collection data |
| [`02_staging/`](./02_staging) | Canonical loan balance/DPD, daily payment activity, and collection worklist views |
| [`03_functions/`](./03_functions) | Point-in-time loan state, PAR functions, payment validation, and triggers |
| [`04_views_mv/`](./04_views_mv) | Customer summary, portfolio PAR materialization, and refresh scripts |
| [`05_reporting/`](./05_reporting) | Business-question queries and dashboard-ready report datasets |
| [`06_checks/`](./06_checks) | Data integrity and KPI range checks; expected result is no exception rows |
| [`07_grants/`](./07_grants) | Role-specific least-privilege grants |

[`creditbook_db.sql`](../creditbook_db.sql) is the original study/query notebook and source of the business questions. It is intentionally separate from the ordered, buildable project scripts; use the files in this folder for a clean run.

### Corrections made when modularizing the study SQL

- Application decisions now use one random draw for the intended 70% approved / 20% declined / 10% pending split, and decision dates cannot predate the application.
- Seeded payments are never dated in the future; partial payments are represented, and all as-of measures ignore payments posted after the snapshot date.
- PAR uses unpaid principal exposure, not the full schedule total that includes future interest. The separate receivable measure is retained for clarity.
- Equal-principal schedule rounding is reconciled in the final installment so scheduled principal equals the original principal.
- Month-end snapshots are generated from month boundaries, avoiding the short-month drift from subtracting one month from dates such as the 31st.
- Historical vintage/roll/PAR logic uses dated payment records rather than today's payment totals; the roll matrix includes paid-off loans.
- Monthly disbursement summaries group by month and retain empty months so month-over-month calculations are aligned.
- The collections role uses a narrowly scoped overdue-worklist function instead of direct access to all customer and loan rows.

## Report map

| Business question / guide sprint | SQL file |
|---|---|
| Loan filters, Nairobi customer ranking, declined applications, customers without loans, product averages, approval rate, safe joins, DPD buckets, large disbursement months, top loans/borrowers, running disbursements | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql) |
| Portfolio KPIs and approval funnel | [`rpt_portfolio_summary.sql`](./05_reporting/rpt_portfolio_summary.sql) |
| PAR30/60/90 overall, by product and region, and by prior month-end | [`rpt_par.sql`](./05_reporting/rpt_par.sql) |
| Current and age-matched vintage performance | [`rpt_vintage.sql`](./05_reporting/rpt_vintage.sql) |
| Month-end roll transitions and Current → 1–30 trend | [`rpt_roll_rate.sql`](./05_reporting/rpt_roll_rate.sql) |
| Highest-risk overdue loans and collector work queue | [`rpt_watchlist.sql`](./05_reporting/rpt_watchlist.sql), [`v_collection_fact.sql`](./02_staging/v_collection_fact.sql) |
| Collection action volumes and recorded outcomes | [`rpt_collections_effectiveness.sql`](./05_reporting/rpt_collections_effectiveness.sql) |
| Scenario-based expected credit loss | [`rpt_ecl.sql`](./05_reporting/rpt_ecl.sql) |
| Monthly applications and originations | [`rpt_disbursements.sql`](./05_reporting/rpt_disbursements.sql) |
| Equal-payment and equal-principal schedules | [`rpt_amortization_equal_payment.sql`](./05_reporting/rpt_amortization_equal_payment.sql), [`rpt_amortization_equal_principal.sql`](./05_reporting/rpt_amortization_equal_principal.sql) |
| Shared DPD/PAR definitions and views | [`fn_portfolio_par.sql`](./03_functions/fn_portfolio_par.sql), [`v_loan_balance.sql`](./02_staging/v_loan_balance.sql), [`v_loan_dpd.sql`](./02_staging/v_loan_dpd.sql), [`mv_portfolio_par.sql`](./04_views_mv/mv_portfolio_par.sql) |
| Sanity and integrity checks | [`06_checks/`](./06_checks) |
| Permissions and role matrix implementation | [`003_create_roles.sql`](./00_schema/003_create_roles.sql), [`grants.sql`](./07_grants/grants.sql) |

### Guide sprint → project file map

| Sprint | Topic / answered exercise | Project file(s) |
|---:|---|---|
| 1 | Loan exploration, value/rate filters, latest disbursements, Nairobi credit-score ranking, declined applications | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql) |
| 2 | Book totals, approval percentage, never-borrowed customers, average ticket by product | [`rpt_portfolio_summary.sql`](./05_reporting/rpt_portfolio_summary.sql), [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql) |
| 3 | Borrower/product joins, customers without loans, safe aggregation of one-to-many payments | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql) |
| 4 | Loan age, days past maturity, 90-day disbursement filter, monthly disbursement counts | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql), [`rpt_disbursements.sql`](./05_reporting/rpt_disbursements.sql) |
| 5 | DPD buckets with 0/30/60/90/180/365-day boundaries and average original principal per bucket | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql), [`v_loan_dpd.sql`](./02_staging/v_loan_dpd.sql) |
| 6 | Product, region, month, category share/concentration, groups with >100 disbursements | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql), [`rpt_par.sql`](./05_reporting/rpt_par.sql), [`rpt_disbursements.sql`](./05_reporting/rpt_disbursements.sql) |
| 7 | Payment allocation, oldest overdue installment, DPD and remaining principal | [`fn_portfolio_par.sql`](./03_functions/fn_portfolio_par.sql), [`v_loan_balance.sql`](./02_staging/v_loan_balance.sql), [`v_loan_dpd.sql`](./02_staging/v_loan_dpd.sql) |
| 8 | PAR30/60/90 overall, by product/region, and over time | [`rpt_par.sql`](./05_reporting/rpt_par.sql), [`fn_portfolio_par.sql`](./03_functions/fn_portfolio_par.sql) |
| 9 | Category ranking, top borrowers, running disbursement totals and product-level views | [`rpt_loan_exploration.sql`](./05_reporting/rpt_loan_exploration.sql) |
| 10 | Current vintage distribution, age-matched 6-month vintage, and 6–9-month book | [`rpt_vintage.sql`](./05_reporting/rpt_vintage.sql) |
| 11 | Month-end roll matrix and six-transition Current → 1–30 trend | [`rpt_roll_rate.sql`](./05_reporting/rpt_roll_rate.sql) |
| 12 | Recursive equal-payment schedule, comparison against equal-principal | [`rpt_amortization_equal_payment.sql`](./05_reporting/rpt_amortization_equal_payment.sql), [`rpt_amortization_equal_principal.sql`](./05_reporting/rpt_amortization_equal_principal.sql) |
| 13 | Reusable views, materialized PAR, refresh workflow | [`04_views_mv/`](./04_views_mv), [`02_staging/`](./02_staging) |
| 14 | Indexes and `EXPLAIN (ANALYZE, BUFFERS)` performance experiment | [`002_create_indexes.sql`](./00_schema/002_create_indexes.sql); see performance note below |
| 15 | Positive-payment validation, payment-status trigger, reusable PAR function and month-end calls | [`03_functions/`](./03_functions), [`rpt_par.sql`](./05_reporting/rpt_par.sql) |
| 16 | Analyst/risk/collections/CFO least-privilege matrix and grants | [`003_create_roles.sql`](./00_schema/003_create_roles.sql), [`grants.sql`](./07_grants/grants.sql), role table above |

### Role matrix

| Capability | Analyst | Risk officer | Collections | CFO |
|---|---|---|---|---|
| Read loan/product/schedule/payment reporting data | Yes | Yes (inherits analyst) | Only overdue worklist | Yes (inherits analyst) |
| Read customer PII | No; customer ID and region only | Yes | Only contact fields on overdue worklist | Yes |
| Read application decisions | No | Yes | No | Yes |
| Update application decision / loan status | No | Yes, decision and status columns only | No | No |
| Record payment | No | No | Insert only | No |
| Read customer summary / collection facts | No | Yes | Worklist only | Yes |
| DDL / truncate | No | No | No | No |

## Completed guide exercises and important interpretations

The exploration and reporting files include the guide's homework solutions, including the declined-last-year count, customer/product joins, approval rate, grouped average loan size, updated DPD boundaries with average principal, large monthly cohorts, top borrowers, age-aligned six-month vintage matrix, historical roll-rate trend, 12 month-end PAR function calls, amortization comparison inputs, and the role grants.

- The **6-month vintage query** in `rpt_vintage.sql` compares each eligible cohort at the same age. The current 6–9 month book is a different slice; filter disbursements between `CURRENT_DATE - INTERVAL '9 months'` and `CURRENT_DATE - INTERVAL '6 months'` when you need that exact window.
- A closed loan is not currently delinquent simply because it was late in the past. Current DPD uses payments received as of the report date, so paid-off accounts return to current/zero DPD. To report historical delinquency after cure, retain dated loan snapshots; do not infer it from the current-state view.
- Month-end DPD and principal can be reconstructed from dated payments, but this sample has no historical status-change or write-off date. Historical PAR uses positive as-of principal exposure rather than today's status; the roll-rate matrix includes a `Paid off` destination to keep paid accounts from disappearing between snapshots.
- The account-level payment model intentionally has no `schedule_id` on payments. The shared state function therefore applies completed cash to due installments FIFO, interest first within each installment. This is a transparent portfolio-level allocation assumption, not a substitute for a lender's servicing ledger.
- Collection actions are not linked to payment IDs. The collections report measures action/outcome activity and does not claim that a particular action caused a recovery.
- Equal-payment installments have a fixed regular payment, except the final installment may differ by cents to clear rounding residuals. Equal-principal has constant principal and declining interest/payment.
- Run the **PAR check after refreshing** `mv_portfolio_par`; otherwise the materialized result may be stale.

## Suggested credit-committee presentation

1. **Portfolio summary:** funded loans, borrowers, disbursed principal, remaining principal, ticket size, and approval rate.
2. **Risk headline:** PAR30/60/90 balance and percentage, with the measurement date and balance definition stated.
3. **Concentration:** PAR and exposure by product and customer region.
4. **Trend:** monthly disbursement volume and month-end PAR.
5. **Vintage quality:** current performance and the age-matched six-month comparison.
6. **Early warning:** the Current → 1–30 roll rate across the latest six month-end transitions.
7. **Action:** high-priority watchlist with DPD, balance, and next collections action.
8. **Caveats:** synthetic data, allocation assumptions, modeled ECL, and any missing historical snapshots.

Do not present synthetic values as actual lender results. Generate the database on presentation day and record the as-of date shown in the reports.

## Power BI / React readiness

Use `loan_id` as the loan grain and avoid joining raw one-to-many payment, schedule, and collection rows together in one visual; aggregate each child table first or use the provided one-row-per-loan views. Useful Power BI pages are: Executive Overview, Portfolio Risk, Vintage & Roll Rate, Originations, and Collections. The `v_loan_dpd`, `v_loan_balance`, `v_payment_daily`, `v_collection_fact`, and `mv_portfolio_par` outputs are starting datasets.

For a future React page, expose only aggregated/report-safe outputs through an API. Do not connect a browser directly to PostgreSQL or expose the customer watchlist / phone data to public clients. [`METRICS.md`](./METRICS.md) specifies the measures and caveats.

## Performance exercise

The index file includes a covering `(loan_id, installment_no)` schedule index and a payment `(loan_id, payment_date)` index. For the guide's PAR query-plan exercise, run:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.category,
    SUM(s.outstanding_principal) AS outstanding_principal,
    SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30) AS par30_balance
FROM public.fn_loan_state(CURRENT_DATE) s
JOIN public.loan_products p ON p.product_id = s.product_id
WHERE s.loan_status IN ('active', 'delinquent', 'defaulted')
GROUP BY p.category;
```

Look at the nodes with the most `actual time × loops`, the top node's total execution time, and `shared read` vs `shared hit` buffers. Then test a selective payment-date query before and after a temporary index:

```sql
CREATE INDEX idx_test_payment_date ON payments (payment_date);
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM payments
WHERE payment_date BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE;
DROP INDEX idx_test_payment_date;
```

A selective payment-date filter may use an index on a large table; adding a `loan_id` index to a whole-table aggregate may not change the plan. The best index depends on table size and data distribution; do not claim a speedup without recording the actual plans and timings. A sequential scan can be the correct choice on small synthetic tables.

The expected learning answer is not a fixed percentage: an index on a selective payment-date or customer lookup may help, while a whole-book aggregation can still correctly use a sequential scan. Compare `actual time`, `loops`, and buffer reads from your own two plans. The current seed set is intentionally small, so it is not representative of production latency.
