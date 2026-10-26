-- PAR uses remaining principal exposure (not future contractual interest).
SELECT *
FROM fn_portfolio_par(CURRENT_DATE);

-- Segment views use each segment's own outstanding-principal denominator.
WITH state AS (
    SELECT *
    FROM fn_loan_state(CURRENT_DATE)
    WHERE outstanding_principal > 0
      AND loan_status IN ('active', 'delinquent', 'defaulted')
),
segments AS (
    SELECT
        CASE WHEN GROUPING(p.category) = 0 THEN 'product_category' ELSE 'region' END
            AS segment_type,
        COALESCE(p.category, c.region, 'unknown') AS segment,
        COUNT(*) AS loan_count,
        SUM(s.outstanding_principal) AS outstanding_principal,
        SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30) AS par30_balance,
        SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 60) AS par60_balance,
        SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 90) AS par90_balance
    FROM state s
    JOIN loan_products p ON p.product_id = s.product_id
    JOIN customers c ON c.customer_id = s.customer_id
    GROUP BY GROUPING SETS ((p.category), (c.region))
)
SELECT
    segment_type,
    segment,
    loan_count,
    ROUND(outstanding_principal, 2) AS outstanding_principal,
    ROUND(par30_balance, 2) AS par30_balance,
    ROUND(par60_balance, 2) AS par60_balance,
    ROUND(par90_balance, 2) AS par90_balance,
    ROUND(100.0 * par30_balance / NULLIF(outstanding_principal, 0), 2) AS par30_pct,
    ROUND(100.0 * par60_balance / NULLIF(outstanding_principal, 0), 2) AS par60_pct,
    ROUND(100.0 * par90_balance / NULLIF(outstanding_principal, 0), 2) AS par90_pct
FROM segments
ORDER BY segment_type, par30_pct DESC NULLS LAST, segment;

-- Historical PAR trend at each of the last 12 completed month-ends.
SELECT
    snapshots.as_of_date,
    par.total_outstanding,
    par.par30_balance,
    par.par60_balance,
    par.par90_balance,
    par.par30_pct,
    par.par60_pct,
    par.par90_pct
FROM (
    SELECT (
        DATE_TRUNC('month', CURRENT_DATE)::DATE
        - (g.n * INTERVAL '1 month')
        - INTERVAL '1 day'
    )::DATE AS as_of_date
    FROM generate_series(0, 11) AS g(n)
) AS snapshots
CROSS JOIN LATERAL fn_portfolio_par(snapshots.as_of_date) AS par
ORDER BY snapshots.as_of_date;

-- Monthly PAR30 by product category with cumulative PAR30 balance.
WITH asofs AS (
    SELECT (
        DATE_TRUNC('month', CURRENT_DATE)::DATE
        - (g.n * INTERVAL '1 month')
        - INTERVAL '1 day'
    )::DATE AS as_of_date
    FROM generate_series(0, 11) AS g(n)
),
monthly_category AS (
    SELECT
        a.as_of_date,
        p.category AS product_category,
        SUM(s.outstanding_principal) AS total_outstanding_principal,
        SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30) AS par30_balance
    FROM asofs a
    CROSS JOIN LATERAL public.fn_loan_state(a.as_of_date) s
    JOIN loans l ON l.loan_id = s.loan_id
    JOIN loan_products p ON p.product_id = s.product_id
    WHERE s.outstanding_principal > 0
      AND (
          a.as_of_date < CURRENT_DATE
          OR s.loan_status IN ('active', 'delinquent', 'defaulted')
      )
    GROUP BY a.as_of_date, p.category
)
SELECT
    as_of_date,
    product_category,
    ROUND(total_outstanding_principal, 2) AS total_outstanding_principal,
    ROUND(par30_balance, 2) AS par30_balance,
    ROUND(100.0 * par30_balance / NULLIF(total_outstanding_principal, 0), 2) AS par30_pct,
    ROUND(
        SUM(par30_balance) OVER (
            PARTITION BY product_category ORDER BY as_of_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cumulative_par30_balance
FROM monthly_category
ORDER BY product_category, as_of_date;
