-- Reject non-positive payments explicitly; the table constraint is a second guard.
CREATE OR REPLACE FUNCTION fn_validate_payment()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.amount IS NULL OR NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero (got %)', NEW.amount
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
