\set loan_id 1

-- Equal-principal schedule generated during seeding. Change loan_id above.
SELECT
    rs.installment_no,
    rs.loan_id,
    rs.due_date,
    ROUND(rs.principal_due, 2) AS principal_due,
    ROUND(rs.interest_due, 2) AS interest_due,
    ROUND(rs.total_due, 2) AS payment_due,
    ROUND(
        GREATEST(0, l.principal - SUM(rs.principal_due)
            OVER (PARTITION BY rs.loan_id ORDER BY rs.installment_no)),
        2
    ) AS closing_principal_balance,
    ROUND(SUM(rs.interest_due)
        OVER (PARTITION BY rs.loan_id ORDER BY rs.installment_no), 2)
        AS cumulative_interest
FROM repayment_schedule rs
JOIN loans l ON l.loan_id = rs.loan_id
WHERE rs.loan_id = :loan_id
ORDER BY rs.installment_no;
