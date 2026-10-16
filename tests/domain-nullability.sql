-- Install clone_schema.sql first. Run with psql -X -v ON_ERROR_STOP=1
-- against a disposable database; these schema names must not already exist.
BEGIN;
SET LOCAL statement_timeout = '15s';
CREATE SCHEMA domain_src;
CREATE DOMAIN domain_src.optional_int AS integer CHECK (VALUE >= 0);
CREATE DOMAIN domain_src.required_int AS integer NOT NULL;
CREATE TABLE domain_src.items (a domain_src.optional_int, b domain_src.required_int);
INSERT INTO domain_src.items VALUES (NULL, 1);
SELECT public.clone_schema('domain_src', 'domain_data', 'DATA');
SELECT public.clone_schema('domain_src', 'domain_empty', 'NODATA', 'NOOWNER', 'NOACL');
-- Use the cloned domain itself, independently of table type bindings.
SELECT NULL::domain_data.optional_int;
SELECT NULL::domain_empty.optional_int;
DO $$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY['domain_data', 'domain_empty'] LOOP
    IF (SELECT typnotnull FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
        WHERE n.nspname=target AND t.typname='optional_int') IS DISTINCT FROM false THEN
      RAISE EXCEPTION 'nullable domain changed in %', target;
    END IF;
    IF (SELECT typnotnull FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
        WHERE n.nspname=target AND t.typname='required_int') IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'NOT NULL domain changed in %', target;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM domain_data.items WHERE a IS NULL AND b=1) <> 1 THEN
    RAISE EXCEPTION 'NULL row was not copied';
  END IF;
END $$;
INSERT INTO domain_empty.items VALUES (NULL, 2);
ROLLBACK;
