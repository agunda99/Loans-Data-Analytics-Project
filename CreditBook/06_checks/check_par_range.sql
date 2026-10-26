-- PAR percentages must be between zero and 100; no row means the check passed.
SELECT
    product_category,
    par30_pct,
    par60_pct,
    par90_pct
FROM mv_portfolio_par
WHERE par30_pct < 0 OR par30_pct > 100
   OR par60_pct < 0 OR par60_pct > 100
   OR par90_pct < 0 OR par90_pct > 100
   OR par30_pct < par60_pct
   OR par60_pct < par90_pct;

-- A zero-exposure portfolio should have NULL ratios rather than division errors.
SELECT *
FROM mv_portfolio_par
WHERE total_outstanding_principal = 0
  AND (par30_pct IS NOT NULL OR par60_pct IS NOT NULL OR par90_pct IS NOT NULL);
