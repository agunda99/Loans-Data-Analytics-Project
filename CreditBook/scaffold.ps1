# Create any missing CreditBook structure without overwriting existing work.
$directories = @(
    "00_schema", "01_seed", "02_staging", "03_functions",
    "04_views_mv", "05_reporting", "06_checks", "07_grants"
)
foreach ($directory in $directories) {
    New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot $directory) |
        Out-Null
}

$files = @(
    "00_schema\001_create_tables.sql",
    "00_schema\002_create_indexes.sql",
    "00_schema\003_create_roles.sql",
    "01_seed\seed_data.sql",
    "02_staging\v_loan_dpd.sql",
    "02_staging\v_loan_balance.sql",
    "02_staging\v_payment_daily.sql",
    "02_staging\v_collection_fact.sql",
    "03_functions\fn_portfolio_par.sql",
    "03_functions\fn_set_payment_status.sql",
    "03_functions\trg_payments_set_status.sql",
    "04_views_mv\v_customer_summary.sql",
    "04_views_mv\mv_portfolio_par.sql",
    "04_views_mv\refresh_mv_portfolio_par.sql",
    "04_views_mv\refresh_all.sql",
    "05_reporting\rpt_loan_exploration.sql",
    "05_reporting\rpt_portfolio_summary.sql",
    "05_reporting\rpt_par.sql",
    "05_reporting\rpt_vintage.sql",
    "05_reporting\rpt_roll_rate.sql",
    "05_reporting\rpt_watchlist.sql",
    "05_reporting\rpt_collections_effectiveness.sql",
    "05_reporting\rpt_ecl.sql",
    "05_reporting\rpt_disbursements.sql",
    "05_reporting\rpt_amortization_equal_payment.sql",
    "05_reporting\rpt_amortization_equal_principal.sql",
    "06_checks\check_loan_count.sql",
    "06_checks\check_par_range.sql",
    "06_checks\check_payment_positive.sql",
    "07_grants\grants.sql",
    "METRICS.md",
    "README.md",
    "build.ps1",
    "build.sh"
)

foreach ($file in $files) {
    $path = Join-Path $PSScriptRoot $file
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType File -Path $path | Out-Null
    }
}

Write-Host "CreditBook structure is ready at $PSScriptRoot"
