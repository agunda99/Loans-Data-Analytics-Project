/*
SANITY CHECK
Confirm relationships & get the feel of the generated data.

A useful relationship to follow is: 

	customer → application → loan → repayment schedule → payment. 

Collection actions are associated with loans too. 
Avoid joining raw schedules, payments, and collections 
all together before aggregating: those one-to-many joins 
can multiply rows and inflate totals.
*/
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'loan_products', COUNT(*) FROM loan_products
UNION ALL SELECT 'loan_applications', COUNT(*) FROM loan_applications
UNION ALL SELECT 'loans', COUNT(*) FROM loans
UNION ALL SELECT 'repayment_schedule', COUNT(*) FROM repayment_schedule
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'collections_actions', COUNT(*) FROM collections_actions;

SELECT loan_id, customer_id, principal, annual_rate, tenor_months, status
FROM loans
ORDER BY loan_id
LIMIT 20;

SELECT loan_id, installment_no, due_date, principal_due, interest_due, total_due
FROM repayment_schedule
ORDER BY loan_id, installment_no
LIMIT 20;

SELECT payment_id, loan_id, payment_date, amount, channel, status 
FROM payments
ORDER BY 3, 4
LIMIT 20;

SELECT  channel, count(*) 
FROM payments
GROUP BY channel
LIMIT 20;

SELECT product_id, product_name, category, min_amount, max_amount, min_tenor, max_tenor 
FROM loan_products
ORDER BY 2
LIMIT 20;

SELECT * 
FROM loan_applications
ORDER BY 1
LIMIT 20;

SELECT lp.product_name, lp.category, COUNT(*)
FROM loan_applications la
JOIN loan_products lp
ON lp.product_id = la.product_id
GROUP BY lp.product_name, lp.category
ORDER BY 1
LIMIT 20;

SELECT * 
FROM customers
ORDER BY 1
LIMIT 20;

SELECT agent, outcome, COUNT(*)
FROM collections_actions
GROUP BY 1, 2	-- Always come before 'ORDER BY'
ORDER BY 1
LIMIT 20;