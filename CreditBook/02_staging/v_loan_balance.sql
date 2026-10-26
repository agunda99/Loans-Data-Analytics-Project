-- Point-in-time balances as of today.
-- outstanding_principal is the PAR exposure; outstanding_receivable also includes
-- future contractual interest and should not be used as PAR exposure.
CREATE OR REPLACE VIEW v_loan_balance AS
SELECT
    s.loan_id,
    s.customer_id,
    s.product_id,
    s.loan_status,
    s.disbursement_date,
    s.principal,
    s.total_scheduled,
    s.total_paid,
    s.outstanding_receivable,
    s.outstanding_principal,
    s.oldest_overdue,
    s.dpd,
    CURRENT_DATE AS as_of_date
FROM fn_loan_state(CURRENT_DATE) AS s;
