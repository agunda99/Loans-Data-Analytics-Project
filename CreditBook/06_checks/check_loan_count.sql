-- Expected invariant: each disbursed loan has exactly tenor_months installments.
SELECT
    l.loan_id,
    l.tenor_months,
    COUNT(rs.schedule_id) AS installment_count
FROM loans l
LEFT JOIN repayment_schedule rs ON rs.loan_id = l.loan_id
GROUP BY l.loan_id, l.tenor_months
HAVING COUNT(rs.schedule_id) <> l.tenor_months
ORDER BY l.loan_id;

-- Expected invariant: scheduled principal amortizes the full original principal.
SELECT
    l.loan_id,
    l.principal AS original_principal,
    SUM(rs.principal_due) AS scheduled_principal
FROM loans l
JOIN repayment_schedule rs ON rs.loan_id = l.loan_id
GROUP BY l.loan_id, l.principal
HAVING ABS(l.principal - SUM(rs.principal_due)) > 0.01
ORDER BY l.loan_id;

-- Expected invariant: disbursed loans trace back to an approved application
-- for the same customer and product.
SELECT
    l.loan_id,
    l.application_id,
    l.customer_id AS loan_customer_id,
    a.customer_id AS application_customer_id,
    l.product_id AS loan_product_id,
    a.product_id AS application_product_id,
    a.decision
FROM loans l
JOIN loan_applications a ON a.application_id = l.application_id
WHERE a.decision <> 'approved'
   OR l.customer_id <> a.customer_id
   OR l.product_id <> a.product_id;
