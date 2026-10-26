-- Synthetic, repeatable portfolio data. Re-running this file resets all sample rows.
BEGIN;
TRUNCATE TABLE collections_actions, payments, repayment_schedule, loans,
    loan_applications, loan_products, customers RESTART IDENTITY CASCADE;
SELECT setseed(0.42);

INSERT INTO loan_products
    (product_name, category, min_amount, max_amount, min_tenor, max_tenor, base_annual_rate)
VALUES
    ('Personal Standard', 'personal', 5000, 100000, 6, 36, 18.50),
    ('Personal Premium', 'personal', 100000, 1000000, 12, 60, 14.00),
    ('SME Working Capital', 'business', 20000, 2000000, 3, 24, 22.00),
    ('Auto Loan', 'auto', 200000, 3000000, 12, 84, 12.50),
    ('Micro Loan', 'micro', 500, 20000, 1, 12, 28.00);

INSERT INTO customers
    (full_name, date_of_birth, gender, region, employment_type, monthly_income, credit_score)
SELECT
    'Customer ' || g,
    DATE '1965-01-01' + (random() * 15000)::INT,
    (ARRAY['M', 'F'])[1 + (random() * 1)::INT],
    (ARRAY['Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret'])[1 + (random() * 4)::INT],
    (ARRAY['salaried', 'self_employed', 'business_owner', 'casual'])[1 + (random() * 3)::INT],
    (20000 + random() * 300000)::NUMERIC(12,2),
    (300 + random() * 500)::INT
FROM generate_series(1, 2000) AS g;

WITH product_options AS MATERIALIZED (
    SELECT
        p.product_id,
        p.min_amount,
        p.max_amount,
        p.min_tenor,
        p.max_tenor,
        p.base_annual_rate,
        ROW_NUMBER() OVER (ORDER BY p.product_id) AS product_number,
        COUNT(*) OVER () AS product_count
    FROM loan_products p
),
application_inputs AS MATERIALIZED (
    SELECT
        c.customer_id,
        p.product_id,
        p.min_amount,
        p.max_amount,
        p.min_tenor,
        p.max_tenor,
        p.base_annual_rate,
        c.credit_score,
        CURRENT_DATE - (random() * 730)::INT AS application_date,
        random() AS amount_draw,
        random() AS tenor_draw,
        random() AS decision_draw
    FROM customers c
    CROSS JOIN LATERAL generate_series(1, 1 + (random() * 2)::INT) AS attempt(n)
        JOIN product_options p
            ON p.product_number = MOD(c.customer_id + attempt.n - 2, p.product_count) + 1
)
INSERT INTO loan_applications
    (customer_id, product_id, application_date, requested_amount, requested_tenor,
     decision, decision_date, approved_amount, approved_rate)
SELECT
    customer_id,
    product_id,
    application_date,
    (min_amount + amount_draw * (max_amount - min_amount))::NUMERIC(12,2),
    min_tenor + (tenor_draw * (max_tenor - min_tenor))::INT,
    CASE
        WHEN decision_draw < 0.70 THEN 'approved'
        WHEN decision_draw < 0.90 THEN 'declined'
        ELSE 'pending'
    END,
    CASE
        WHEN decision_draw < 0.90 THEN application_date + (random() * 14)::INT
        ELSE NULL
    END,
    CASE
        WHEN decision_draw < 0.70
        THEN (min_amount + amount_draw * (max_amount - min_amount))::NUMERIC(12,2)
        ELSE NULL
    END,
    CASE
        WHEN decision_draw < 0.70
        THEN base_annual_rate + CASE WHEN credit_score > 700 THEN -2.00 ELSE 3.00 END
        ELSE NULL
    END
FROM application_inputs;

INSERT INTO loans
    (application_id, customer_id, product_id, principal, annual_rate, tenor_months,
     disbursement_date, maturity_date, status)
SELECT
    a.application_id,
    a.customer_id,
    a.product_id,
    a.approved_amount,
    a.approved_rate,
    a.requested_tenor,
    a.decision_date + 3,
    (a.decision_date + 3 + (a.requested_tenor * INTERVAL '1 month'))::DATE,
    'active'
FROM loan_applications a
WHERE a.decision = 'approved'
  AND a.decision_date <= CURRENT_DATE - 3
  AND random() < 0.85;

WITH installment_amounts AS (
    SELECT
        l.loan_id,
        l.principal,
        l.annual_rate,
        l.tenor_months,
        g.installment_no,
        (l.disbursement_date + (g.installment_no * INTERVAL '1 month'))::DATE AS due_date,
        CASE
            WHEN g.installment_no = l.tenor_months
            THEN l.principal - ROUND(l.principal / l.tenor_months, 2) * (l.tenor_months - 1)
            ELSE ROUND(l.principal / l.tenor_months, 2)
        END AS principal_due,
        ROUND(
            (l.principal - (g.installment_no - 1) * (l.principal / l.tenor_months))
            * (l.annual_rate / 12.0 / 100),
            2
        ) AS interest_due
    FROM loans l
    CROSS JOIN LATERAL generate_series(1, l.tenor_months) AS g(installment_no)
)
INSERT INTO repayment_schedule
    (loan_id, installment_no, due_date, principal_due, interest_due, total_due)
SELECT
    loan_id,
    installment_no,
    due_date,
    principal_due,
    interest_due,
    principal_due + interest_due
FROM installment_amounts;

INSERT INTO payments (loan_id, payment_date, amount, channel, status)
SELECT
    rs.loan_id,
    LEAST(rs.due_date + (random() * 60)::INT, CURRENT_DATE),
    CASE
        WHEN random() < 0.15 THEN GREATEST(0.01, ROUND(rs.total_due * 0.50, 2))
        ELSE rs.total_due
    END,
    (ARRAY['mobile_money', 'bank_transfer', 'cash', 'card'])[1 + (random() * 3)::INT],
    'completed'
FROM repayment_schedule rs
WHERE rs.due_date < CURRENT_DATE
  AND random() < 0.83;

INSERT INTO collections_actions (loan_id, action_date, action_type, agent, outcome)
SELECT
    l.loan_id,
    GREATEST(l.disbursement_date, CURRENT_DATE - (random() * 90)::INT),
    (ARRAY['call', 'sms', 'email', 'visit'])[1 + (random() * 3)::INT],
    'agent_' || (1 + (random() * 20)::INT),
    (ARRAY['promise_to_pay', 'no_answer', 'paid', 'escalated'])[1 + (random() * 3)::INT]
FROM loans l
WHERE random() < 0.30;

WITH loan_repayments AS (
    SELECT
        l.loan_id,
        l.maturity_date,
        SUM(rs.total_due) AS scheduled_total,
        COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'completed'), 0) AS paid_total
    FROM loans l
    JOIN repayment_schedule rs ON rs.loan_id = l.loan_id
    LEFT JOIN payments p ON p.loan_id = l.loan_id
    GROUP BY l.loan_id, l.maturity_date
)
UPDATE loans l
SET status = 'closed'
FROM loan_repayments r
WHERE r.loan_id = l.loan_id
  AND r.maturity_date <= CURRENT_DATE
  AND r.paid_total >= r.scheduled_total;

COMMIT;

-- Reproducibility checks after loading.
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'loan_products', COUNT(*) FROM loan_products
UNION ALL SELECT 'loan_applications', COUNT(*) FROM loan_applications
UNION ALL SELECT 'loans', COUNT(*) FROM loans
UNION ALL SELECT 'repayment_schedule', COUNT(*) FROM repayment_schedule
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'collections_actions', COUNT(*) FROM collections_actions;

-- Product coverage across applications and every downstream loan fact.
WITH application_counts AS (
    SELECT product_id, COUNT(*) AS application_count
    FROM loan_applications
    GROUP BY product_id
), loan_counts AS (
    SELECT product_id, COUNT(*) AS loan_count
    FROM loans
    GROUP BY product_id
), schedule_counts AS (
    SELECT l.product_id, COUNT(*) AS installment_count
    FROM loans l
    JOIN repayment_schedule rs ON rs.loan_id = l.loan_id
    GROUP BY l.product_id
), payment_counts AS (
    SELECT l.product_id, COUNT(*) AS payment_count
    FROM loans l
    JOIN payments p ON p.loan_id = l.loan_id
    GROUP BY l.product_id
)
SELECT
    p.category,
    p.product_name,
    COALESCE(a.application_count, 0) AS application_count,
    COALESCE(l.loan_count, 0) AS loan_count,
    COALESCE(s.installment_count, 0) AS installment_count,
    COALESCE(pay.payment_count, 0) AS payment_count
FROM loan_products p
LEFT JOIN application_counts a ON a.product_id = p.product_id
LEFT JOIN loan_counts l ON l.product_id = p.product_id
LEFT JOIN schedule_counts s ON s.product_id = p.product_id
LEFT JOIN payment_counts pay ON pay.product_id = p.product_id
ORDER BY p.product_id;
