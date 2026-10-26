-- Database: creditbook_db

-- DROP DATABASE IF EXISTS creditbook_db;

CREATE DATABASE creditbook_db
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'English_United States.1252'
    LC_CTYPE = 'English_United States.1252'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- Create Schemas

DROP TABLE IF EXISTS collections_actions CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS repayment_schedule CASCADE;
DROP TABLE IF EXISTS loans CASCADE;
DROP TABLE IF EXISTS loan_applications CASCADE;
DROP TABLE IF EXISTS loan_products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    customer_id      SERIAL PRIMARY KEY,
    full_name        TEXT NOT NULL,
    date_of_birth    DATE NOT NULL,
    gender           CHAR(1),
    region           TEXT,
    employment_type  TEXT,
    monthly_income   NUMERIC(12,2),
    credit_score     INT,
    kyc_status       TEXT DEFAULT 'verified',
    onboarded_at     TIMESTAMP DEFAULT now()
);

CREATE TABLE loan_products (
    product_id        SERIAL PRIMARY KEY,
    product_name      TEXT NOT NULL,
    category          TEXT,
    min_amount        NUMERIC(12,2),
    max_amount        NUMERIC(12,2),
    min_tenor         INT,
    max_tenor         INT,
    base_annual_rate  NUMERIC(5,2)
);

CREATE TABLE loan_applications (
    application_id    SERIAL PRIMARY KEY,
    customer_id       INT REFERENCES customers(customer_id),
    product_id        INT REFERENCES loan_products(product_id),
    application_date  DATE NOT NULL,
    requested_amount  NUMERIC(12,2),
    requested_tenor   INT,
    decision          TEXT,
    decision_date     DATE,
    approved_amount   NUMERIC(12,2),
    approved_rate     NUMERIC(5,2)
);

CREATE TABLE loans (
    loan_id            SERIAL PRIMARY KEY,
    application_id     INT REFERENCES loan_applications(application_id),
    customer_id        INT REFERENCES customers(customer_id),
    product_id         INT REFERENCES loan_products(product_id),
    principal          NUMERIC(12,2) NOT NULL,
    annual_rate        NUMERIC(5,2)  NOT NULL,
    tenor_months       INT           NOT NULL,
    disbursement_date  DATE NOT NULL,
    maturity_date      DATE NOT NULL,
    status             TEXT NOT NULL
);

CREATE TABLE repayment_schedule (
    schedule_id      SERIAL PRIMARY KEY,
    loan_id          INT REFERENCES loans(loan_id),
    installment_no   INT NOT NULL,
    due_date         DATE NOT NULL,
    principal_due    NUMERIC(12,2),
    interest_due     NUMERIC(12,2),
    total_due        NUMERIC(12,2)
);

CREATE TABLE payments (
    payment_id    SERIAL PRIMARY KEY,
    loan_id       INT REFERENCES loans(loan_id),
    payment_date  DATE NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    channel       TEXT,
    status        TEXT DEFAULT 'completed'
);

CREATE TABLE collections_actions (
    action_id     SERIAL PRIMARY KEY,
    loan_id       INT REFERENCES loans(loan_id),
    action_date   DATE NOT NULL,
    action_type   TEXT,
    agent         TEXT,
    outcome       TEXT,
    notes         TEXT
);

--Seed Data
-- Products
INSERT INTO loan_products (product_name, category, min_amount, max_amount, min_tenor, max_tenor, base_annual_rate) VALUES
('Personal Standard',   'personal', 5000,   100000,   6, 36, 18.5),
('Personal Premium',    'personal', 100000, 1000000, 12, 60, 14.0),
('SME Working Capital', 'business', 20000,  2000000,  3, 24, 22.0),
('Auto Loan',           'auto',     200000, 3000000, 12, 84, 12.5),
('Micro Loan',          'micro',    500,    20000,    1, 12, 28.0);

-- Customers
INSERT INTO customers (full_name, date_of_birth, gender, region, employment_type, monthly_income, credit_score)
SELECT
    'Cust ' || g,
    DATE '1965-01-01' + (random()*15000)::int,
    (ARRAY['M','F'])[1 + (random()*1)::int],
    (ARRAY['Nairobi','Mombasa','Kisumu','Nakuru','Eldoret'])[1 + (random()*4)::int],
    (ARRAY['salaried','self_employed','business_owner','casual'])[1 + (random()*3)::int],
    (20000 + random()*300000)::numeric(12,2),
    (300 + random()*500)::int
FROM generate_series(1, 2000) g;

-- Applications (each customer applies 1-3 times over the last 24 months)
INSERT INTO loan_applications (customer_id, product_id, application_date, requested_amount, requested_tenor, decision, decision_date)
SELECT
    c.customer_id,
    p.product_id,
    CURRENT_DATE - ((random()*730)::int),
    (p.min_amount + random()*(p.max_amount - p.min_amount))::numeric(12,2),
    p.min_tenor + ((random()*(p.max_tenor - p.min_tenor))::int),
    CASE WHEN random() < 0.70 THEN 'approved'
         WHEN random() < 0.90 THEN 'declined'
         ELSE 'pending' END,
    CURRENT_DATE - ((random()*720)::int)
FROM customers c
JOIN LATERAL (SELECT * FROM loan_products ORDER BY random() LIMIT 1) p ON true
CROSS JOIN generate_series(1, 1 + (random()*2)::int);

-- Approved amounts and rates
UPDATE loan_applications a
SET approved_amount = LEAST(a.requested_amount, p.max_amount),
    approved_rate   = p.base_annual_rate
                    + CASE WHEN c.credit_score > 700 THEN -2.0 ELSE 3.0 END
FROM loan_products p, customers c
WHERE a.product_id = p.product_id
  AND a.customer_id = c.customer_id
  AND a.decision = 'approved';

-- Loans: 85% of approved applications become disbursed loans
INSERT INTO loans (application_id, customer_id, product_id, principal, annual_rate, tenor_months,
                   disbursement_date, maturity_date, status)
SELECT
    a.application_id, a.customer_id, a.product_id,
    a.approved_amount, a.approved_rate, a.requested_tenor,
    a.decision_date + 3,
    a.decision_date + 3 + (a.requested_tenor * INTERVAL '1 month'),
    'active'
FROM loan_applications a
WHERE a.decision = 'approved'
  AND a.approved_amount IS NOT NULL
  AND random() < 0.85;

-- Repayment schedule: equal-principal installments (simple, defensible)
INSERT INTO repayment_schedule (loan_id, installment_no, due_date, principal_due, interest_due, total_due)
SELECT
    l.loan_id,
    k,
    (l.disbursement_date + (k * INTERVAL '1 month'))::date,
    round(l.principal / l.tenor_months, 2),
    round((l.principal - (k-1)*(l.principal/l.tenor_months)) * (l.annual_rate/12.0/100), 2),
    round(l.principal / l.tenor_months, 2)
      + round((l.principal - (k-1)*(l.principal/l.tenor_months)) * (l.annual_rate/12.0/100), 2)
FROM loans l
CROSS JOIN LATERAL generate_series(1, l.tenor_months) k;

-- Payments: ~83% of past-due installments are paid, 0-60 days late
INSERT INTO payments (loan_id, payment_date, amount, channel)
SELECT
    rs.loan_id,
    rs.due_date + ((random()*60)::int),
    rs.total_due,
    (ARRAY['mobile_money','bank_transfer','cash','card'])[1 + (random()*3)::int]
FROM repayment_schedule rs
WHERE rs.due_date < CURRENT_DATE
  AND random() < 0.83;

-- Some collection actions
INSERT INTO collections_actions (loan_id, action_date, action_type, agent, outcome)
SELECT
    l.loan_id,
    CURRENT_DATE - ((random()*90)::int),
    (ARRAY['call','sms','email','visit'])[1 + (random()*3)::int],
    'agent_' || (1 + (random()*20)::int),
    (ARRAY['promise_to_pay','no_answer','paid','escalated'])[1 + (random()*3)::int]
FROM loans l
WHERE random() < 0.30;

-- Mark fully-repaid past-due loans as closed
WITH cumulative AS (
    SELECT rs.loan_id, rs.due_date, rs.total_due,
           SUM(rs.total_due) OVER (PARTITION BY rs.loan_id ORDER BY rs.installment_no) AS cum_due
    FROM repayment_schedule rs
), paid AS (
    SELECT loan_id, SUM(amount) AS total_paid FROM payments GROUP BY loan_id
)
UPDATE loans l
SET status = 'closed'
FROM (
    SELECT c.loan_id
    FROM cumulative c JOIN paid p USING (loan_id)
    WHERE c.due_date <= CURRENT_DATE
    GROUP BY c.loan_id, p.total_paid
    HAVING MAX(c.cum_due) <= p.total_paid
) done
WHERE l.loan_id = done.loan_id;

--Sanity Check
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'loans', COUNT(*) FROM loans
UNION ALL SELECT 'installments', COUNT(*) FROM repayment_schedule
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'collections', COUNT(*) FROM collections_actions;

--What does our loan book look like at a glance
SELECT * FROM loans; --All columns present in our loan book

-- The ten largest active loans
SELECT loan_id, customer_id, principal, annual_rate, tenor_months, disbursement_date
FROM   loans
WHERE  status = 'active'
ORDER  BY principal DESC
LIMIT  10;

-- All loans over 500,000 with an interest rate below 15%
SELECT loan_id, customer_id, principal, annual_rate, tenor_months, disbursement_date
FROM loans
WHERE principal > 500000 
AND annual_rate < 15
ORDER BY disbursement_date DESC;

-- Loans disbursed in the last 90 days, newest first.
SELECT loan_id, customer_id, principal, annual_rate, tenor_months, disbursement_date
FROM loans
WHERE disbursement_date IS NOT NULL
AND disbursement_date >= CURRENT_DATE - INTERVAL'90 days'
ORDER BY disbursement_date DESC;

--Five customers in Nairobi with the highest credit score
SELECT customer_id, full_name, gender, employment_type, monthly_income, credit_score
FROM customers
WHERE region = 'Nairobi'
ORDER BY credit_score DESC
LIMIT 5;

-- Applications that were declined last year
SELECT application_id, application_date, requested_amount, decision_date
FROM loan_applications
WHERE decision = 'declined'
AND decision_date IS NOT NULL
AND decision_date > current_date-interval'1 year'
ORDER BY decision_date;

-- How many applications were declined in the last year
SELECT 
	COUNT(*) total_applications_declined_last_yr
FROM loan_applications
WHERE decision = 'declined'
AND decision_date IS NOT NULL
AND decision_date > current_date-interval'1 year'


-- PORTFOLIO AT A GLANCE
-- How many loans do we have? How many loans are out there?
SELECT
    COUNT(*)                        AS total_loans,
    COUNT(*) FILTER (WHERE status = 'active') AS active_loans,
    COUNT(*) FILTER (WHERE status = 'closed') AS closed_loans,
    COUNT(DISTINCT customer_id)     AS distinct_borrowers,
    ROUND(SUM(principal), 2)        AS total_disbursed,
    ROUND(AVG(principal), 2)        AS avg_loan_size,
    ROUND(AVG(annual_rate), 2)      AS avg_rate
FROM loans;

-- What fraction of applications are approved? Show as a percentage rounded to one decimal.
SELECT COUNT(*)
FROM loan_applications
WHERE decision = 'approved'; 

SELECT 
	COUNT (*) total_loans,
	COUNT (
		CASE WHEN decision = 'approved'
		THEN 1 END) approved_loans
FROM loan_applications;
	

SELECT ROUND(
			(100.0 * --ADD 100.0 for float division
			COUNT(
				CASE WHEN decision = 'approved'
				THEN 1 
				END) / 
			COUNT (*)),
			1
			) AS approved_application_percentage
FROM loan_applications; 

-- Compute the average loan size by product 
SELECT * FROM loans;
SELECT * FROM loan_products;
SELECT product_id, 
	ROUND(AVG(principal),2) avg_loan_size,
	COUNT(*) loan_count
FROM loans 
GROUP BY product_id
ORDER BY avg_loan_size DESC;

SELECT lp.product_name, 
	AVG(principal) avg_loan_size,
	COUNT(*) loan_count
FROM loans l
JOIN loan_products lp
ON l.product_id = lp.product_id
GROUP BY lp.product_id
ORDER BY avg_loan_size DESC;

-- Joining the dots (and the trap)
--  For each loan, who is the borrower and what product is it?
SELECT
    l.loan_id,
    c.full_name,
    c.region,
    p.product_name,
    l.principal,
    l.annual_rate,
    l.disbursement_date
FROM   loans l
JOIN   customers c      ON c.customer_id = l.customer_id
JOIN   loan_products p  ON p.product_id  = l.product_id
WHERE  l.status = 'active'
ORDER  BY l.principal DESC
LIMIT  15;

-- How many customers have never taken a loan? 
SELECT * FROM customers;
SELECT * FROM loans;
SELECT 
	c.customer_id,
	full_name,
	gender,
	region,
	employment_type,
	credit_score
FROM customers c
WHERE NOT EXISTS (
	SELECT 1 FROM loans l 
	WHERE l.customer_id = c.customer_id
); -- Display list

-- Sanity check
SELECT * 
FROM loans 
WHERE customer_id 
IN (9, 10, 100, 15, 21, 23, 26);

SELECT COUNT(*) 
AS customers_never_borrowed
FROM customers c
LEFT JOIN  loans l 
ON c.customer_id = l.customer_id
WHERE l.customer_id IS NULL;

-- Join loans to loan_products and count loans per product category.
SELECT 
	l.product_id,
	l.principal,
	lp.product_name
FROM loans l
JOIN loan_products lp
ON l.product_id = lp.product_id;

SELECT 
	lp.product_name,
	COUNT (*) AS loan_count,
	ROUND(SUM(l.principal), 2) total_amt,
	ROUND(AVG(l.principal), 2) avg_amt
FROM loans l
JOIN loan_products lp
ON l.product_id = lp.product_id
WHERE l.disbursement_date IS NOT NULL -- or l.status = 'disbursed'
GROUP BY lp.product_name
ORDER BY loan_count DESC;

-- Which loans are overdue, and by how much?
-- How old is each loan, in days and months?
SELECT
    loan_id,
    disbursement_date,
    maturity_date,
    (CURRENT_DATE - disbursement_date)          AS days_since_disbursement,
    (CURRENT_DATE - maturity_date)              AS days_past_maturity,
    DATE_TRUNC('month', disbursement_date)::date AS disbursement_month
FROM   loans
WHERE  status = 'active'
ORDER  BY days_since_disbursement DESC
LIMIT  10;

-- Loans whose maturity_date has already passed but status is still active.
SELECT 
	loan_id,
	disbursement_date,
	maturity_date
FROM loans
WHERE CURRENT_DATE > maturity_date
AND status = 'active'
ORDER BY maturity_date DESC;

-- OR to see how many days past maturity date
SELECT 
	loan_id,
	disbursement_date,
	maturity_date,
	status,
	(CURRENT_DATE - maturity_date) AS DPD
FROM loans
WHERE status = 'active'
AND (CURRENT_DATE - maturity_date) >= 1
ORDER BY DPD;

-- For each loan, compute days_since_disbursement / 30.44 rounded to 1 decimal — the "age in months."
SELECT 
	loan_id,
	disbursement_date,
	maturity_date,
	ROUND(
		((CURRENT_DATE - disbursement_date) / 30.44),
		1
	) AS age_in_months
FROM loans;

-- Group loans by DATE_TRUNC('month', disbursement_date) and count per month
SELECT
    DATE_TRUNC('month', disbursement_date)::date AS disbursement_month,
    COUNT(*)                                     AS loan_count
FROM   loans
GROUP  BY 1
ORDER  BY 1;


-- How many of our active loans are overdue, and how badly?
WITH first_unpaid AS (
    SELECT
        rs.loan_id,
        MIN(rs.due_date) FILTER (WHERE rs.due_date < CURRENT_DATE) AS first_due_date
    FROM repayment_schedule rs
    GROUP BY rs.loan_id
)
SELECT
    CASE
        WHEN fu.first_due_date IS NULL THEN 'not yet started'
        WHEN CURRENT_DATE - fu.first_due_date <= 0  THEN 'current'
        WHEN CURRENT_DATE - fu.first_due_date <= 30 THEN '1-30 DPD'
        WHEN CURRENT_DATE - fu.first_due_date <= 60 THEN '31-60 DPD'
        WHEN CURRENT_DATE - fu.first_due_date <= 90 THEN '61-90 DPD'
        ELSE '90+ DPD'
    END AS dpd_bucket,
    COUNT(*) AS num_loans
FROM loans l
LEFT JOIN first_unpaid fu USING (loan_id)
WHERE l.status = 'active'
GROUP BY 1
ORDER BY MIN(CURRENT_DATE - fu.first_due_date) NULLS LAST;

-- MORE WORK ON CTEs
-- Change the bucket boundaries to 0, 30, 60, 90, 180, 365 days.

-- Add a column showing the average principal per bucket.

-- Reproduce the bucket for closed loans. Are there any? Why would there be? (Hint: if a loan was paid off late, it can be closed with historic DPD.)


-- GROUPING FOR MANAGEMENT
--  Break down the portfolio by product, region, and disbursement month.
SELECT
    p.category                        AS product_category,
    COUNT(*)                          AS num_loans,
    ROUND(SUM(l.principal), 2)        AS total_principal,
    ROUND(AVG(l.principal), 2)        AS avg_size,
    ROUND(AVG(l.annual_rate), 2)      AS avg_rate
FROM   loans l
JOIN   loan_products p ON p.product_id = l.product_id
WHERE  l.status = 'active'
GROUP  BY p.category
ORDER  BY total_principal DESC;
-- Aliases in GROUP BY.
-- Postgres allows GROUP BY p.category (the expression) or GROUP BY 1 (position).
-- It does not allow GROUP BY product_category (the alias) in the same SELECT.
-- Use the position form for fat CASE columns.

-- THE RULES:
-- The rule: every non-aggregated column in SELECT must be in GROUP BY. Postgres enforces it; SQLite doesn't; MySQL sometimes doesn't. Learn the rule once and you'll never be confused again.
-- HAVING filters groups (post-aggregation); WHERE filters rows (pre-aggregation):
-- Products with more than 200 active loans

SELECT 
	p.product_name, 
	COUNT(*) AS total_loans
FROM   loans l 
JOIN loan_products p 
USING (product_id) -- or ON l.product_id = p.product_id
WHERE  l.status = 'active'
GROUP  BY p.product_name
HAVING COUNT(*) > 200
ORDER  BY total_loans DESC;

-- Break down active loans by region and product_category in one query.
SELECT
    c.region    AS region,
    p.category  AS category,
    COUNT(*)    AS count_loans,
    SUM(l.principal) AS sum_loans
FROM loans l
JOIN customers     c 
ON c.customer_id = l.customer_id
JOIN loan_products p 
ON p.product_id  = l.product_id
WHERE l.status = 'active'
GROUP BY c.region, p.category
ORDER BY c.region, p.category;


-- Which disbursement months (as DATE_TRUNC('month', disbursement_date)) had more than 100 loans?
SELECT
    DATE_TRUNC('month', disbursement_date) AS disbursement_month,
    COUNT(*)                               AS loan_count
FROM   loans
WHERE  disbursement_date IS NOT NULL
GROUP  BY DATE_TRUNC('month', disbursement_date)
HAVING COUNT(*) > 100
ORDER  BY disbursement_month;

-- For each product category, show the share of total active principal (use a window function)
SELECT
    p.category,
    SUM(l.principal)                                        AS category_principal,
    SUM(SUM(l.principal)) OVER ()                            AS total_active_principal,
    ROUND(
        100.0 * SUM(l.principal)
              / SUM(SUM(l.principal)) OVER (),
        2
    )                                                        AS pct_of_total
FROM loans l
JOIN loan_products p 
ON p.product_id = l.product_id
WHERE l.status = 'active'
GROUP BY p.category
ORDER BY pct_of_total DESC; 

-- CTEs & THE PAYMENT ALLOCATION PROBLEM
-- For each loan, what is its real DPD, taking partial payments into account?
WITH installments AS (
    SELECT
        rs.loan_id,
        rs.installment_no,
        rs.due_date,
        rs.total_due,
        SUM(rs.total_due) OVER (
            PARTITION BY rs.loan_id
            ORDER BY rs.installment_no
        ) AS cum_due
    FROM repayment_schedule rs
),
paid AS (
    SELECT 
		loan_id, 
		SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT
        i.loan_id,
        i.installment_no,
        i.due_date,
        i.total_due,
        i.cum_due,
        COALESCE(p.total_paid, 0) AS total_paid,
        CASE
            WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid'
            ELSE 'unpaid'
        END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
)
SELECT
    loan_id,
    MIN(due_date)
		FILTER 
		(
			WHERE inst_status = 'unpaid' 
			AND due_date < CURRENT_DATE
		) AS oldest_overdue,
    GREATEST(0, CURRENT_DATE - MIN(due_date) 
		FILTER 
		(
			WHERE inst_status = 'unpaid' 
			AND due_date < CURRENT_DATE
		)) AS dpd
FROM tagged
GROUP BY loan_id
ORDER BY dpd DESC NULLS LAST
LIMIT 50;

-- Per-loan view: outstanding balance + customer + DPD (as of :asof)
WITH params AS (
    SELECT DATE '2026-10-23' AS asof        -- change this one line per run
),
installments AS (
    SELECT
        rs.loan_id,
        rs.installment_no,
        rs.due_date,
        rs.total_due,
        SUM(rs.total_due) OVER (
            PARTITION BY rs.loan_id
            ORDER BY rs.installment_no
        ) AS cum_due
    FROM repayment_schedule rs
),
paid AS (
    SELECT p.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    CROSS JOIN params
    WHERE p.status = 'completed'
      AND p.payment_date <= params.asof
    GROUP BY p.loan_id
),
tagged AS (
    SELECT
        i.loan_id,
        i.installment_no,
        i.due_date,
        i.total_due,
        i.cum_due,
        COALESCE(p.total_paid, 0) AS total_paid,
        CASE
            WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid'
            ELSE 'unpaid'
        END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_agg AS (
    SELECT
        t.loan_id,
        SUM(t.total_due)                 AS total_scheduled,
        MAX(t.total_paid)                AS total_paid,
        GREATEST(0, SUM(t.total_due) - MAX(t.total_paid)) AS outstanding_balance,
        MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid'
              AND t.due_date < (SELECT asof FROM params)
        ) AS oldest_overdue
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    l.loan_id,
    c.full_name                              AS customer_name,
    COALESCE(c.region, 'unknown')       AS phone_region,
    la.total_scheduled,
    la.total_paid,
    la.outstanding_balance,
    la.oldest_overdue,
    COALESCE(prm.asof - la.oldest_overdue, 0) AS dpd
FROM loan_agg la
JOIN loans     l ON l.loan_id     = la.loan_id
JOIN customers c ON c.customer_id = l.customer_id
CROSS JOIN params prm
ORDER BY dpd DESC NULLS LAST
LIMIT 20;

-- DPDs Buckets
WITH params AS (
    SELECT DATE '2026-10-23' AS asof        -- change this one line per run
),
installments AS (
    SELECT
        rs.loan_id,
        rs.installment_no,
        rs.due_date,
        rs.total_due,
        SUM(rs.total_due) OVER (
            PARTITION BY rs.loan_id
            ORDER BY rs.installment_no
        ) AS cum_due
    FROM repayment_schedule rs
),
paid AS (
    SELECT p.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    CROSS JOIN params
    WHERE p.status = 'completed'
      AND p.payment_date <= params.asof
    GROUP BY p.loan_id
),
tagged AS (
    SELECT
        i.loan_id,
        i.installment_no,
        i.due_date,
        i.total_due,
        i.cum_due,
        COALESCE(p.total_paid, 0) AS total_paid,
        CASE
            WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid'
            ELSE 'unpaid'
        END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_agg AS (
    SELECT
        t.loan_id,
        SUM(t.total_due)                 AS total_scheduled,
        MAX(t.total_paid)                AS total_paid,
        GREATEST(0, SUM(t.total_due) - MAX(t.total_paid)) AS outstanding_balance,
        MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid'
              AND t.due_date < (SELECT asof FROM params)
        ) AS oldest_overdue
    FROM tagged t
    GROUP BY t.loan_id
)
, per_loan AS (
    SELECT
        la.loan_id,
        la.outstanding_balance,
        COALESCE(prm.asof - la.oldest_overdue, 0) AS dpd
    FROM loan_agg la
    CROSS JOIN params prm
)
SELECT
    CASE
        WHEN dpd = 0    THEN '0 - current'
        WHEN dpd <= 30  THEN '1 - 30'
        WHEN dpd <= 60  THEN '31 - 60'
        WHEN dpd <= 90  THEN '61 - 90'
        ELSE                 '90+'
    END                       AS dpd_bucket,
    COUNT(*)                  AS loan_count,
    SUM(outstanding_balance)  AS bucket_outstanding_balance
FROM per_loan
GROUP BY 1
ORDER BY MIN(dpd);

-- PAR: the number every CFO stares at
-- What is our Portfolio at Risk at 30, 60, and 90 days?

-- PAR = the outstanding balance of loans that are n or more days past due, 
-- divided by total outstanding balance. It's the standard benchmark.
-- PAR30 > 5% gets the risk team called to a meeting.

WITH installments AS (
    SELECT 
		loan_id, 
		installment_no, 
		due_date, total_due,
        SUM(total_due) 
			OVER 
			(
				PARTITION BY loan_id 
				ORDER BY installment_no
			) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT 
		loan_id, 
		SUM(amount) AS total_paid 
	FROM payments 
	WHERE status='completed' 
	GROUP BY loan_id
),
tagged AS (
    SELECT 
		i.*, 
		COALESCE(p.total_paid,0) AS total_paid,
        CASE 
			WHEN COALESCE(p.total_paid,0) >= i.cum_due 
			THEN 'paid' 
			ELSE 'unpaid' 
			END AS inst_status
    FROM installments i 
	LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
            WHERE t.inst_status='unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    ROUND(SUM(outstanding), 2)                                           AS total_outstanding,
    ROUND(SUM(outstanding) FILTER (WHERE dpd >= 30), 2)                 AS par30_balance,
    ROUND(SUM(outstanding) FILTER (WHERE dpd >= 60), 2)                 AS par60_balance,
    ROUND(SUM(outstanding) FILTER (WHERE dpd >= 90), 2)                 AS par90_balance,
    ROUND(100.0 * SUM(outstanding) FILTER (WHERE dpd >= 30) / SUM(outstanding), 2) AS par30_pct,
    ROUND(100.0 * SUM(outstanding) FILTER (WHERE dpd >= 60) / SUM(outstanding), 2) AS par60_pct,
    ROUND(100.0 * SUM(outstanding) FILTER (WHERE dpd >= 90) / SUM(outstanding), 2) AS par90_pct
FROM loan_state s
JOIN loans l USING (loan_id)
WHERE l.status = 'active';


-- Compute PAR by product category and by region. Show as percentages.
-- PAR by product category
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT i.*, COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    p.category,
    COUNT(*)                                                          AS loan_count,
    ROUND(SUM(s.outstanding), 2)                                      AS total_outstanding,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)          AS par30_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 60), 2)          AS par60_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 90), 2)          AS par90_balance,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par30_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 60)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par60_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 90)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par90_pct
FROM loan_state s
JOIN loans         l ON l.loan_id     = s.loan_id
JOIN loan_products p ON p.product_id  = l.product_id
WHERE l.status = 'active'
GROUP BY p.category
ORDER BY par30_pct DESC NULLS LAST;

-- PAR by region
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT i.*, COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    COALESCE(c.region, 'unknown')                                     AS region,
    COUNT(*)                                                          AS loan_count,
    ROUND(SUM(s.outstanding), 2)                                      AS total_outstanding,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)          AS par30_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 60), 2)          AS par60_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 90), 2)          AS par90_balance,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par30_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 60)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par60_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 90)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par90_pct
FROM loan_state s
JOIN loans     l ON l.loan_id     = s.loan_id
JOIN customers c ON c.customer_id = l.customer_id
WHERE l.status = 'active'
GROUP BY c.region
ORDER BY par30_pct DESC NULLS LAST;

-- Compute PAR by disbursement vintage (monthly)
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT i.*, COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    DATE_TRUNC('month', l.disbursement_date)::date                    AS vintage_month,
    COUNT(*)                                                          AS loan_count,
    ROUND(SUM(s.outstanding), 2)                                      AS total_outstanding,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)          AS par30_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 60), 2)          AS par60_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 90), 2)          AS par90_balance,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par30_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 60)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par60_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 90)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par90_pct
FROM loan_state s
JOIN loans l ON l.loan_id = s.loan_id
WHERE l.status = 'active'
  AND l.disbursement_date IS NOT NULL
GROUP BY DATE_TRUNC('month', l.disbursement_date)
ORDER BY vintage_month;

-- Trend it: PAR by DATE_TRUNC('month', CURRENT_DATE) — since we only have one snapshot, you'll need to add a :asof parameter per row.
-- Try asof = each of the last 12 month-ends and union the results

-- Approach: cross-join the as-of dates
-- Trick: Generate a set of month-end dates, CROSS JOIN them into the payment and installment sides, 
-- add asof to every GROUP BY. That turns a one-snapshot query into 12 independent snapshots in one pass.
WITH asofs AS (
    SELECT (DATE_TRUNC('month', CURRENT_DATE)
            - (i || ' month')::interval
            - interval '1 day')::date AS asof
    FROM generate_series(0, 11) AS g(i)          -- 12 month-ends, newest first
),
installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (                                        -- one row per (asof, loan)
    SELECT a.asof, p.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    CROSS JOIN asofs a
    WHERE p.status = 'completed'
      AND p.payment_date <= a.asof               -- the whole point
    GROUP BY a.asof, p.loan_id
),
tagged AS (
    SELECT
        a.asof, i.loan_id, i.due_date, i.total_due, i.cum_due,
        COALESCE(p.total_paid, 0) AS total_paid,
        CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
             THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    CROSS JOIN asofs a
    LEFT JOIN paid p ON p.asof = a.asof AND p.loan_id = i.loan_id
),
loan_state AS (
    SELECT
        t.asof,
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, t.asof - MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid' AND t.due_date < t.asof
        )) AS dpd
    FROM tagged t
    GROUP BY t.asof, t.loan_id
)
SELECT
    s.asof,
    COUNT(*)                                                          AS loan_count,
    ROUND(SUM(s.outstanding), 2)                                      AS total_outstanding,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)          AS par30_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 60), 2)          AS par60_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 90), 2)          AS par90_balance,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par30_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 60)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par60_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 90)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par90_pct
FROM loan_state s
JOIN loans l ON l.loan_id = s.loan_id
WHERE l.status = 'active'
  AND l.disbursement_date <= s.asof           -- loan must exist at snapshot
GROUP BY s.asof
ORDER BY s.asof;

-- Window functions: running totals, ranking, share
-- Rank borrowers; compute cumulative disbursements over time; show each loan's share of its product category.
-- Top 3 largest active loans per product category
WITH ranked AS (
    SELECT
        l.loan_id,
        p.category,
        l.principal,
        ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY l.principal DESC) AS rn
    FROM loans l 
	JOIN loan_products p USING (product_id)
    WHERE l.status = 'active'
)
SELECT * FROM ranked WHERE rn <= 3;

-- Monthly disbursement volume and running total
SELECT
    DATE_TRUNC('month', disbursement_date)::date AS month,
    COUNT(*)                                      AS loans,
    SUM(principal)                                AS disbursed,
    SUM(SUM(principal)) OVER (ORDER BY DATE_TRUNC('month', disbursement_date)) AS cumulative_disbursed
FROM loans
GROUP BY 1, disbursement_date -- Added 'disbursement_date' to the 'GROUP BY' as psql could not take the positional reference 1
ORDER BY 1;

-- Each loan's share of its category
SELECT
    l.loan_id,
    p.category,
    l.principal,
    ROUND(
		100.0 * l.principal / 
		SUM(l.principal) 
		OVER (PARTITION BY p.category)
		, 2) AS pct_of_category
FROM loans l 
JOIN loan_products p 
USING (product_id)
WHERE l.status = 'active'
ORDER BY 
	p.category, 
	pct_of_category DESC;

-- LAG(x) OVER (ORDER BY y) gives the previous row's value 
-- The classic way to compute month-over-month change:
SELECT
    month,
    disbursed,
    LAG(disbursed) OVER (ORDER BY month)              AS prev_month,
    ROUND(100.0 * (disbursed - LAG(disbursed) OVER (ORDER BY month))
                / NULLIF(LAG(disbursed) OVER (ORDER BY month), 0), 2) AS mom_pct_change
FROM (
    SELECT DATE_TRUNC('month', disbursement_date)::date AS month,
           SUM(principal) AS disbursed
    FROM loans GROUP BY 1
) m
ORDER BY month;

-- Top 10 borrowers by total principal borrowed
WITH borrower_totals AS (
    SELECT customer_id,
           COUNT(*)          AS loan_count,
           SUM(principal)    AS total_principal
    FROM   loans
    GROUP  BY customer_id
)
SELECT
    c.customer_id,
    c.full_name,
    COALESCE(c.region, 'unknown')                    AS region,
    bt.loan_count,
    bt.total_principal,
    RANK()       OVER (ORDER BY bt.total_principal DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY bt.total_principal DESC) AS dense_rnk
FROM borrower_totals bt
JOIN customers c ON c.customer_id = bt.customer_id
ORDER BY bt.total_principal DESC, c.customer_id
LIMIT 10;

-- Loans per customer, as a window count per loan
SELECT
    loan_id,
    customer_id,
    principal,
    disbursement_date,
    COUNT(*)         OVER (PARTITION BY customer_id) AS customer_loan_count,
    SUM(principal)   OVER (PARTITION BY customer_id) AS customer_total_principal
FROM loans
ORDER BY customer_id, disbursement_date;

--  Cumulative PAR30 by product category across months
WITH asofs AS (
    SELECT (DATE_TRUNC('month', CURRENT_DATE)
            - (i || ' month')::interval
            - interval '1 day')::date AS asof
    FROM generate_series(0, 11) AS g(i)
),
installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT a.asof, p.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    CROSS JOIN asofs a
    WHERE p.status = 'completed'
      AND p.payment_date <= a.asof
    GROUP BY a.asof, p.loan_id
),
tagged AS (
    SELECT
        a.asof, i.loan_id, i.due_date, i.total_due, i.cum_due,
        COALESCE(p.total_paid, 0) AS total_paid,
        CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
             THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    CROSS JOIN asofs a
    LEFT JOIN paid p ON p.asof = a.asof AND p.loan_id = i.loan_id
),
loan_state AS (
    SELECT
        t.asof,
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, t.asof - MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid' AND t.due_date < t.asof
        )) AS dpd
    FROM tagged t
    GROUP BY t.asof, t.loan_id
)
SELECT
    DATE_TRUNC('month', s.asof)::date                                 AS month,
    p.category,
    ROUND(SUM(s.outstanding), 2)                                      AS total_outstanding,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)          AS par30_balance,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par30_pct,
    ROUND(SUM(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30))
          OVER (PARTITION BY p.category
                ORDER BY DATE_TRUNC('month', s.asof)), 2)             AS cumulative_par30_balance
FROM loan_state s
JOIN loans         l ON l.loan_id    = s.loan_id
JOIN loan_products p ON p.product_id = l.product_id
WHERE l.status = 'active'
  AND l.disbursement_date <= s.asof
GROUP BY DATE_TRUNC('month', s.asof), p.category
ORDER BY p.category, month;

-- Number of loans ever been 30+ DPD as of each month" — a monotonic series that do not double count loans 30+ DPD
WITH asofs AS (
    SELECT (DATE_TRUNC('month', CURRENT_DATE)
            - (i || ' month')::interval
            - interval '1 day')::date AS asof
    FROM generate_series(0, 11) AS g(i)
),
installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT a.asof, p.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    CROSS JOIN asofs a
    WHERE p.status = 'completed'
      AND p.payment_date <= a.asof
    GROUP BY a.asof, p.loan_id
),
tagged AS (
    SELECT
        a.asof, i.loan_id, i.due_date, i.total_due, i.cum_due,
        COALESCE(p.total_paid, 0) AS total_paid,
        CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
             THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    CROSS JOIN asofs a
    LEFT JOIN paid p ON p.asof = a.asof AND p.loan_id = i.loan_id
),
loan_state AS (
    SELECT
        t.asof,
        t.loan_id,
        SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
        GREATEST(0, t.asof - MIN(t.due_date) FILTER (
            WHERE t.inst_status = 'unpaid' AND t.due_date < t.asof
        )) AS dpd
    FROM tagged t
    GROUP BY t.asof, t.loan_id
)
, flagged AS (
    SELECT
        s.*,
        BOOL_OR(s.dpd >= 30) OVER (PARTITION BY s.loan_id
                                   ORDER BY s.asof) AS ever_par30
    FROM loan_state s
)
SELECT
    DATE_TRUNC('month', f.asof)::date AS month,
    p.category,
    COUNT(*) FILTER (WHERE f.ever_par30)                    AS loans_ever_par30,
    ROUND(SUM(f.outstanding) FILTER (WHERE f.ever_par30), 2) AS ever_par30_balance
FROM flagged f
JOIN loans         l ON l.loan_id    = f.loan_id
JOIN loan_products p ON p.product_id = l.product_id
WHERE l.status = 'active' AND l.disbursement_date <= f.asof
GROUP BY DATE_TRUNC('month', f.asof), p.category
ORDER BY p.category, month;

-- VINTAGE ANALYSIS
-- Are newer vintages of loans performing worse than older ones? (If yes, credit policy has a problem.)
-- The idea: group loans by disbursement month (the "vintage"). Compute the % of that cohort that is currently in each DPD bucket.
-- Compare across vintages. A well-run lender shows stable or improving vintages; a deteriorating book shows the opposite.
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid FROM payments WHERE status='completed' GROUP BY loan_id
),
tagged AS (
    SELECT i.*, COALESCE(p.total_paid,0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid,0) >= i.cum_due THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT
        t.loan_id,
        GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
            WHERE t.inst_status='unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
    FROM tagged t GROUP BY t.loan_id
)
SELECT
    DATE_TRUNC('month', l.disbursement_date)::date              AS vintage,
    COUNT(*)                                                     AS loans,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd = 0) / COUNT(*), 2)            AS pct_current,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd BETWEEN 1 AND 30) / COUNT(*), 2) AS pct_1_30,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd BETWEEN 31 AND 90) / COUNT(*), 2) AS pct_31_90,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd > 90) / COUNT(*), 2)          AS pct_90_plus
FROM loans l
LEFT JOIN loan_state s USING (loan_id)
GROUP BY 1
ORDER BY 1;

-- Did credit standards slip?" across many vintages
-- DPD measured at age 6 months
WITH loan_asof AS (
    SELECT loan_id, disbursement_date,
           (disbursement_date + INTERVAL '6 months')::date AS asof
    FROM loans
),
installments AS (
    SELECT rs.loan_id, rs.installment_no, rs.due_date, rs.total_due,
           SUM(rs.total_due) OVER (PARTITION BY rs.loan_id ORDER BY rs.installment_no) AS cum_due
    FROM repayment_schedule rs
),
paid AS (
    SELECT la.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    JOIN loan_asof la ON la.loan_id = p.loan_id
    WHERE p.status = 'completed'
      AND p.payment_date <= la.asof
    GROUP BY la.loan_id
),
tagged AS (
    SELECT i.loan_id, i.due_date,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
                THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT t.loan_id,
           GREATEST(0, la.asof - MIN(t.due_date) FILTER (
               WHERE t.inst_status = 'unpaid' AND t.due_date < la.asof
           )) AS dpd_at_6m
    FROM tagged t
    JOIN loan_asof la USING (loan_id)
    GROUP BY t.loan_id, la.asof
)
SELECT
    DATE_TRUNC('month', l.disbursement_date)::date                                 AS vintage,
    COUNT(*)                                                                        AS loans,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd_at_6m = 0)               / COUNT(*), 2) AS pct_current,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd_at_6m BETWEEN 1  AND 30) / COUNT(*), 2) AS pct_1_30,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd_at_6m BETWEEN 31 AND 90) / COUNT(*), 2) AS pct_31_90,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd_at_6m > 90)              / COUNT(*), 2) AS pct_90_plus
FROM loans l
JOIN loan_state s USING (loan_id)
WHERE l.disbursement_date <= (CURRENT_DATE - INTERVAL '6 months')::date
GROUP BY 1
ORDER BY 1;

-- How is the current 6–9 month book performing?


WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT i.*, COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
                THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT t.loan_id,
           GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
               WHERE t.inst_status = 'unpaid' AND t.due_date < CURRENT_DATE
           )) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    DATE_TRUNC('month', l.disbursement_date)::date                       AS vintage,
    COUNT(*)                                                              AS loans,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd = 0)              / COUNT(*), 2) AS pct_current,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd BETWEEN 1  AND 30) / COUNT(*), 2) AS pct_1_30,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd BETWEEN 31 AND 90) / COUNT(*), 2) AS pct_31_90,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.dpd > 90)              / COUNT(*), 2) AS pct_90_plus
FROM loans l
JOIN loan_state s USING (loan_id)
WHERE l.disbursement_date BETWEEN (CURRENT_DATE - INTERVAL '9 months')::date
                              AND (CURRENT_DATE - INTERVAL '6 months')::date
GROUP BY 1
ORDER BY 1;


-- Roll rates
-- Of the loans that were "Current" last month, how many rolled into "1-30 DPD" this month
-- Roll rate requires two snapshots. In a real system, you'd have a daily (or month-end) snapshot table.
-- Let's build one from the data we already have — 12 month-end snapshots.

-- snapshot table.
DROP TABLE IF EXISTS loan_snapshot CASCADE;

CREATE TABLE loan_snapshot AS
WITH months AS (
    SELECT (CURRENT_DATE - (k || ' month')::interval)::date AS snap_date
    FROM generate_series(1, 12) k
),
installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
)
SELECT
    m.snap_date,
    i.loan_id,
    GREATEST(0, m.snap_date - MIN(i.due_date) FILTER (
        WHERE i.due_date < m.snap_date
          AND (SELECT COALESCE(SUM(p.amount),0) FROM payments p
               WHERE p.loan_id = i.loan_id AND p.payment_date <= m.snap_date) < i.cum_due
    ))::int AS dpd
FROM months m
CROSS JOIN installments i
GROUP BY m.snap_date, i.loan_id;

-- Roll rate matrix
WITH bucketed AS (
    SELECT
        snap_date,
        loan_id,
        CASE
            WHEN dpd = 0          THEN 'Current'
            WHEN dpd <= 30        THEN '1-30'
            WHEN dpd <= 60        THEN '31-60'
            WHEN dpd <= 90        THEN '61-90'
            ELSE '90+'
        END AS bucket
    FROM loan_snapshot
),
pairs AS (
    SELECT
        a.snap_date,
        a.loan_id,
        a.bucket AS from_bucket,
        b.bucket AS to_bucket
    FROM bucketed a
    JOIN bucketed b
      ON a.loan_id = b.loan_id
     AND b.snap_date = a.snap_date + INTERVAL '1 month'
)
SELECT
    from_bucket,
    COUNT(*) FILTER (WHERE to_bucket = 'Current') AS to_current,
    COUNT(*) FILTER (WHERE to_bucket = '1-30')    AS to_1_30,
    COUNT(*) FILTER (WHERE to_bucket = '31-60')   AS to_31_60,
    COUNT(*) FILTER (WHERE to_bucket = '61-90')   AS to_61_90,
    COUNT(*) FILTER (WHERE to_bucket = '90+')     AS to_90_plus
FROM pairs
GROUP BY from_bucket
ORDER BY CASE from_bucket
    WHEN 'Current' THEN 1 WHEN '1-30' THEN 2 WHEN '31-60' THEN 3
    WHEN '61-90' THEN 4 ELSE 5 END;


-- Compute the roll rate for each of the last six months (group by snap_date).
-- Chart the Current → 1-30 line over time. You now have a leading indicator you can show a board.
WITH asofs AS (
    SELECT (DATE_TRUNC('month', CURRENT_DATE)
            - (i || ' month')::interval
            - interval '1 day')::date AS snap_date
    FROM generate_series(0, 6) AS g(i)        -- 7 month-ends → 6 transitions
),
installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT a.snap_date, p.loan_id, SUM(p.amount) AS total_paid
    FROM payments p
    CROSS JOIN asofs a
    WHERE p.status = 'completed'
      AND p.payment_date <= a.snap_date
    GROUP BY a.snap_date, p.loan_id
),
tagged AS (
    SELECT a.snap_date, i.loan_id, i.due_date,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
                THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    CROSS JOIN asofs a
    LEFT JOIN paid p ON p.snap_date = a.snap_date AND p.loan_id = i.loan_id
),
loan_state AS (
    SELECT t.snap_date, t.loan_id,
           GREATEST(0, t.snap_date - MIN(t.due_date) FILTER (
               WHERE t.inst_status = 'unpaid' AND t.due_date < t.snap_date
           )) AS dpd
    FROM tagged t
    GROUP BY t.snap_date, t.loan_id
),
bucketed AS (
    SELECT l.loan_id, s.snap_date, s.dpd,
           CASE
               WHEN s.dpd = 0               THEN 'current'
               WHEN s.dpd BETWEEN 1 AND 30  THEN '1-30'
               WHEN s.dpd BETWEEN 31 AND 60 THEN '31-60'
               WHEN s.dpd BETWEEN 61 AND 90 THEN '61-90'
               ELSE                              '90+'
           END AS bucket
    FROM loan_state s
    JOIN loans l ON l.loan_id = s.loan_id
    WHERE l.disbursement_date <= s.snap_date     -- loan exists at snapshot
),
with_lag AS (
    SELECT loan_id, snap_date, bucket,
           LAG(snap_date) OVER (PARTITION BY loan_id ORDER BY snap_date) AS prev_snap,
           LAG(bucket)    OVER (PARTITION BY loan_id ORDER BY snap_date) AS prev_bucket
    FROM bucketed
),
transitions AS (
    SELECT snap_date        AS to_snap,
           prev_bucket     AS from_bucket,
           bucket          AS to_bucket
    FROM with_lag
    WHERE prev_snap IS NOT NULL
      AND DATE_TRUNC('month', snap_date)
          = DATE_TRUNC('month', prev_snap) + INTERVAL '1 month'   -- consecutive months only
)
SELECT
    to_snap                                                                    AS snap_date,
    COUNT(*) FILTER (WHERE from_bucket = 'current')                            AS current_loans,
    COUNT(*) FILTER (WHERE from_bucket = 'current' AND to_bucket = '1-30')     AS current_to_1_30,
    ROUND(100.0 * COUNT(*) FILTER (WHERE from_bucket = 'current' AND to_bucket = '1-30')
                 / NULLIF(COUNT(*) FILTER (WHERE from_bucket = 'current'), 0), 2)
                                                                               AS current_to_1_30_pct
FROM transitions
GROUP BY to_snap
ORDER BY to_snap;

--  Recursive CTE: build an amortization schedule from scratch
-- For a given loan, produce the correct amortization schedule — the one where the borrower pays the same PMT every month.

-- The classic PMT formula:
-- PMT = P × r × (1 + r)^n / ((1 + r)^n − 1)
-- Where P = principal, r = monthly rate (annual / 12 / 100), n = tenor.
WITH RECURSIVE t(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM t WHERE n < 5
)
SELECT * FROM t;

WITH RECURSIVE amort AS (
    -- seed: first installment
    SELECT
        1 AS installment_no,
        l.loan_id,
        l.principal                                   AS opening_balance,
        l.annual_rate/12.0/100                        AS monthly_rate,
        round(
            l.principal * (l.annual_rate/12.0/100)
              * power(1 + l.annual_rate/12.0/100, l.tenor_months)
              / (power(1 + l.annual_rate/12.0/100, l.tenor_months) - 1),
            2
        )                                             AS pmt,
        l.tenor_months,
        round(l.principal * (l.annual_rate/12.0/100), 2) AS interest,
        round(
            round(
                l.principal * (l.annual_rate/12.0/100)
                  * power(1 + l.annual_rate/12.0/100, l.tenor_months)
                  / (power(1 + l.annual_rate/12.0/100, l.tenor_months) - 1),
                2
            ) - round(l.principal * (l.annual_rate/12.0/100), 2),
            2
        )                                             AS principal_paid
    FROM loans l WHERE l.loan_id = 1

    UNION ALL

    SELECT
        a.installment_no + 1,
        a.loan_id,
        a.opening_balance - a.principal_paid          AS opening_balance,
        a.monthly_rate,
        a.pmt,
        a.tenor_months,
        round((a.opening_balance - a.principal_paid) * a.monthly_rate, 2),
        round(a.pmt - round((a.opening_balance - a.principal_paid) * a.monthly_rate, 2), 2)
    FROM amort a
    WHERE a.installment_no < a.tenor_months
)
SELECT * FROM amort ORDER BY installment_no;

-- Parameterise the loan: replace WHERE l.loan_id = 1 with :loan_id — in psql, :loan_id requires \set, or just hardcode.
\set loan_id 1

WITH RECURSIVE
loan_params AS (
    SELECT loan_id, principal, tenor_months,
           annual_rate::numeric / 12 / 100 AS r
    FROM loans
    WHERE loan_id = :loan_id          -- or = 1
),
growth AS (
    SELECT loan_id, principal, tenor_months, r,
           POWER(1 + r, tenor_months) AS g
    FROM loan_params
),
first_payment AS (
    SELECT loan_id, tenor_months, r AS monthly_rate,
           principal::numeric AS opening_balance,
           ROUND(principal * r * g / NULLIF(g - 1, 0), 2) AS pmt
    FROM growth
),
schedule AS (
    SELECT
        1 AS n, loan_id, tenor_months, monthly_rate, pmt, opening_balance,
        ROUND(opening_balance * monthly_rate, 2)                    AS interest,
        ROUND(pmt - ROUND(opening_balance * monthly_rate, 2), 2)    AS principal_paid
    FROM first_payment

    UNION ALL

    SELECT
        s.n + 1, s.loan_id, s.tenor_months, s.monthly_rate, s.pmt,
        s.opening_balance - s.principal_paid,
        ROUND((s.opening_balance - s.principal_paid) * s.monthly_rate, 2),
        ROUND(s.pmt - ROUND((s.opening_balance - s.principal_paid) * s.monthly_rate, 2), 2)
    FROM schedule s
    WHERE s.n < s.tenor_months
),
schedule_clean AS (
    -- last row clears the residual; every other row keeps the annuity payment
    SELECT
        n, tenor_months,
        ROUND(opening_balance, 2) AS opening_balance,
        interest,
        CASE WHEN n = tenor_months
             THEN ROUND(opening_balance, 2)
             ELSE principal_paid
        END AS principal_paid
    FROM schedule
)
SELECT
    n                                                                 AS installment_no,
    opening_balance,
    interest,
    principal_paid,
    ROUND(opening_balance - principal_paid, 2)                        AS closing_balance,
    ROUND(interest + principal_paid, 2)                               AS payment,
    SUM(principal_paid) OVER (ORDER BY n)                             AS cum_principal,
    SUM(interest)       OVER (ORDER BY n)                             AS cum_interest
FROM schedule_clean
ORDER BY n;


-- Add closing_balance = opening_balance - principal_paid to each row. The final row's closing balance should be ~0.
WITH params AS (
    SELECT loan_id, principal::numeric AS p, tenor_months AS n,
           annual_rate::numeric / 12 / 100 AS r
    FROM loans WHERE loan_id = :loan_id
),
inst AS (
    SELECT g.i, p.p, p.n AS tenor, p.r
    FROM params p
    CROSS JOIN generate_series(1, p.n) AS g(i)
)
SELECT
    i.i                                                              AS installment_no,
    ROUND(i.p - (i.i - 1) * (i.p / i.tenor), 2)                      AS opening_balance,
    ROUND(i.p / i.tenor, 2)                                          AS principal_paid,
    ROUND((i.p - (i.i - 1) * (i.p / i.tenor)) * i.r, 2)              AS interest,
    ROUND(i.p / i.tenor
          + (i.p - (i.i - 1) * (i.p / i.tenor)) * i.r, 2)            AS payment,
    ROUND(i.p - i.i * (i.p / i.tenor), 2)                            AS closing_balance
FROM inst i
ORDER BY i.i;


/*
 Side-by-side comparison
For a concrete loan — P = 100,000, annual_rate = 12% (r = 1%/month), tenor = 12 — the two schedules differ like this:

								Equal-payment (annuity)			Equal-principal
Monthly payment					8,884.88 constant				9,333.33 → 8,416.67 declining
Period 1: interest				1,000.00						1,000.00
Period 1: principal				7,884.88						8,333.33
Period 1 interest share			11.25%							10.71%
Period 12: interest				≈ 87.98							83.33
Total interest					≈ 6,618.56						6,500.00
Principal retired by month 6	~62%							~50%

Which one front-loads interest? Equal-payment. Two reinforcing effects:

The early payments are disproportionately interest. In the first period both schedules pay the same dollar interest (1,000 — same opening balance), but equal-payment's total payment is smaller, so a larger fraction of it goes to interest. The gap widens every month because equal-payment's balance declines slower.

The average balance is higher, so total interest is higher. Equal-payment barely dents principal in the early months (7,885 of an 8,885 payment), so the balance — and therefore the interest accruing on it — stays elevated for longer. Equal-principal retires principal linearly and fast, which starves the interest line. Same nominal rate, but ~118 more dollars of interest over 12 months for equal-payment; the gap widens with tenor and rate.

The mirror image: equal-principal front-loads principal repayment — every payment carries the same principal, so the balance collapses quickly and interest declines sharply.

4. Why most lenders use equal-payment
Four reasons, in rough order of importance:

1. Affordability / payment-to-income. A constant payment matches the flat-or-slowly-rising income of most borrowers. Equal-principal front-loads payments — the borrower's highest payment is in month 1, when they've just paid a down payment and are most cash-strapped. Equal-payment's lower initial payment (8,885 vs 9,333 in the example) means more borrowers qualify and fewer default early in the loan.

2. Lower quoted payment = easier to sell. Borrowers shop on the headline monthly payment, not the total interest. A lower first-payment figure is more competitive in the market, even though it costs more in total. This is a straightforward marketing and competition effect.

3. Higher total interest = higher lender revenue. Same nominal rate, ~2% more interest dollars over the life of a 12-month loan at 12% — and the gap grows substantially with tenor. For a 30-year mortgage the difference is tens of thousands of dollars per loan. Lenders have a direct financial incentive to prefer the schedule that accrues more.

4. Standardisation. Fixed-payment amortisation is the basis for mortgage-backed securities, agency underwriting (Fannie/Freddie), servicing systems, and most disclosure regimes. A declining payment schedule breaks pooling and securitisation — you can't easily tranche cash flows that shrink every month. Equal-principal is common in project finance, equipment leasing, and some commercial lending where the borrower's cash flow is itself declining, but it's a niche in retail.

The corollary worth flagging for a board: "same rate" does not mean "same cost." The nominal rate is identical between the two schedules; the total interest differs because the amortisation path differs. If you quote equal-payment to a customer and the competitor quotes equal-principal at the same rate, the competitor's loan is genuinely cheaper in total dollars — the equal-payment loan only wins on the monthly payment. That's the trade-off the borrower is actually making, and it's usually invisible to them unless the disclosure shows total interest.
*/


-- Views and materialized views: build the reporting layer
-- Turn the monster DPD query into a "table" anyone can SELECT from?

-- Reusable view of the current DPD for every loan
CREATE OR REPLACE VIEW v_loan_dpd AS
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid FROM payments WHERE status='completed' GROUP BY loan_id
),
tagged AS (
    SELECT i.*, COALESCE(p.total_paid,0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid,0) >= i.cum_due THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i LEFT JOIN paid p USING (loan_id)
)
SELECT
    t.loan_id,
    SUM(t.total_due) - MAX(t.total_paid)                              AS outstanding,
    GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
        WHERE t.inst_status='unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
FROM tagged t
GROUP BY t.loan_id;

-- Now queries get trivially simple:
SELECT 
	l.status, 
	COUNT(*), 
	ROUND(AVG(d.dpd), 1) AS avg_dpd
FROM loans l 
JOIN v_loan_dpd d 
USING (loan_id)
GROUP BY l.status;

/*
Views are just saved queries. 
They don't store data — they run every time you SELECT them. 
Great for correctness (one source of truth), bad for speed if they're heavy and used by dashboards.

Materialized views store the result on disk:
*/

CREATE MATERIALIZED VIEW mv_loan_dpd AS
SELECT * FROM v_loan_dpd;

CREATE UNIQUE INDEX ON mv_loan_dpd (loan_id);

-- Refresh (recompute) when the underlying data changes:
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_loan_dpd;

/*
CONCURRENTLY allows reads during refresh — requires a unique index.

You must remember to refresh. A stale dashboard is worse than no dashboard. 
In production this is scheduled (cron, Airflow, pg_cron).
*/

-- MATERIALIZED VIEW: mv_portfolio_par returning PAR30/60/90 by product. Refresh it and query it.
BEGIN;

DROP MATERIALIZED VIEW IF EXISTS mv_portfolio_par;

CREATE MATERIALIZED VIEW mv_portfolio_par AS
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT i.loan_id, i.due_date, i.total_due,
           COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
                THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT t.loan_id,
           SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
           GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
               WHERE t.inst_status = 'unpaid' AND t.due_date < CURRENT_DATE
           )) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    p.category,
    COUNT(*)                                                          AS loan_count,
    ROUND(SUM(s.outstanding), 2)                                      AS total_outstanding,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)          AS par30_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 60), 2)          AS par60_balance,
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 90), 2)          AS par90_balance,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par30_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 60)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par60_pct,
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 90)
               / NULLIF(SUM(s.outstanding), 0), 2)                    AS par90_pct,
    CURRENT_DATE                                                       AS snapshot_date
FROM loan_state s
JOIN loans         l ON l.loan_id    = s.loan_id
JOIN loan_products p ON p.product_id = l.product_id
WHERE l.status = 'active'
GROUP BY p.category
WITH DATA;

-- Unique index for CONCURRENTLY refresh — required if you want to refresh without locking readers:
CREATE UNIQUE INDEX mv_portfolio_par_category_uidx ON mv_portfolio_par (category);

COMMIT;
-- Refresh and query:
-- Fast, blocks readers momentarily:
REFRESH MATERIALIZED VIEW mv_portfolio_par;

-- Or, with the unique index above, non-blocking:
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_portfolio_par;

SELECT * FROM mv_portfolio_par ORDER BY par30_pct DESC NULLS LAST;

-- Plain view: v_customer_summary
CREATE VIEW v_customer_summary AS
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
    GROUP BY loan_id
),
tagged AS (
    SELECT i.loan_id, i.total_due,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
                THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_outstanding AS (
    SELECT t.loan_id,
           SUM(t.total_due) - MAX(COALESCE(p.total_paid, 0)) AS outstanding
    FROM tagged t
    LEFT JOIN paid p USING (loan_id)
    GROUP BY t.loan_id
),
per_customer AS (
    SELECT
        l.customer_id,
        COUNT(*)                                AS loan_count,
        SUM(l.principal)                        AS total_principal,
        SUM(COALESCE(o.outstanding, 0))         AS total_outstanding
    FROM loans l
    LEFT JOIN loan_outstanding o ON o.loan_id = l.loan_id
    GROUP BY l.customer_id
)
SELECT
    c.customer_id,
    c.full_name,
    c.region,
    COALESCE(pc.loan_count, 0)          AS loan_count,
    COALESCE(pc.total_principal, 0)     AS total_principal,
    COALESCE(pc.total_outstanding, 0)   AS total_outstanding
FROM customers c
LEFT JOIN per_customer pc ON pc.customer_id = c.customer_id;

-- Query it
SELECT *
FROM   v_customer_summary
WHERE  total_outstanding > 100000
ORDER  BY total_outstanding DESC;

--  Indexes and EXPLAIN: make it fast
-- My dashboard takes 45 seconds. How do I make it 2 seconds?
EXPLAIN ANALYZE
SELECT * FROM loans WHERE customer_id = 42;

-- Seq Scan = Postgres read the whole table. Fine for 1,800 rows; terrible for 18 million. Add an index:
CREATE INDEX idx_loans_customer ON loans (customer_id);
EXPLAIN ANALYZE SELECT * FROM loans WHERE customer_id = 42;



/*
EXPLAIN ANALYZE the PAR query from Sprint 8. Which step takes the most time?

Add indexes on payments.loan_id and repayment_schedule.loan_id. Rerun. How much faster?

Try CREATE INDEX idx_test ON payments (payment_date); then EXPLAIN ANALYZE a query filtering by payment_date. Then DROP INDEX idx_test. What changed?

I can't run these against your database, so I can't give you the actual millisecond numbers — those depend entirely on your row counts and hardware. What I *can* do is give you the exact commands, tell you which node to look at in the output, and give you the honest expected outcome for each experiment (including the cases where the index does **nothing**, which is common and worth knowing).

## Experiment 1 — baseline EXPLAIN ANALYZE

`EXPLAIN ANALYZE` can't wrap a `CREATE MATERIALIZED VIEW`, so run it on the inner `SELECT`:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments WHERE status = 'completed' GROUP BY loan_id
),
tagged AS (
    SELECT i.loan_id, i.due_date, i.total_due,
           COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT t.loan_id,
           SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
           GREATEST(0, CURRENT_DATE - MIN(t.due_date) FILTER (
               WHERE t.inst_status = 'unpaid' AND t.due_date < CURRENT_DATE)) AS dpd
    FROM tagged t GROUP BY t.loan_id
)
SELECT p.category, COUNT(*), ROUND(SUM(s.outstanding), 2),
       ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2)
FROM loan_state s
JOIN loans l ON l.loan_id = s.loan_id
JOIN loan_products p ON p.product_id = l.product_id
WHERE l.status = 'active'
GROUP BY p.category;
```

**How to read it — which step dominates:**

- Look at the **`actual time`** on each node, but multiply by **`loops`** — a node with `actual time=0.5..2.0` and `loops=10000` costs 20,000 ms total, not 2 ms. The dominant node is the one whose `actual time × loops` is largest.
- The **topmost node's `actual time`** is the total wall time; the second number (`..X`) includes children.
- **`BUFFERS`** — a node with high `shared read` (not `hit`) is disk-bound. That's the one to attack with an index.

**What the plan will almost certainly show, and the real bottleneck:**

1. **`Sort` for the window function** — `SUM(...) OVER (PARTITION BY loan_id ORDER BY installment_no)` forces a sort of the *entire* `repayment_schedule` by `(loan_id, installment_no)` unless the planner can get that order from an index. This is O(n log n) over every installment in the book, and it is very often **the single most expensive node**, more than any join.
2. **`Hash Left Join` / `HashAggregate`** for the `paid` CTE and the `tagged → loan_state` collapse — cost scales with the join's row count.
3. **`Seq Scan on repayment_schedule`** — feeding the sort.

Note on CTEs: PostgreSQL 12+ **inlines** non-recursive CTEs that are referenced once (all of yours are), so you'll see one merged plan, not `CTE Scan` nodes. If you're on ≤11, you'll see `CTE Scan` and the CTE is an optimization fence — a completely different plan shape.

## Experiment 2 — add `loan_id` indexes

**Before creating anything, check whether they already exist.** FK columns are frequently indexed already, and a duplicate index costs writes and buys nothing:

```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('payments','repayment_schedule')
ORDER BY tablename, indexname;

SELECT relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE relname IN ('payments','repayment_schedule');
```

`idx_scan = 0` on an existing index means it's dead weight — don't add another.

If absent:

```sql
CREATE INDEX CONCURRENTLY idx_payments_loan_id       ON payments (loan_id);
CREATE INDEX CONCURRENTLY idx_repayment_sched_loan_id ON repayment_schedule (loan_id);
```

**Honest expected result: probably close to zero, and here's why.**

- The joins in this query are `installments LEFT JOIN paid USING (loan_id)`. That's a hash join or merge join, not an index lookup — a hash join doesn't use a `loan_id` index on the build side at all. The planner will still prefer a hash join over a nested-loop-with-index for a whole-table aggregation.
- `repayment_schedule.loan_id` is almost certainly already indexed (PK/unique on `(loan_id, installment_no)` or an FK index). The new index is redundant; Postgres will *not* use it and you'll see no change — `EXPLAIN` will show the same plan.

**The index that actually helps this query** is one that kills the window Sort by providing the required order:

```sql
CREATE INDEX CONCURRENTLY idx_rs_loan_inst_cover
    ON repayment_schedule (loan_id, installment_no) INCLUDE (due_date, total_due);
```

With that, the planner can do an **Index Only Scan** in `(loan_id, installment_no)` order and feed the window function directly — the `Sort` node disappears from the plan entirely. That's typically a **2–10× win on the installments side** of a large book; the plain `loan_id` indexes give you nothing.

So the accurate answer to "how much faster?" is: **plain `loan_id` indexes: likely 0% (or a regression from write overhead). The covering composite index: the real win.** I can't put a number on it without your `EXPLAIN` output — run both and compare the `Sort` node's cost before/after.

## Experiment 3 — `payment_date` index, then drop it

```sql
CREATE INDEX CONCURRENTLY idx_test ON payments (payment_date);

-- query A: narrow window (selective) — index should win
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM payments
WHERE payment_date BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE;

-- query B: whole table (non-selective) — seq scan should win, index ignored
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount) FROM payments WHERE payment_date IS NOT NULL;

DROP INDEX idx_test;
```

**What changed, and the two lessons:**

- **Query A on a large table:** plan flips from `Seq Scan` to `Index Scan` (or `Bitmap Index Scan → Bitmap Heap Scan`), time drops — the index earns its keep because it reads ~1 month of rows instead of the whole table.
- **Query A on a small table:** plan **stays `Seq Scan`**. The planner computes that random I/O to follow the index costs more than reading a small table sequentially, and it's right. This is the most common surprise: "I added an index and nothing changed" almost always means the table is small enough that seq scan is cheaper.
- **Query B regardless of size:** plan stays `Seq Scan`, because reading a large fraction of the table via index is *slower* than a sequential read (random I/O vs streaming). The index is simply not the right access path.
- **After `DROP INDEX`:** the plan reverts to exactly what it was before `CREATE` — `Seq Scan` for both. Nothing is cached; the planner re-decides on every query.

Also note: `CREATE INDEX` (non-concurrent) takes an `ACCESS EXCLUSIVE` lock and blocks writes on `payments` for the duration. Use `CONCURRENTLY` on anything live — it's slower to build and can fail leaving an invalid index (`pg_index.indisvalid = false`), which you'd then `DROP INDEX CONCURRENTLY` and retry.

## How to report "how much faster"

You can't get a number from me — you get it from the pair of plans. The defensible method:

```sql
-- run 3× each, take the median "Execution Time"
EXPLAIN (ANALYZE, BUFFERS) <query>;   -- before indexes
-- create indexes
EXPLAIN (ANALYZE, BUFFERS) <query>;   -- after
```

Compare **`Execution Time:`** on the last line, and confirm the plan actually *changed* (if the plan is identical, the "speedup" is noise — run 3 times to see the variance). A benchmark that doesn't change the plan shape is measuring cache warmth, not indexing.

**The likely headline for your write-up:** "The dominant cost was the window-function `Sort` on `repayment_schedule`, not the joins. `loan_id` indexes were redundant with existing FK indexes and gave no measurable change. A covering `(loan_id, installment_no) INCLUDE (due_date, total_due)` index removed the sort and is the optimization worth keeping." That's a more useful finding than a percentage, and it's the one your `EXPLAIN` output will support.
*/


--  Functions and triggers
-- Can the database itself enforce business rules?
-- A useful function: compute DPD for a single loan — reusable in reports.

CREATE OR REPLACE FUNCTION fn_dpd(p_loan_id INT, p_asof DATE DEFAULT CURRENT_DATE)
RETURNS INT LANGUAGE SQL AS 
$$
    WITH installments AS (
        SELECT installment_no, due_date, total_due,
               SUM(total_due) OVER (ORDER BY installment_no) AS cum_due
        FROM repayment_schedule WHERE loan_id = p_loan_id
    ),
    paid AS (
        SELECT COALESCE(SUM(amount), 0) AS total_paid FROM payments
        WHERE loan_id = p_loan_id AND status='completed' AND payment_date <= p_asof
    )
    SELECT COALESCE(GREATEST(0, p_asof - MIN(due_date) FILTER (
        WHERE due_date < p_asof AND (SELECT total_paid FROM paid) < cum_due)), 0)::int
    FROM installments
$$;

-- Use it anywhere:
SELECT loan_id, fn_dpd(loan_id) AS dpd FROM loans WHERE status='active' LIMIT 10;

-- A trigger: enforce that every payment must be positive.
CREATE OR REPLACE FUNCTION trg_payment_positive() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be positive (got %)', NEW.amount;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_payment_positive
    BEFORE INSERT OR UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION trg_payment_positive();

INSERT INTO payments (loan_id, payment_date, amount) VALUES (1, CURRENT_DATE, -50);
-- fails with a clear error. The database enforces the rule, not the application code. That's the correct place for it — any app (web, mobile, batch) obeys it.

--Trigger: auto-set payments.status from amount
-- Sets payments.status = 'completed' when the amount > 0 and leaves it 'pending' otherwise
CREATE OR REPLACE FUNCTION trg_set_payment_status() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount > 0 THEN
        NEW.status := 'completed';
    ELSE
        NEW.status := 'pending';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payments_set_status
BEFORE INSERT OR UPDATE OF amount ON payments
FOR EACH ROW
EXECUTE FUNCTION trg_set_payment_status();

-- Function: fn_portfolio_par(p_asof DATE) that returns PAR30, PAR60, PAR90 as a record
CREATE OR REPLACE FUNCTION fn_portfolio_par(p_asof DATE)
RETURNS TABLE (
    par30_balance NUMERIC,
    par60_balance NUMERIC,
    par90_balance NUMERIC,
    par30_pct     NUMERIC,
    par60_pct     NUMERIC,
    par90_pct     NUMERIC
)
LANGUAGE sql STABLE AS $$
WITH installments AS (
    SELECT loan_id, installment_no, due_date, total_due,
           SUM(total_due) OVER (PARTITION BY loan_id ORDER BY installment_no) AS cum_due
    FROM repayment_schedule
),
paid AS (
    SELECT loan_id, SUM(amount) AS total_paid
    FROM payments
    WHERE status = 'completed'
      AND payment_date <= p_asof          -- point-in-time snapshot
    GROUP BY loan_id
),
tagged AS (
    SELECT i.loan_id, i.due_date, i.total_due,
           COALESCE(p.total_paid, 0) AS total_paid,
           CASE WHEN COALESCE(p.total_paid, 0) >= i.cum_due
                THEN 'paid' ELSE 'unpaid' END AS inst_status
    FROM installments i
    LEFT JOIN paid p USING (loan_id)
),
loan_state AS (
    SELECT t.loan_id,
           SUM(t.total_due) - MAX(t.total_paid) AS outstanding,
           GREATEST(0, p_asof - MIN(t.due_date) FILTER (
               WHERE t.inst_status = 'unpaid' AND t.due_date < p_asof
           )) AS dpd
    FROM tagged t
    GROUP BY t.loan_id
)
SELECT
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 30), 2),
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 60), 2),
    ROUND(SUM(s.outstanding) FILTER (WHERE s.dpd >= 90), 2),
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 30)
               / NULLIF(SUM(s.outstanding), 0), 2),
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 60)
               / NULLIF(SUM(s.outstanding), 0), 2),
    ROUND(100.0 * SUM(s.outstanding) FILTER (WHERE s.dpd >= 90)
               / NULLIF(SUM(s.outstanding), 0), 2)
FROM loan_state s
JOIN loans l ON l.loan_id = s.loan_id
WHERE l.status = 'active'
  AND l.disbursement_date <= p_asof;      -- loan must exist at snapshot
$$;

-- Call for the last 12 month-ends
SELECT
    m.asof,
    fp.par30_balance,
    fp.par60_balance,
    fp.par90_balance,
    fp.par30_pct,
    fp.par60_pct,
    fp.par90_pct
FROM (
    SELECT (DATE_TRUNC('month', CURRENT_DATE)
            - (i || ' month')::interval
            - interval '1 day')::date AS asof
    FROM generate_series(0, 11) AS g(i)
) m
CROSS JOIN LATERAL fn_portfolio_par(m.asof) fp
ORDER BY m.asof;


-- Roles and security
-- Stop the collections team from seeing the CFO's data and vice versa?
-- Create roles
CREATE ROLE analyst;
CREATE ROLE collections_agent;

-- Analysts see aggregated views, not raw PII
GRANT SELECT ON v_loan_dpd TO analyst;
GRANT SELECT ON mv_portfolio_par TO analyst;
GRANT SELECT (loan_id, customer_id, principal, disbursement_date) ON loans TO analyst;
-- NOTE: no grant on `payments` or `customers.full_name` / `monthly_income`.

-- Collections agents can see the loans, payments, and customers they need
GRANT SELECT, INSERT ON collections_actions TO collections_agent;
GRANT SELECT ON loans TO collections_agent;
GRANT SELECT ON customers TO collections_agent;


-- Row-level security (RLS) 
-- Postgres's way of filtering per user, at the row level.
-- Scenario: an agent in Nairobi should only see Nairobi customers.
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY agent_sees_only_own_region ON customers
    FOR SELECT
    TO collections_agent
    USING (region = current_setting('app.agent_region', true));
-- Now unless app.agent_region is set (by the app when connecting), collections_agent sees nothing. You set it per session:

SET app.agent_region = 'Nairobi';
SELECT * FROM customers;  -- only Nairobi rows

/* 
Why this matters. 
In a production lender, "who can see what" is a regulator-level question. 
GDPR and Kenya's Data Protection Act both require least-privilege access to PII. 
Analysts often see aggregated data only. 
Collections sees contact data but not salaries. 
RLS is how you enforce this in the database, not in the app
*/


-- Full role matrix for CreditBook
/*
# CreditBook role matrix

## The matrix

Legend: 
	**R** read 
	**W** write (INSERT/UPDATE/DELETE)
	**R\*** read, column-restricted
	**X** execute function
	**—** no access
	**RLS** filtered by row-level security

| Object / capability 								| analyst | risk_officer | collections_agent | cfo  |
|---												|---	  |---			 |---				 |---	|
| `customers.name`, `customers.phone` 				| — 	  | R 			 | R 				 | R 	|
| `customers.region`, `customers.customer_id` 		| R\* 	  | R 			 | R 				 | R 	|
| `loans` (structure: principal, rate, dates) 		| R 	  | R 			 | R (RLS) 			 | R 	|
| `loans.status` 									| R 	  | R + W 		 | R (RLS) 			 | R 	|
| `loan_applications.decision` 						| R 	  | R + W 		 | — 				 | R 	|
| `loan_products` 									| R 	  | R 			 | R 				 | R 	|
| `repayment_schedule` 								| R 	  | R 			 | R 				 | R 	|
| `payments` 										| R 	  | R 			 | R + INSERT 		 | R 	|
| `payments.status` 								| R 	  | R 			 | — 				 | R 	|
| `mv_portfolio_par` 								| R 	  | R 			 | — 				 | R 	|
| `v_customer_summary` 								| — 	  | R 			 | — 				 | R 	|
| `fn_portfolio_par(date)` 							| X 	  | X 		 	 | — 				 | X 	|
| DDL (CREATE/ALTER/DROP) 							| — 	  | — 			 | — 				 | — 	|
| TRUNCATE 											| — 	  | — 			 | — 				 | — 	|

**The load-bearing decisions:**

- **Analyst gets no PII.** 
		They see `customer_id` and `region` but not `name` or `phone`. 
		Aggregations by region work; drilling to a person doesn't. 
		This is the standard least-privilege posture for analysts running ad-hoc queries — 
		the moment PII is in scope, every dashboard export becomes a data-protection incident.
- **Risk officerc an only write one column: `loan_applications.decision`.** 
		Not `loans`, not `payments`. The approve/reject decision is their job; 
		everything downstream (disbursement, payment capture) belongs to other systems. 
		Segregation of duties.
- **Collections gets INSERT on `payments`, not UPDATE.** 
		They record money received; they can't rewrite history. 
		Combined with the trigger from the previous turn (`amount > 0 → status = 'completed'`), 
		they physically cannot mark a $0 payment as completed or flip a completed payment to pending.
- **CFO reads everything, writes nothing.** 
		Oversight role. If the CFO can write, they can fabricate the numbers they're reporting — 
		segregation of duties, again.
- **No role has DDL.** Schema changes go through migrations run by a separate deploy role. 
No role has `TRUNCATE` — that's a `DELETE` on steroids and has no place in application access.
*/

-- SETUP
-- 1. Group roles (NOLOGIN). Real users are members.
CREATE ROLE creditbook_analyst       NOLOGIN;
CREATE ROLE creditbook_risk_officer  NOLOGIN;
CREATE ROLE creditbook_collections   NOLOGIN;
CREATE ROLE creditbook_cfo           NOLOGIN;

-- 2. Schema hygiene: revoke the default PUBLIC grants.
--    In PG15+ CREATE on public is already revoked, but USAGE and function EXECUTE are not.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public
  TO creditbook_analyst, creditbook_risk_officer,
     creditbook_collections, creditbook_cfo;

--The function `REVOKE` is the one people forget: 
--PostgreSQL grants `EXECUTE` on new functions to `PUBLIC` by default.
-- This means `fn_portfolio_par` is callable by anyone who can connect until you revoke.

-- ## GRANTS PER ROLE

-- ### analyst
GRANT SELECT ON
    loans,
    loan_products,
    repayment_schedule,
    payments
  TO creditbook_analyst;

-- customers: column-level, PII excluded
GRANT SELECT (customer_id, region) ON customers TO creditbook_analyst;

GRANT SELECT ON mv_portfolio_par TO creditbook_analyst;
GRANT EXECUTE ON FUNCTION fn_portfolio_par(DATE) TO creditbook_analyst;


-- No `v_customer_summary` — it projects `name`, which the analyst isn't allowed to see. 
-- If analysts need per-customer aggregates, build `v_customer_summary_masked` 
-- (`customer_id` in place of `name`) and grant that.

-- ### risk_officer
-- inherits all analyst read
GRANT creditbook_analyst TO creditbook_risk_officer;

-- PII and full customer view
GRANT SELECT ON customers TO creditbook_risk_officer;
GRANT SELECT ON v_customer_summary TO creditbook_risk_officer;

-- loan application decisions only
GRANT SELECT ON loan_applications TO creditbook_risk_officer;
GRANT UPDATE (decision) ON loan_applications TO creditbook_risk_officer;

-- loan status transitions (current → delinquent → defaulted, etc.)
GRANT UPDATE (status) ON loans TO creditbook_risk_officer;

-- Column-level `UPDATE` is the key move here: 
-- `GRANT UPDATE (decision)` lets the risk officer change the decision without being able to touch `principal`, `rate`, or `disbursement_date`. 
-- In PostgreSQL this is a real restriction, not advisory — `UPDATE loan_applications SET principal = 0` fails for this role.

-- ### collections_agent
GRANT SELECT ON
    loans,
    loan_products,
    repayment_schedule,
    payments
  TO creditbook_collections;

-- customer contact info: name and phone are the whole point of the role
GRANT SELECT (customer_id, full_name, phone, region) ON customers TO creditbook_collections;

-- record payments received; the trigger enforces status
GRANT INSERT ON payments TO creditbook_collections;

-- sequence usage for the serial/identity PK on payments
GRANT USAGE, SELECT ON SEQUENCE payments_payment_id_seq TO creditbook_collections;

-- Note: 
-- **no `UPDATE` on `payments`** and **no `DELETE`** 
-- The agent records a payment once; corrections go through a separate reconciliation process with its own audit trail.
-- Also **no `UPDATE (status)` on `loans`** — collections observes delinquency, doesn't adjudicate it.

-- ### CFO
GRANT creditbook_analyst TO creditbook_cfo;          -- read everything analyst sees
GRANT SELECT ON customers TO creditbook_cfo;          -- full PII, oversight needs it
GRANT SELECT ON v_customer_summary TO creditbook_cfo;
GRANT SELECT ON mv_portfolio_par TO creditbook_cfo;
GRANT EXECUTE ON FUNCTION fn_portfolio_par(DATE) TO creditbook_cfo;

-- `GRANT creditbook_analyst TO creditbook_cfo` makes the CFO role a superset of analyst. 
-- If you later narrow analyst's grants, CFO narrows automatically — one grant to update, not two.

-- ## Row-level security for collections

-- Column grants stop the agent seeing `principal`, but they don't stop them *querying* every loan in the book. 
-- If the intent is "collections works the overdue list, not the whole portfolio," add RLS:

ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

CREATE POLICY collections_overdue_only ON loans
    FOR SELECT
    TO creditbook_collections
    USING (status IN ('delinquent', 'defaulted'));

-- **Caveat:** RLS on `loans` alone is porous. 
-- `payments`, `repayment_schedule`, and `customers` still leak.
-- The agent can join to see any customer who has ever been delinquent, or infer the full book from `payments`.
-- A correct implementation applies RLS to every table reachable from `loans`, 
-- or fronts the whole thing with a `SECURITY DEFINER` view (`v_collections_worklist`) 
-- that joins through only the overdue set and grants no direct table access at all. 
-- The view approach is simpler and more auditable:

CREATE VIEW v_collections_worklist
  WITH (security_barrier = true) AS
SELECT l.loan_id, l.customer_id, c.full_name, c.phone, c.region,
       rs.installment_no, rs.due_date, rs.total_due,
       CURRENT_DATE - rs.due_date AS dpd
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
JOIN repayment_schedule rs ON rs.loan_id = l.loan_id
WHERE l.status IN ('delinquent', 'defaulted')
  AND rs.due_date < CURRENT_DATE;

REVOKE SELECT ON loans, customers, repayment_schedule FROM creditbook_collections;
GRANT  SELECT ON v_collections_worklist TO creditbook_collections;

-- `security_barrier = true` prevents the planner from pushing user-supplied predicates below the view's `WHERE`, 
-- which is what stops `SELECT * FROM v_collections_worklist WHERE customer_id = 999` from bypassing the filter on a row it shouldn't see.

-- ## Default privileges for future objects

-- Tables created tomorrow inherit nothing by default. 
--Wire it up *as the object owner* (migrations run as this role):


ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO creditbook_analyst, creditbook_risk_officer,
                              creditbook_collections, creditbook_cfo;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO creditbook_analyst, creditbook_risk_officer, creditbook_cfo;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO creditbook_risk_officer, creditbook_collections;

-- Without this, every new table silently becomes unreadable to the roles that need it, 
--and every new sequence breaks the collections agent's INSERT — the kind of failure that surfaces at 2 a.m. on an unexpected random Friday.

/*
## Segregation of duties — the short version

| Concern 							| Who can do it 						| Who cannot 					|
|---								|---									|---							|
| Approve a loan 					| risk_officer 							| collections, analyst, cfo 	|
| Disburse funds 					| (app service, not a role) 			| all four roles 			 	|
| Record a payment 					| collections_agent 					| risk_officer, analyst, cfo 	|
| Reverse/correct a payment 		| (reconciliation process, not a role)  | collections_agent 			|
| Mark a loan charged off 			| risk_officer 							| collections_agent 			|
| Read PII 							| risk_officer, collections_agent, cfo  | analyst 						|
| Change schema 					| (deploy role) 						| all four roles 				|

The gaps in this table are deliberate — the actions not owned by any of these four roles belong to automated 
services or a separate reconciliation role, precisely so no single human can both cause and conceal a loss.
*/

-- ## What to test after applying
-- run as each role (SET ROLE) and confirm the boundary holds
SET ROLE creditbook_analyst;
SELECT name FROM customers;                          -- must fail: 42501
SELECT region FROM customers;                        -- must succeed
SELECT * FROM fn_portfolio_par(CURRENT_DATE);        -- must succeed

SET ROLE creditbook_collections;
UPDATE payments SET amount = 0 WHERE payment_id = 1; -- must fail: no UPDATE grant
INSERT INTO payments (loan_id, amount, payment_date, status)
VALUES (1, 100, CURRENT_DATE, 'pending');            -- must succeed, and trigger sets 'completed'

SET ROLE creditbook_risk_officer;
UPDATE loan_applications SET decision = 'approved' WHERE application_id = 1;  -- must succeed
UPDATE loan_applications SET principal = 0 WHERE application_id = 1;          -- must fail
/*
Any `42501` (`insufficient_privilege`) where the matrix says "must fail" is the test passing.
The two most common mistakes: forgetting `USAGE` on a sequence (INSERT fails with `42501` on the sequence, not the table), 
and forgetting that `EXECUTE` on functions defaults to `PUBLIC` — 
if `REVOKE ALL ... FROM PUBLIC` wasn't run first, every role can call every function regardless of the `GRANT`s below.
*/
