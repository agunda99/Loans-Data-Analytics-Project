-- Shared point-in-time loan state.
CREATE OR REPLACE FUNCTION fn_loan_state(p_asof DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    loan_id INT,
    customer_id INT,
    product_id INT,
    loan_status TEXT,
    disbursement_date DATE,
    principal NUMERIC,
    total_scheduled NUMERIC,
    total_paid NUMERIC,
    outstanding_receivable NUMERIC,
    outstanding_principal NUMERIC,
    oldest_overdue DATE,
    dpd INT
)
LANGUAGE sql STABLE AS $$
    WITH paid AS (
        SELECT p.loan_id, SUM(p.amount) AS total_paid
        FROM public.payments p
        WHERE p.status = 'completed'
          AND p.payment_date <= p_asof
        GROUP BY p.loan_id
    ),
    installment_totals AS (
        SELECT
            rs.loan_id,
            rs.installment_no,
            rs.due_date,
            rs.principal_due,
            rs.interest_due,
            rs.total_due,
            SUM(rs.total_due) OVER (
                PARTITION BY rs.loan_id
                ORDER BY rs.installment_no
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_due,
            COALESCE(p.total_paid, 0) AS total_paid
        FROM public.repayment_schedule rs
        LEFT JOIN paid p ON p.loan_id = rs.loan_id
    ),
    allocations AS (
        SELECT
            i.*,
            LEAST(
                i.total_due,
                GREATEST(0, i.total_paid - (i.cumulative_due - i.total_due))
            ) AS amount_allocated
        FROM installment_totals i
    ),
    per_loan AS (
        SELECT
            a.loan_id,
            SUM(a.total_due) AS total_scheduled,
            MAX(a.total_paid) AS total_paid,
            GREATEST(0, SUM(a.total_due) - MAX(a.total_paid)) AS outstanding_receivable,
            GREATEST(
                0,
                SUM(a.principal_due)
                - SUM(LEAST(a.principal_due, GREATEST(0, a.amount_allocated - a.interest_due)))
            ) AS outstanding_principal,
            MIN(a.due_date) FILTER (
                WHERE a.due_date < p_asof AND a.amount_allocated < a.total_due
            ) AS oldest_overdue
        FROM allocations a
        GROUP BY a.loan_id
    )
    SELECT
        l.loan_id,
        l.customer_id,
        l.product_id,
        l.status,
        l.disbursement_date,
        l.principal,
        COALESCE(pl.total_scheduled, 0),
        COALESCE(pl.total_paid, 0),
        COALESCE(pl.outstanding_receivable, l.principal),
        COALESCE(pl.outstanding_principal, l.principal),
        pl.oldest_overdue,
        COALESCE(GREATEST(0, p_asof - pl.oldest_overdue), 0)::INT
    FROM public.loans l
    LEFT JOIN per_loan pl ON pl.loan_id = l.loan_id
    WHERE l.disbursement_date <= p_asof;
$$;

CREATE OR REPLACE FUNCTION fn_dpd(
    p_loan_id INT,
    p_asof DATE DEFAULT CURRENT_DATE
)
RETURNS INT
LANGUAGE sql STABLE AS $$
    SELECT s.dpd
    FROM public.fn_loan_state(p_asof) AS s
    WHERE s.loan_id = p_loan_id;
$$;

CREATE OR REPLACE FUNCTION fn_portfolio_par(p_asof DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    total_outstanding NUMERIC,
    par30_balance NUMERIC,
    par60_balance NUMERIC,
    par90_balance NUMERIC,
    par30_pct NUMERIC,
    par60_pct NUMERIC,
    par90_pct NUMERIC
)
LANGUAGE sql STABLE AS $$
    SELECT
        ROUND(SUM(s.outstanding_principal), 2),
        ROUND(SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30), 2),
        ROUND(SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 60), 2),
        ROUND(SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 90), 2),
        ROUND(100.0 * SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 30)
              / NULLIF(SUM(s.outstanding_principal), 0), 2),
        ROUND(100.0 * SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 60)
              / NULLIF(SUM(s.outstanding_principal), 0), 2),
        ROUND(100.0 * SUM(s.outstanding_principal) FILTER (WHERE s.dpd >= 90)
              / NULLIF(SUM(s.outstanding_principal), 0), 2)
    FROM public.fn_loan_state(p_asof) AS s
    WHERE s.outstanding_principal > 0
      AND (
          p_asof < CURRENT_DATE
          OR s.loan_status IN ('active', 'delinquent', 'defaulted')
      );
$$;

-- A narrowly scoped definer function for the collections queue. Collections
-- users can execute this function but cannot query the full loan-state function.
CREATE OR REPLACE FUNCTION fn_collections_worklist()
RETURNS TABLE (
    loan_id INT,
    customer_id INT,
    full_name TEXT,
    phone TEXT,
    region TEXT,
    product_name TEXT,
    oldest_overdue DATE,
    dpd INT,
    outstanding_principal NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT
        s.loan_id,
        s.customer_id,
        c.full_name,
        c.phone,
        COALESCE(c.region, 'unknown'),
        p.product_name,
        s.oldest_overdue,
        s.dpd,
        s.outstanding_principal
    FROM public.fn_loan_state(CURRENT_DATE) AS s
    JOIN public.customers AS c ON c.customer_id = s.customer_id
    JOIN public.loan_products AS p ON p.product_id = s.product_id
    WHERE s.loan_status IN ('active', 'delinquent', 'defaulted')
      AND s.dpd > 0
      AND s.outstanding_principal > 0;
$$;
