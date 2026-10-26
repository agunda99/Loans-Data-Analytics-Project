-- CreditBook's normalized PostgreSQL model.
-- Create the database separately, then run this file before the seed script.
BEGIN;

CREATE TABLE IF NOT EXISTS customers (
    customer_id      SERIAL PRIMARY KEY,
    full_name        TEXT NOT NULL,
    phone            TEXT,
    date_of_birth    DATE NOT NULL,
    gender           CHAR(1) CHECK (gender IN ('M', 'F', 'X')),
    region           TEXT,
    employment_type  TEXT,
    monthly_income   NUMERIC(12,2) CHECK (monthly_income IS NULL OR monthly_income >= 0),
    credit_score     INT CHECK (credit_score IS NULL OR credit_score BETWEEN 300 AND 850),
    kyc_status       TEXT NOT NULL DEFAULT 'verified'
                     CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
    onboarded_at     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS loan_products (
    product_id        SERIAL PRIMARY KEY,
    product_name      TEXT NOT NULL UNIQUE,
    category          TEXT NOT NULL,
    min_amount        NUMERIC(12,2) NOT NULL CHECK (min_amount > 0),
    max_amount        NUMERIC(12,2) NOT NULL CHECK (max_amount >= min_amount),
    min_tenor         INT NOT NULL CHECK (min_tenor > 0),
    max_tenor         INT NOT NULL CHECK (max_tenor >= min_tenor),
    base_annual_rate  NUMERIC(5,2) NOT NULL CHECK (base_annual_rate >= 0)
);

CREATE TABLE IF NOT EXISTS loan_applications (
    application_id    SERIAL PRIMARY KEY,
    customer_id       INT NOT NULL REFERENCES customers(customer_id),
    product_id        INT NOT NULL REFERENCES loan_products(product_id),
    application_date  DATE NOT NULL,
    requested_amount  NUMERIC(12,2) NOT NULL CHECK (requested_amount > 0),
    requested_tenor   INT NOT NULL CHECK (requested_tenor > 0),
    decision          TEXT NOT NULL DEFAULT 'pending'
                      CHECK (decision IN ('pending', 'approved', 'declined')),
    decision_date     DATE,
    approved_amount   NUMERIC(12,2) CHECK (approved_amount IS NULL OR approved_amount > 0),
    approved_rate     NUMERIC(5,2) CHECK (approved_rate IS NULL OR approved_rate >= 0),
    CHECK (decision_date IS NULL OR decision_date >= application_date),
    CHECK ((decision = 'approved') = (approved_amount IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS loans (
    loan_id            SERIAL PRIMARY KEY,
    application_id     INT UNIQUE REFERENCES loan_applications(application_id),
    customer_id        INT NOT NULL REFERENCES customers(customer_id),
    product_id         INT NOT NULL REFERENCES loan_products(product_id),
    principal          NUMERIC(12,2) NOT NULL CHECK (principal > 0),
    annual_rate        NUMERIC(5,2) NOT NULL CHECK (annual_rate >= 0),
    tenor_months       INT NOT NULL CHECK (tenor_months > 0),
    disbursement_date  DATE NOT NULL,
    maturity_date      DATE NOT NULL,
    status             TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active', 'delinquent', 'defaulted', 'closed', 'written_off')),
    CHECK (maturity_date > disbursement_date)
);

CREATE TABLE IF NOT EXISTS repayment_schedule (
    schedule_id      SERIAL PRIMARY KEY,
    loan_id          INT NOT NULL REFERENCES loans(loan_id) ON DELETE CASCADE,
    installment_no   INT NOT NULL CHECK (installment_no > 0),
    due_date         DATE NOT NULL,
    principal_due    NUMERIC(12,2) NOT NULL CHECK (principal_due >= 0),
    interest_due     NUMERIC(12,2) NOT NULL CHECK (interest_due >= 0),
    total_due        NUMERIC(12,2) NOT NULL CHECK (total_due > 0),
    UNIQUE (loan_id, installment_no),
    CHECK (total_due = principal_due + interest_due)
);

CREATE TABLE IF NOT EXISTS payments (
    payment_id    SERIAL PRIMARY KEY,
    loan_id       INT NOT NULL REFERENCES loans(loan_id),
    payment_date  DATE NOT NULL,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    channel       TEXT CHECK (channel IN ('mobile_money', 'bank_transfer', 'cash', 'card')),
    status        TEXT NOT NULL DEFAULT 'completed'
                  CHECK (status IN ('pending', 'completed', 'failed', 'reversed'))
);

CREATE TABLE IF NOT EXISTS collections_actions (
    action_id     SERIAL PRIMARY KEY,
    loan_id       INT NOT NULL REFERENCES loans(loan_id),
    action_date   DATE NOT NULL,
    action_type   TEXT NOT NULL CHECK (action_type IN ('call', 'sms', 'email', 'visit')),
    agent         TEXT,
    outcome       TEXT CHECK (outcome IN ('promise_to_pay', 'no_answer', 'paid', 'escalated')),
    notes         TEXT
);

COMMIT;
