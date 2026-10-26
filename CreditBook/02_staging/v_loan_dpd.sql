CREATE OR REPLACE VIEW v_loan_dpd AS
SELECT
    b.loan_id,
    b.customer_id,
    b.product_id,
    b.loan_status,
    b.disbursement_date,
    b.outstanding_principal,
    b.outstanding_receivable,
    b.oldest_overdue,
    b.dpd,
    CASE
        WHEN b.dpd = 0 THEN 'Current'
        WHEN b.dpd <= 30 THEN '1-30'
        WHEN b.dpd <= 60 THEN '31-60'
        WHEN b.dpd <= 90 THEN '61-90'
        ELSE '90+'
    END AS dpd_bucket,
    b.as_of_date,
    b.principal
FROM v_loan_balance AS b;
