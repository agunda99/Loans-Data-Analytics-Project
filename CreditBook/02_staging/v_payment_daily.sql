-- Daily payment activity by receipt date and payment status.
CREATE OR REPLACE VIEW v_payment_daily AS
SELECT
    payment_date,
    channel,
    status,
    COUNT(*) AS payment_count,
    SUM(amount) AS payment_amount,
    COUNT(DISTINCT loan_id) AS loans_paid
FROM payments
GROUP BY payment_date, channel, status;
