-- Current performance by disbursement-month vintage.
WITH current_state AS (
    SELECT *
    FROM fn_loan_state(CURRENT_DATE)
),
vintage AS (
    SELECT
        DATE_TRUNC('month', l.disbursement_date)::DATE AS vintage_month,
        s.loan_id,
        s.dpd,
        s.outstanding_principal
    FROM loans l
    JOIN current_state s ON s.loan_id = l.loan_id
)
SELECT
    vintage_month,
    COUNT(*) AS loan_count,
    ROUND(SUM(outstanding_principal), 2) AS outstanding_principal,
    COUNT(*) FILTER (WHERE dpd = 0) AS current_loans,
    COUNT(*) FILTER (WHERE dpd BETWEEN 1 AND 30) AS loans_1_30_dpd,
    COUNT(*) FILTER (WHERE dpd BETWEEN 31 AND 60) AS loans_31_60_dpd,
    COUNT(*) FILTER (WHERE dpd BETWEEN 61 AND 90) AS loans_61_90_dpd,
    COUNT(*) FILTER (WHERE dpd > 90) AS loans_90_plus_dpd,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dpd >= 30) / NULLIF(COUNT(*), 0), 2)
        AS loans_30_plus_dpd_pct,
    ROUND(100.0 * SUM(outstanding_principal) FILTER (WHERE dpd >= 30)
        / NULLIF(SUM(outstanding_principal), 0), 2) AS par30_pct
FROM vintage
GROUP BY vintage_month
ORDER BY vintage_month;

-- Comparable six-month performance using set-based allocations at each loan's anniversary.
WITH loan_asof AS (
    SELECT
        l.loan_id,
        DATE_TRUNC('month', l.disbursement_date)::DATE AS vintage_month,
        (l.disbursement_date + INTERVAL '6 months')::DATE AS as_of_date
    FROM loans l
    WHERE (l.disbursement_date + INTERVAL '6 months')::DATE <= CURRENT_DATE
),
paid AS (
    SELECT la.loan_id, SUM(p.amount) AS total_paid
    FROM loan_asof la
    JOIN payments p
      ON p.loan_id = la.loan_id
     AND p.status = 'completed'
     AND p.payment_date <= la.as_of_date
    GROUP BY la.loan_id
),
installments AS (
    SELECT
        la.loan_id,
        la.vintage_month,
        la.as_of_date,
        rs.due_date,
        rs.principal_due,
        rs.interest_due,
        rs.total_due,
        SUM(rs.total_due) OVER (
            PARTITION BY la.loan_id ORDER BY rs.installment_no
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_due,
        COALESCE(p.total_paid, 0) AS total_paid
    FROM loan_asof la
    JOIN repayment_schedule rs ON rs.loan_id = la.loan_id
    LEFT JOIN paid p ON p.loan_id = la.loan_id
),
allocations AS (
    SELECT
        i.*,
        LEAST(i.total_due, GREATEST(0, i.total_paid - (i.cumulative_due - i.total_due)))
            AS amount_allocated
    FROM installments i
),
six_month_state AS (
    SELECT
        loan_id,
        vintage_month,
        GREATEST(
            0,
            as_of_date - MIN(due_date) FILTER (
                WHERE due_date < as_of_date AND amount_allocated < total_due
            )
        ) AS dpd
    FROM allocations
    GROUP BY loan_id, vintage_month, as_of_date
)
SELECT
    vintage_month,
    COUNT(*) AS loans_at_six_months,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dpd = 0) / NULLIF(COUNT(*), 0), 2)
        AS pct_current_at_six_months,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dpd BETWEEN 1 AND 30) / NULLIF(COUNT(*), 0), 2)
        AS pct_1_30_at_six_months,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dpd BETWEEN 31 AND 90) / NULLIF(COUNT(*), 0), 2)
        AS pct_31_90_at_six_months,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dpd > 90) / NULLIF(COUNT(*), 0), 2)
        AS pct_90_plus_at_six_months
FROM six_month_state
GROUP BY vintage_month
ORDER BY vintage_month;

-- Current 6-9 month-old book, as requested in the guide.
WITH current_state AS (
    SELECT *
    FROM fn_loan_state(CURRENT_DATE)
)
SELECT
    DATE_TRUNC('month', l.disbursement_date)::DATE AS vintage_month,
    COUNT(*) AS loans_age_6_to_9_months,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd = 0) / NULLIF(COUNT(*), 0), 2)
        AS pct_current,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd BETWEEN 1 AND 30) / NULLIF(COUNT(*), 0), 2)
        AS pct_1_30,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd BETWEEN 31 AND 90) / NULLIF(COUNT(*), 0), 2)
        AS pct_31_90,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd > 90) / NULLIF(COUNT(*), 0), 2)
        AS pct_90_plus
FROM loans l
JOIN current_state s ON s.loan_id = l.loan_id
WHERE l.disbursement_date >= (CURRENT_DATE - INTERVAL '9 months')::DATE
  AND l.disbursement_date <= (CURRENT_DATE - INTERVAL '6 months')::DATE
GROUP BY vintage_month
ORDER BY vintage_month;
