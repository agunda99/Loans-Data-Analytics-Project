-- Executive snapshot: counts, funded volume, principal exposure, and approval rate.
WITH loan_metrics AS (
    SELECT
        COUNT(*) FILTER (WHERE status IN ('active', 'delinquent', 'defaulted')) AS open_loans,
        COUNT(*) FILTER (WHERE status = 'closed') AS closed_loans,
        COUNT(DISTINCT customer_id) AS borrowers,
        COALESCE(SUM(principal), 0) AS lifetime_disbursed,
        COALESCE(AVG(principal), 0) AS average_loan_size,
        COALESCE(AVG(annual_rate), 0) AS average_annual_rate
    FROM loans
),
application_metrics AS (
    SELECT
        COUNT(*) AS total_applications,
        COUNT(*) FILTER (WHERE decision = 'approved') AS approved_applications,
        COUNT(*) FILTER (WHERE decision = 'declined') AS declined_applications,
        COUNT(*) FILTER (WHERE decision = 'pending') AS pending_applications
    FROM loan_applications
),
current_state_metrics AS (
    SELECT
        COALESCE(SUM(outstanding_principal)
            FILTER (WHERE loan_status IN ('active', 'delinquent', 'defaulted')), 0)
            AS outstanding_principal,
        COUNT(*) FILTER (
            WHERE dpd >= 30
              AND loan_status IN ('active', 'delinquent', 'defaulted')
        ) AS loans_30_plus_dpd,
        COUNT(*) FILTER (
            WHERE loan_status IN ('active', 'delinquent', 'defaulted')
        ) AS open_loans
    FROM fn_loan_state(CURRENT_DATE)
)
SELECT
    CURRENT_DATE AS as_of_date,
    lm.open_loans,
    lm.closed_loans,
    lm.borrowers,
    ROUND(lm.lifetime_disbursed, 2) AS lifetime_disbursed,
    ROUND(sm.outstanding_principal, 2) AS outstanding_principal,
    ROUND(lm.average_loan_size, 2) AS average_loan_size,
    ROUND(lm.average_annual_rate, 2) AS average_annual_rate_pct,
    am.total_applications,
    am.approved_applications,
    am.declined_applications,
    am.pending_applications,
    ROUND(100.0 * am.approved_applications / NULLIF(am.total_applications, 0), 2)
        AS application_approval_pct,
    sm.loans_30_plus_dpd,
    ROUND(100.0 * sm.loans_30_plus_dpd / NULLIF(sm.open_loans, 0), 2)
        AS loans_30_plus_dpd_pct
FROM loan_metrics lm
CROSS JOIN application_metrics am
CROSS JOIN current_state_metrics sm;
