-- High-priority open-loan worklist. Use only with appropriate PII permissions.
SELECT
    s.loan_id,
    s.customer_id,
    c.full_name,
    c.phone,
    COALESCE(c.region, 'unknown') AS region,
    p.product_name,
    s.disbursement_date,
    s.principal,
    s.outstanding_principal,
    s.oldest_overdue,
    s.dpd,
    CASE
        WHEN s.dpd >= 90 THEN 'Critical'
        WHEN s.dpd >= 60 THEN 'High'
        WHEN s.dpd >= 30 THEN 'Elevated'
        ELSE 'Monitor'
    END AS collection_priority
FROM fn_loan_state(CURRENT_DATE) AS s
JOIN customers AS c ON c.customer_id = s.customer_id
JOIN loan_products AS p ON p.product_id = s.product_id
WHERE s.loan_status IN ('active', 'delinquent', 'defaulted')
  AND s.dpd > 0
  AND s.outstanding_principal > 0
ORDER BY s.dpd DESC, s.outstanding_principal DESC, s.loan_id
LIMIT 20;
