-- Learn the calculations from the inside out

-- Core function and views:

SELECT *
FROM fn_loan_state(CURRENT_DATE)
ORDER BY dpd DESC
LIMIT 20;

SELECT *
FROM v_loan_dpd
ORDER BY dpd DESC
LIMIT 20;

SELECT *
FROM fn_portfolio_par(CURRENT_DATE);

SELECT *
FROM mv_portfolio_par;