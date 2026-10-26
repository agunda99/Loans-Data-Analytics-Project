-- Illustrative scenario ECL only; replace PD/LGD assumptions with approved
-- policy parameters before using for finance, regulatory, or lending decisions.
WITH assumptions AS (
    SELECT
        0.01::NUMERIC AS pd_current_to_30,
        0.05::NUMERIC AS pd_31_to_60,
        0.20::NUMERIC AS pd_61_to_90,
        0.50::NUMERIC AS pd_90_plus,
        0.45::NUMERIC AS lgd
),
exposures AS (
    SELECT
        s.loan_id,
        p.category AS product_category,
        s.dpd,
        s.outstanding_principal AS ead,
        CASE
            WHEN s.dpd = 0 THEN a.pd_current_to_30
            WHEN s.dpd <= 30 THEN a.pd_current_to_30
            WHEN s.dpd <= 60 THEN a.pd_31_to_60
            WHEN s.dpd <= 90 THEN a.pd_61_to_90
            ELSE a.pd_90_plus
        END AS pd,
        a.lgd
    FROM fn_loan_state(CURRENT_DATE) s
    JOIN loan_products p ON p.product_id = s.product_id
    CROSS JOIN assumptions a
    WHERE s.loan_status IN ('active', 'delinquent', 'defaulted')
      AND s.outstanding_principal > 0
)
SELECT
    product_category,
    COUNT(*) AS exposure_count,
    ROUND(SUM(ead), 2) AS exposure_at_default,
    ROUND(SUM(ead * pd), 2) AS probability_weighted_exposure,
    ROUND(SUM(ead * pd * lgd), 2) AS illustrative_ecl,
    ROUND(100.0 * SUM(ead * pd * lgd) / NULLIF(SUM(ead), 0), 2)
        AS illustrative_ecl_pct_of_ead
FROM exposures
GROUP BY product_category
ORDER BY illustrative_ecl DESC;
