from sqlalchemy import text

with engine.begin() as c:
    c.execute(text("DROP TABLE IF EXISTS loans;"))
    c.execute(text("""
        CREATE TABLE loans (
            loan_id           INTEGER PRIMARY KEY,
            borrower_id       INTEGER NOT NULL,
            disbursement_date DATE    NOT NULL,
            loan_amount       NUMERIC(12,2) NOT NULL,
            repayment_amount  NUMERIC(12,2) NOT NULL DEFAULT 0,
            due_date          DATE    NOT NULL,
            payment_date      DATE,
            status            TEXT    NOT NULL
        );
    """))

TODAY = "2024-06-15"  # pinned as-of date for reproducibility

loans = pd.DataFrame(
    [
        (1, 1, "2024-05-20", 5000, 1000, "2024-06-20", None, "active"),
        (2, 1, "2024-04-01", 3000, 3000, "2024-05-01", "2024-04-28", "closed"),
        (3, 2, "2024-06-01", 10000, 2000, "2024-07-01", None, "active"),
        (4, 2, "2024-02-15", 8000, 4000, "2024-03-15", "2024-04-05", "active"),
        (5, 3, "2024-06-10", 2000, 0, "2024-07-10", None, "active"),
        (6, 3, "2024-01-10", 15000, 5000, "2024-02-10", "2024-05-01", "active"),
        (7, 4, "2024-05-05", 4000, 4000, "2024-06-05", "2024-06-10", "closed"),
        (8, 4, "2024-06-12", 6000, 0, "2024-07-12", None, "active"),
        (9, 5, "2024-03-20", 7000, 3500, "2024-04-20", "2024-05-25", "active"),
        (10, 5, "2024-06-14", 1200, 0, "2024-07-14", None, "active"),
        (11, 1, "2024-04-25", 9000, 9000, "2024-05-25", "2024-05-25", "closed"),
        (12, 2, "2024-06-05", 5500, 500, "2024-08-05", None, "active"),
        (13, 3, "2024-03-01", 11000, 6000, "2024-04-01", "2024-06-20", "active"),
        (14, 4, "2024-05-30", 2500, 1000, "2024-06-30", None, "active"),
        (15, 5, "2024-02-01", 3000, 3000, "2024-03-01", "2024-03-15", "closed"),
    ],
    columns=[
        "loan_id",
        "borrower_id",
        "disbursement_date",
        "loan_amount",
        "repayment_amount",
        "due_date",
        "payment_date",
        "status",
    ],
)

# psycopg2 needs real Python date objects, not strings — let pandas parse them
for col in ["disbursement_date", "due_date", "payment_date"]:
    loans[col] = pd.to_datetime(loans[col]).dt.date

loans.to_sql("loans", engine, if_exists="append", index=False)
print(f"Loaded {len(loans)} rows into learn.loans")
