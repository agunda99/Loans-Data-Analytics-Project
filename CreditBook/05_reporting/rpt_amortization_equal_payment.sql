\set loan_id 1

-- Equal-payment (annuity) schedule for one loan. Change loan_id above.
WITH RECURSIVE loan_params AS (
    SELECT
        loan_id,
        principal::NUMERIC AS principal,
        tenor_months,
        annual_rate::NUMERIC / 12 / 100 AS monthly_rate
    FROM loans
    WHERE loan_id = :loan_id
),
payment_params AS (
    SELECT
        loan_id,
        principal,
        tenor_months,
        monthly_rate,
        CASE
            WHEN monthly_rate = 0 THEN ROUND(principal / tenor_months, 2)
            ELSE ROUND(
                principal * monthly_rate * POWER(1 + monthly_rate, tenor_months)
                / (POWER(1 + monthly_rate, tenor_months) - 1),
                2
            )
        END AS regular_payment
    FROM loan_params
),
schedule AS (
    SELECT
        1 AS installment_no,
        loan_id,
        tenor_months,
        monthly_rate,
        regular_payment,
        principal AS opening_balance,
        ROUND(principal * monthly_rate, 2) AS interest_due
    FROM payment_params

    UNION ALL

    SELECT
        s.installment_no + 1,
        s.loan_id,
        s.tenor_months,
        s.monthly_rate,
        s.regular_payment,
        s.opening_balance - (s.regular_payment - s.interest_due),
        ROUND((s.opening_balance - (s.regular_payment - s.interest_due)) * s.monthly_rate, 2)
    FROM schedule s
    WHERE s.installment_no < s.tenor_months
),
final_schedule AS (
    SELECT
        installment_no,
        loan_id,
        opening_balance,
        interest_due,
        CASE
            WHEN installment_no = tenor_months THEN ROUND(opening_balance, 2)
            ELSE ROUND(regular_payment - interest_due, 2)
        END AS principal_due,
        regular_payment
    FROM schedule
)
SELECT
    installment_no,
    loan_id,
    ROUND(opening_balance, 2) AS opening_balance,
    interest_due,
    principal_due,
    ROUND(interest_due + principal_due, 2) AS payment_due,
    ROUND(opening_balance - principal_due, 2) AS closing_balance,
    SUM(principal_due) OVER (ORDER BY installment_no) AS cumulative_principal,
    SUM(interest_due) OVER (ORDER BY installment_no) AS cumulative_interest
FROM final_schedule
ORDER BY installment_no;
