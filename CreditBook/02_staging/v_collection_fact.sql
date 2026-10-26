-- One row per collection action. It intentionally reports recorded outcomes,
-- not causal recovery attribution (actions are not linked to payment IDs).
CREATE OR REPLACE VIEW v_collection_fact AS
SELECT
    ca.action_id,
    ca.loan_id,
    l.customer_id,
    l.product_id,
    c.region,
    ca.action_date,
    ca.action_type,
    ca.agent,
    ca.outcome,
    b.dpd AS current_dpd,
    b.outstanding_principal AS current_outstanding_principal
FROM collections_actions AS ca
JOIN loans AS l ON l.loan_id = ca.loan_id
JOIN customers AS c ON c.customer_id = l.customer_id
LEFT JOIN v_loan_balance AS b ON b.loan_id = ca.loan_id;

-- Least-privilege work queue: one row per overdue loan, with contact details.
CREATE OR REPLACE VIEW v_collections_worklist
WITH (security_barrier = true) AS
SELECT * FROM fn_collections_worklist();
