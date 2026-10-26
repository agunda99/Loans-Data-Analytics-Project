-- Non-concurrent refresh is safe on the first load and works without an index.
REFRESH MATERIALIZED VIEW mv_portfolio_par;
