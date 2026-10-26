-- Expected result: no rows. The table constraint and trigger also enforce this.
SELECT payment_id, loan_id, payment_date, amount, status
FROM payments
WHERE amount IS NULL OR amount <= 0;

-- Completed payments must not be dated after the current reporting date.
SELECT payment_id, loan_id, payment_date, amount
FROM payments
WHERE status = 'completed'
  AND payment_date > CURRENT_DATE;
