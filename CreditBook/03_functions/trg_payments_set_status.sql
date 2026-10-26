DROP TRIGGER IF EXISTS trg_payments_validate ON payments;
CREATE TRIGGER trg_payments_validate
BEFORE INSERT OR UPDATE OF amount ON payments
FOR EACH ROW
EXECUTE FUNCTION fn_validate_payment();

-- A newly recorded positive payment is completed unless explicitly reversed.
CREATE OR REPLACE FUNCTION fn_set_payment_status()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status IS NULL THEN
        NEW.status := 'completed';
    ELSIF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
        NEW.status := 'completed';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_payments_set_status ON payments;
CREATE TRIGGER trg_payments_set_status
BEFORE INSERT ON payments
FOR EACH ROW
EXECUTE FUNCTION fn_set_payment_status();
