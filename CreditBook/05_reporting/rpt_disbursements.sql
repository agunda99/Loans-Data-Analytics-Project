-- Monthly loan originations and funding volume.
WITH calendar AS (
    SELECT generate_series(
        DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '23 months',
        DATE_TRUNC('month', CURRENT_DATE),
        INTERVAL '1 month'
    )::DATE AS month
),
monthly_disbursements AS (
    SELECT
        DATE_TRUNC('month', disbursement_date)::DATE AS month,
        COUNT(*) AS loans_disbursed,
        SUM(principal) AS amount_disbursed,
        AVG(principal) AS average_ticket,
        AVG(annual_rate) AS average_annual_rate
    FROM loans
    WHERE disbursement_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '23 months'
      AND disbursement_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
    GROUP BY DATE_TRUNC('month', disbursement_date)::DATE
),
monthly_applications AS (
    SELECT
        DATE_TRUNC('month', application_date)::DATE AS month,
        COUNT(*) AS applications,
        COUNT(*) FILTER (WHERE decision = 'approved') AS approved_applications
    FROM loan_applications
    WHERE application_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '23 months'
      AND application_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
    GROUP BY DATE_TRUNC('month', application_date)::DATE
)
SELECT
    cal.month,
    COALESCE(d.loans_disbursed, 0) AS loans_disbursed,
    ROUND(COALESCE(d.amount_disbursed, 0), 2) AS amount_disbursed,
    ROUND(d.average_ticket, 2) AS average_ticket,
    ROUND(d.average_annual_rate, 2) AS average_annual_rate_pct,
    COALESCE(a.applications, 0) AS applications,
    COALESCE(a.approved_applications, 0) AS approved_applications,
    ROUND(100.0 * a.approved_applications / NULLIF(a.applications, 0), 2)
        AS application_approval_pct,
    ROUND(
        100.0 * (COALESCE(d.amount_disbursed, 0)
            - LAG(COALESCE(d.amount_disbursed, 0)) OVER (ORDER BY cal.month))
        / NULLIF(LAG(COALESCE(d.amount_disbursed, 0)) OVER (ORDER BY cal.month), 0),
        2
    ) AS disbursement_amount_mom_pct
FROM calendar cal
LEFT JOIN monthly_disbursements d ON d.month = cal.month
LEFT JOIN monthly_applications a ON a.month = cal.month
ORDER BY cal.month;
