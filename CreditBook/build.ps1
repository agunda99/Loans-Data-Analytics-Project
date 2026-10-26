param(
    [string]$Database = "creditbook_modular_db",
    [string]$PsqlPath = "psql",
    [string]$Username,
    [string]$Server,
    [int]$Port
)

$ErrorActionPreference = "Stop"
$files = @(
    "00_schema\001_create_tables.sql",
    "00_schema\002_create_indexes.sql",
    "00_schema\003_create_roles.sql",
    "01_seed\seed_data.sql",
    "03_functions\fn_portfolio_par.sql",
    "03_functions\fn_set_payment_status.sql",
    "03_functions\trg_payments_set_status.sql",
    "02_staging\v_loan_balance.sql",
    "02_staging\v_loan_dpd.sql",
    "02_staging\v_payment_daily.sql",
    "02_staging\v_collection_fact.sql",
    "04_views_mv\v_customer_summary.sql",
    "04_views_mv\mv_portfolio_par.sql",
    "04_views_mv\refresh_all.sql",
    "07_grants\grants.sql",
    "06_checks\check_loan_count.sql",
    "06_checks\check_payment_positive.sql",
    "06_checks\check_par_range.sql"
)

$sqlPaths = @()
foreach ($file in $files) {
    $path = Join-Path $PSScriptRoot $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required SQL file is missing: $path"
    }
    $sqlPaths += $path
}

$psqlArguments = @("-X", "-v", "ON_ERROR_STOP=1", "-d", $Database)
if ($Username) { $psqlArguments += @("-U", $Username) }
if ($Server) { $psqlArguments += @("-h", $Server) }
if ($Port -gt 0) { $psqlArguments += @("-p", "$Port") }
foreach ($path in $sqlPaths) {
    $psqlArguments += @("-f", $path)
}

& $PsqlPath @psqlArguments
if ($LASTEXITCODE -ne 0) {
    throw "psql failed with exit code $LASTEXITCODE"
}

Write-Host "CreditBook build completed for database: $Database"
