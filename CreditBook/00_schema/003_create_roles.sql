-- Non-login group roles. Run as a database administrator before grants.sql.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'creditbook_analyst') THEN
        CREATE ROLE creditbook_analyst NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'creditbook_risk_officer') THEN
        CREATE ROLE creditbook_risk_officer NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'creditbook_collections') THEN
        CREATE ROLE creditbook_collections NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'creditbook_cfo') THEN
        CREATE ROLE creditbook_cfo NOLOGIN;
    END IF;
END;
$$;
