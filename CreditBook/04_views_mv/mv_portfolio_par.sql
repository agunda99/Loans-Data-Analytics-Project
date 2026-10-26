CREATE MATERIALIZED VIEW IF NOT EXISTS mv_portfolio_par AS
SELECT
    COALESCE(p.category, 'unknown') AS product_category,
    COUNT(*) AS loan_count,
    ROUND(SUM(s.outstanding_principal), 2) AS total_outstanding_principal,
    ROUND(SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30), 2) AS par30_balance,
    ROUND(SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 60), 2) AS par60_balance,
    ROUND(SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 90), 2) AS par90_balance,
    ROUND(
        100.0 * SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30)
        / NULLIF(SUM(s.outstanding_principal), 0),
        2
    ) AS par30_pct,
    ROUND(
        100.0 * SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 60)
        / NULLIF(SUM(s.outstanding_principal), 0),
        2
    ) AS par60_pct,
    ROUND(
        100.0 * SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 90)
        / NULLIF(SUM(s.outstanding_principal), 0),
        2
    ) AS par90_pct,
    CURRENT_DATE AS as_of_date
FROM public.fn_loan_state(CURRENT_DATE) AS s
JOIN public.loan_products AS p ON p.product_id = s.product_id
WHERE s.loan_status IN ('active', 'delinquent', 'defaulted')
GROUP BY p.category;

CREATE UNIQUE INDEX IF NOT EXISTS mv_portfolio_par_category_uidx
    ON mv_portfolio_par (product_category);
