#!/usr/bin/env bash
set -euo pipefail

DATABASE="${1:-creditbook_modular_db}"
PSQL="${PSQL:-psql}"
files=(
  "00_schema/001_create_tables.sql"
  "00_schema/002_create_indexes.sql"
  "00_schema/003_create_roles.sql"
  "01_seed/seed_data.sql"
  "03_functions/fn_portfolio_par.sql"
  "03_functions/fn_set_payment_status.sql"
  "03_functions/trg_payments_set_status.sql"
  "02_staging/v_loan_balance.sql"
  "02_staging/v_loan_dpd.sql"
  "02_staging/v_payment_daily.sql"
  "02_staging/v_collection_fact.sql"
  "04_views_mv/v_customer_summary.sql"
  "04_views_mv/mv_portfolio_par.sql"
  "04_views_mv/refresh_all.sql"
  "07_grants/grants.sql"
  "06_checks/check_loan_count.sql"
  "06_checks/check_payment_positive.sql"
  "06_checks/check_par_range.sql"
)

args=(-X -v ON_ERROR_STOP=1 -d "$DATABASE")
for file in "${files[@]}"; do
  args+=(-f "$file")
done
"$PSQL" "${args[@]}"

printf 'CreditBook build completed for database: %s\n' "$DATABASE"
