CREATE OR REPLACE VIEW v_customer_summary AS
SELECT
    c.customer_id,
    c.full_name,
    c.phone,
    c.region,
    COUNT(b.loan_id) AS loan_count,
    COALESCE(SUM(b.principal), 0) AS total_principal_disbursed,
    COALESCE(SUM(b.outstanding_principal), 0) AS outstanding_principal,
    COALESCE(SUM(b.outstanding_receivable), 0) AS outstanding_receivable,
    COUNT(b.loan_id) FILTER (WHERE b.dpd >= 30) AS loans_30_plus_dpd
FROM customers AS c
LEFT JOIN v_loan_balance AS b ON b.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.phone, c.region;
