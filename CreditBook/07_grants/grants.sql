-- Apply after schema, functions, views, and materialized views exist.
-- Grant login users membership in these NOLOGIN groups separately.
REVOKE ALL ON customers, loan_products, loan_applications, loans,
    repayment_schedule, payments, collections_actions,
    v_loan_balance, v_loan_dpd, v_payment_daily, v_collection_fact,
    v_collections_worklist, v_customer_summary, mv_portfolio_par
FROM PUBLIC;

REVOKE ALL ON FUNCTION fn_loan_state(DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_dpd(INT, DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_portfolio_par(DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_collections_worklist() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_validate_payment() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_set_payment_status() FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO
    creditbook_analyst, creditbook_risk_officer,
    creditbook_collections, creditbook_cfo;

GRANT SELECT ON
    loans, loan_products, repayment_schedule, payments,
    v_loan_balance, v_loan_dpd, v_payment_daily, mv_portfolio_par
TO creditbook_analyst;
GRANT SELECT (customer_id, region) ON customers TO creditbook_analyst;
GRANT EXECUTE ON FUNCTION fn_loan_state(DATE) TO creditbook_analyst;
GRANT EXECUTE ON FUNCTION fn_dpd(INT, DATE) TO creditbook_analyst;
GRANT EXECUTE ON FUNCTION fn_portfolio_par(DATE) TO creditbook_analyst;

GRANT creditbook_analyst TO creditbook_risk_officer;
GRANT SELECT ON customers, loan_applications, v_customer_summary, v_collection_fact
TO creditbook_risk_officer;
GRANT UPDATE (decision) ON loan_applications TO creditbook_risk_officer;
GRANT UPDATE (status) ON loans TO creditbook_risk_officer;

REVOKE ALL ON customers, loan_products, loan_applications, loans,
    repayment_schedule, payments, collections_actions
FROM creditbook_collections;
GRANT SELECT ON v_collections_worklist TO creditbook_collections;
GRANT EXECUTE ON FUNCTION fn_collections_worklist() TO creditbook_collections;
GRANT INSERT (loan_id, payment_date, amount, channel, status) ON payments
TO creditbook_collections;
GRANT USAGE, SELECT ON SEQUENCE payments_payment_id_seq TO creditbook_collections;

GRANT creditbook_analyst TO creditbook_cfo;
GRANT SELECT ON customers, loan_applications, collections_actions,
    v_customer_summary, v_collection_fact
TO creditbook_cfo;

-- Explicitly remove write/DDL permissions inherited from accidental prior grants.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON
    customers, loan_products, loan_applications, loans,
    repayment_schedule, payments, collections_actions
FROM creditbook_analyst, creditbook_cfo;
