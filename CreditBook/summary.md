Main choices behind the CreditBook metrics, in friendly terms.

### Payment allocation: an analytic FIFO assumption

The source data records payments against loans, but does not link each payment to a specific repayment installment. To estimate remaining balances and delinquency consistently, `fn_portfolio_par.sql` applies these rules:

1. Count only payments marked **completed** and received on or before the report date.
2. Pool those payments per loan and apply them to installments in due-date/sequence order—**first in, first out (FIFO)**.
3. Within each installment, apply allocated money to interest first, then principal.
4. A partially paid installment remains overdue until its full scheduled amount is covered. Principal falls only after that installment’s interest is covered.
5. Payments are capped at the total scheduled amount. Handling extra or advance payments is outside this model.

This provides a repeatable way to estimate balances and DPD, including for past month-end snapshots. It is a **portfolio-analysis assumption**, not a transaction-level accounting ledger.

### PAR: overdue loans’ remaining principal

**Portfolio at Risk (PAR)** measures outstanding principal on loans that are overdue by a specified number of days. In this project:

- **PAR30 balance** = remaining principal on eligible loans with DPD of at least 30; PAR60 and PAR90 use at least 60 and 90.
- **PAR30 %** = PAR30 balance ÷ total outstanding principal for the same eligible loan population × 100.
- The calculation uses **remaining principal**, not the full scheduled receivable, which can include future interest.
- For current reporting, the eligible population includes active, delinquent, and defaulted loans with positive principal outstanding. Historical snapshots reconstruct balances from payments received by each snapshot date.

The code considers an installment overdue only when its due date is **before** the report date. That means a payment due on the report date is not yet overdue. See `fn_portfolio_par.sql`, `rpt_par.sql`, and the definitions in `METRICS.md`.

### ECL: demonstration assumptions, not a forecast

The `rpt_ecl.sql` report estimates expected credit loss using:

**ECL = EAD × PD × LGD**

- **EAD** is represented by outstanding principal.
- **PD** is an assumed probability of default based on the loan’s DPD bucket: 1% for current–30 days, 5% for 31–60, 20% for 61–90, and 50% for over 90 days.
- **LGD** is assumed to be 45% for all buckets.

These values are editable examples, not probabilities learned from the synthetic dataset or approved financial assumptions. The calculation does not provide a complete IFRS 9 or regulatory ECL model: for example, it does not implement validated forward-looking scenarios, discounting, or institution-specific recovery and write-off methods.

### SUMMARY: **“The project demonstrates how credit risk metrics can be calculated from loan and payment data. FIFO allocation and ECL parameters are explicitly illustrative; the outputs should not be treated as booked balances or production risk estimates.”**