-- Month-end roll matrix plus a six-transition Current -> 1-30 trend.
WITH asofs AS (
    SELECT (
        DATE_TRUNC('month', CURRENT_DATE)::DATE
        - (g.n * INTERVAL '1 month')
        - INTERVAL '1 day'
    )::DATE AS snap_date
    FROM generate_series(0, 6) AS g(n)
),
snapshot AS (
    SELECT
        a.snap_date,
        s.loan_id,
        CASE
            WHEN s.outstanding_principal <= 0 THEN 'Paid off'
            WHEN s.dpd = 0 THEN 'Current'
            WHEN s.dpd <= 30 THEN '1-30'
            WHEN s.dpd <= 60 THEN '31-60'
            WHEN s.dpd <= 90 THEN '61-90'
            ELSE '90+'
        END AS dpd_bucket
    FROM asofs a
    CROSS JOIN LATERAL fn_loan_state(a.snap_date) s
),
transitions AS (
    SELECT
        loan_id,
        snap_date,
        dpd_bucket AS to_bucket,
        LAG(snap_date) OVER (PARTITION BY loan_id ORDER BY snap_date) AS from_date,
        LAG(dpd_bucket) OVER (PARTITION BY loan_id ORDER BY snap_date) AS from_bucket
    FROM snapshot
),
valid_transitions AS (
    SELECT *
    FROM transitions
    WHERE from_date = (DATE_TRUNC('month', snap_date)::DATE - INTERVAL '1 day')::DATE
)
SELECT
    snap_date,
    COUNT(*) FILTER (WHERE from_bucket = 'Current') AS loans_current_last_month,
    COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = 'Current')
        AS current_to_current,
    COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = '1-30')
        AS current_to_1_30,
    COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = '31-60')
        AS current_to_31_60,
    COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = '61-90')
        AS current_to_61_90,
    COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = '90+')
        AS current_to_90_plus,
    COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = 'Paid off')
        AS current_to_paid_off,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE from_bucket = 'Current' AND to_bucket = '1-30')
        / NULLIF(COUNT(*) FILTER (WHERE from_bucket = 'Current'), 0),
        2
    ) AS current_to_1_30_pct
FROM valid_transitions
GROUP BY snap_date
ORDER BY snap_date;

-- Latest observed month-end roll-rate matrix.
WITH latest AS (
    SELECT MAX(snap_date) AS snap_date
    FROM (
        SELECT (
            DATE_TRUNC('month', CURRENT_DATE)::DATE
            - (g.n * INTERVAL '1 month')
            - INTERVAL '1 day'
        )::DATE AS snap_date
        FROM generate_series(0, 6) AS g(n)
    ) d
),
snapshots AS (
    SELECT
        d.snap_date,
        s.loan_id,
        CASE
            WHEN s.outstanding_principal <= 0 THEN 'Paid off'
            WHEN s.dpd = 0 THEN 'Current'
            WHEN s.dpd <= 30 THEN '1-30'
            WHEN s.dpd <= 60 THEN '31-60'
            WHEN s.dpd <= 90 THEN '61-90'
            ELSE '90+'
        END AS dpd_bucket
    FROM (
        SELECT (DATE_TRUNC('month', snap_date)::DATE - INTERVAL '1 day')::DATE AS snap_date
        FROM latest
        UNION ALL
        SELECT snap_date FROM latest
    ) d
    CROSS JOIN LATERAL fn_loan_state(d.snap_date) s
),
pairs AS (
    SELECT
        prior.dpd_bucket AS from_bucket,
        current.dpd_bucket AS to_bucket
    FROM snapshots prior
    JOIN snapshots current
      ON current.loan_id = prior.loan_id
     AND DATE_TRUNC('month', current.snap_date)
         = DATE_TRUNC('month', prior.snap_date) + INTERVAL '1 month'
)
SELECT
    from_bucket,
    COUNT(*) FILTER (WHERE to_bucket = 'Current') AS to_current,
    COUNT(*) FILTER (WHERE to_bucket = '1-30') AS to_1_30,
    COUNT(*) FILTER (WHERE to_bucket = '31-60') AS to_31_60,
    COUNT(*) FILTER (WHERE to_bucket = '61-90') AS to_61_90,
    COUNT(*) FILTER (WHERE to_bucket = '90+') AS to_90_plus,
    COUNT(*) FILTER (WHERE to_bucket = 'Paid off') AS to_paid_off
FROM pairs
GROUP BY from_bucket
ORDER BY CASE from_bucket
    WHEN 'Current' THEN 1
    WHEN '1-30' THEN 2
    WHEN '31-60' THEN 3
    WHEN '61-90' THEN 4
    WHEN '90+' THEN 5
    ELSE 6
END;
