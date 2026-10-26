-- Run outside an explicit transaction. The unique index must exist first.
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_portfolio_par;
