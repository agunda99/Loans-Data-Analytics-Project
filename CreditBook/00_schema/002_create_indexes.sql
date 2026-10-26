-- Foreign-key indexes and common report filters.
CREATE INDEX IF NOT EXISTS idx_applications_customer_date
    ON loan_applications (customer_id, application_date);
CREATE INDEX IF NOT EXISTS idx_loans_customer
    ON loans (customer_id);
CREATE INDEX IF NOT EXISTS idx_loans_product_disbursement
    ON loans (product_id, disbursement_date);
CREATE INDEX IF NOT EXISTS idx_loans_status_disbursement
    ON loans (status, disbursement_date);
CREATE INDEX IF NOT EXISTS idx_schedule_loan_installment
    ON repayment_schedule (loan_id, installment_no)
    INCLUDE (due_date, principal_due, interest_due, total_due);
CREATE INDEX IF NOT EXISTS idx_schedule_due_date
    ON repayment_schedule (due_date, loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_loan_date
    ON payments (loan_id, payment_date)
    INCLUDE (amount, status);
CREATE INDEX IF NOT EXISTS idx_collections_loan_date
    ON collections_actions (loan_id, action_date);
