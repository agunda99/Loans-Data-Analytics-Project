-- Sprint 1: selected loan details and common filters.
SELECT loan_id, customer_id, principal, annual_rate, tenor_months,
       disbursement_date, status
FROM loans
WHERE principal > 500000
  AND annual_rate < 15
ORDER BY disbursement_date DESC;

SELECT loan_id, customer_id, principal, annual_rate, tenor_months,
       disbursement_date, status
FROM loans
WHERE disbursement_date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY disbursement_date DESC;

SELECT customer_id, full_name, region, employment_type, monthly_income, credit_score
FROM customers
WHERE region = 'Nairobi'
ORDER BY credit_score DESC NULLS LAST
LIMIT 5;

SELECT COUNT(*) AS declined_applications_last_12_months
FROM loan_applications
WHERE decision = 'declined'
  AND decision_date >= CURRENT_DATE - INTERVAL '1 year'
  AND decision_date <= CURRENT_DATE;

-- Loan age and maturity status for active accounts.
SELECT
    loan_id,
    disbursement_date,
    maturity_date,
    CURRENT_DATE - disbursement_date AS days_since_disbursement,
    ROUND((CURRENT_DATE - disbursement_date) / 30.44, 1) AS age_months_approx,
    GREATEST(0, CURRENT_DATE - maturity_date) AS days_past_maturity
FROM loans
WHERE status IN ('active', 'delinquent', 'defaulted')
ORDER BY days_since_disbursement DESC;

SELECT
    loan_id,
    disbursement_date,
    maturity_date,
    CURRENT_DATE - maturity_date AS days_past_maturity
FROM loans
WHERE status = 'active'
  AND maturity_date < CURRENT_DATE
ORDER BY maturity_date;

-- Sprints 2-3: borrowers, product joins, and application funnel.
SELECT COUNT(*) AS customers_never_borrowed
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM loans l
    WHERE l.customer_id = c.customer_id
);

SELECT
    p.product_name,
    COUNT(l.loan_id) AS loan_count,
    ROUND(AVG(l.principal), 2) AS average_loan_size,
    ROUND(SUM(l.principal), 2) AS total_principal_disbursed
FROM loan_products p
LEFT JOIN loans l ON l.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY average_loan_size DESC NULLS LAST;

SELECT
    p.category,
    COUNT(*) AS loan_count,
    ROUND(SUM(l.principal), 2) AS original_principal
FROM loans l
JOIN loan_products p ON p.product_id = l.product_id
GROUP BY p.category
ORDER BY loan_count DESC;

SELECT
    COUNT(*) AS total_applications,
    COUNT(*) FILTER (WHERE decision = 'approved') AS approved_applications,
    COUNT(*) FILTER (WHERE decision = 'declined') AS declined_applications,
    COUNT(*) FILTER (WHERE decision = 'pending') AS pending_applications,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE decision = 'approved')
        / NULLIF(COUNT(*), 0),
        1
    ) AS approval_rate_pct
FROM loan_applications;

-- Sprint 3: one-to-many-safe loan detail (aggregate payments before joining).
WITH paid_by_loan AS (
    SELECT loan_id, SUM(amount) AS completed_payment_amount
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
)
SELECT
    l.loan_id,
    c.full_name,
    c.region,
    p.product_name,
    l.principal,
    l.annual_rate,
    l.disbursement_date,
    COALESCE(pb.completed_payment_amount, 0) AS completed_payment_amount
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
JOIN loan_products p ON p.product_id = l.product_id
LEFT JOIN paid_by_loan pb ON pb.loan_id = l.loan_id
ORDER BY l.principal DESC
LIMIT 15;

-- Sprint 5: revised ageing boundaries and average original principal per bucket.
SELECT
    CASE
        WHEN dpd = 0 THEN 'Current'
        WHEN dpd <= 30 THEN '1-30'
        WHEN dpd <= 60 THEN '31-60'
        WHEN dpd <= 90 THEN '61-90'
        WHEN dpd <= 180 THEN '91-180'
        WHEN dpd <= 365 THEN '181-365'
        ELSE '366+'
    END AS dpd_bucket,
    COUNT(*) AS loan_count,
    ROUND(AVG(principal), 2) AS average_original_principal,
    ROUND(SUM(outstanding_principal), 2) AS outstanding_principal
FROM v_loan_dpd
WHERE loan_status IN ('active', 'delinquent', 'defaulted')
GROUP BY 1
ORDER BY MIN(dpd);

-- Closed loans are currently paid off, so current DPD is zero. Use dated snapshots
-- (rather than current state) to analyze any delinquency they cured in the past.
SELECT
    dpd_bucket,
    COUNT(*) AS closed_loan_count,
    ROUND(AVG(principal), 2) AS average_original_principal
FROM v_loan_dpd
WHERE loan_status = 'closed'
GROUP BY dpd_bucket
ORDER BY MIN(dpd_bucket);

-- Sprint 6: monthly disbursements with more than 100 loans.
SELECT
    DATE_TRUNC('month', disbursement_date)::DATE AS disbursement_month,
    COUNT(*) AS loan_count
FROM loans
GROUP BY 1
HAVING COUNT(*) > 100
ORDER BY disbursement_month;

-- Active principal share by product category.
SELECT
    p.category,
    SUM(l.principal) AS category_principal,
    SUM(SUM(l.principal)) OVER () AS total_active_principal,
    ROUND(
        100.0 * SUM(l.principal) / NULLIF(SUM(SUM(l.principal)) OVER (), 0),
        2
    ) AS pct_of_active_principal
FROM loans l
JOIN loan_products p ON p.product_id = l.product_id
WHERE l.status IN ('active', 'delinquent', 'defaulted')
GROUP BY p.category
ORDER BY pct_of_active_principal DESC;

SELECT
    p.category,
    c.region,
    COUNT(*) AS active_loan_count,
    ROUND(SUM(l.principal), 2) AS original_principal,
    ROUND(AVG(l.annual_rate), 2) AS average_annual_rate_pct
FROM loans l
JOIN loan_products p ON p.product_id = l.product_id
JOIN customers c ON c.customer_id = l.customer_id
WHERE l.status IN ('active', 'delinquent', 'defaulted')
GROUP BY p.category, c.region
ORDER BY p.category, c.region;

-- Sprint 9: top 3 active loans by product category, and top borrowers.
WITH ranked_loans AS (
    SELECT
        l.loan_id,
        p.category,
        l.principal,
        ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY l.principal DESC, l.loan_id)
            AS category_rank
    FROM loans l
    JOIN loan_products p ON p.product_id = l.product_id
    WHERE l.status IN ('active', 'delinquent', 'defaulted')
)
SELECT *
FROM ranked_loans
WHERE category_rank <= 3
ORDER BY category, category_rank;

WITH borrower_totals AS (
    SELECT customer_id, COUNT(*) AS loan_count, SUM(principal) AS total_principal
    FROM loans
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.full_name,
    c.region,
    bt.loan_count,
    ROUND(bt.total_principal, 2) AS total_principal,
    RANK() OVER (ORDER BY bt.total_principal DESC) AS borrower_rank
FROM borrower_totals bt
JOIN customers c ON c.customer_id = bt.customer_id
ORDER BY borrower_rank, c.customer_id
LIMIT 10;

-- Count loans per customer at loan grain.
SELECT
    loan_id,
    customer_id,
    principal,
    disbursement_date,
    COUNT(*) OVER (PARTITION BY customer_id) AS customer_loan_count,
    SUM(principal) OVER (PARTITION BY customer_id) AS customer_total_principal
FROM loans
ORDER BY customer_id, disbursement_date;

-- Disbursement volume by month and running total.
SELECT
    month,
    loan_count,
    amount_disbursed,
    SUM(amount_disbursed) OVER (ORDER BY month) AS cumulative_disbursements
FROM (
    SELECT
        DATE_TRUNC('month', disbursement_date)::DATE AS month,
        COUNT(*) AS loan_count,
        SUM(principal) AS amount_disbursed
    FROM loans
    GROUP BY 1
) monthly
ORDER BY month;
