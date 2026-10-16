-- PostgreSQL 17+ regression fixture (includes its builtin collation provider).
-- Install clone_schema.sql first. Run with psql -X -v ON_ERROR_STOP=1
-- against a disposable database; fixture names must not already exist.
BEGIN;
SET LOCAL statement_timeout = '15s';
CREATE SCHEMA collation_src;
CREATE COLLATION collation_src."C locale" FROM pg_catalog."C";
CREATE COLLATION collation_src.icu_locale (provider=icu, locale='und', deterministic=false);
CREATE COLLATION collation_src.builtin_locale (provider=builtin, locale='C');
SELECT public.clone_schema('collation_src','collation_empty','NODATA');
SELECT public.clone_schema('collation_src','collation_data','DATA','NOOWNER','NOACL');
DO $$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY['collation_empty','collation_data'] LOOP
    IF (SELECT count(*) FROM pg_collation c JOIN pg_namespace n ON n.oid=c.collnamespace
        WHERE n.nspname=target) <> 3 THEN
      RAISE EXCEPTION 'collations missing in %', target;
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_collation s JOIN pg_namespace sn ON sn.oid=s.collnamespace
        JOIN pg_collation d ON d.collname=s.collname
        JOIN pg_namespace dn ON dn.oid=d.collnamespace
      WHERE sn.nspname='collation_src' AND dn.nspname=target
        AND ROW(s.collprovider,s.collisdeterministic,s.collencoding,s.collcollate,s.collctype,s.colllocale)
            IS DISTINCT FROM ROW(d.collprovider,d.collisdeterministic,d.collencoding,d.collcollate,d.collctype,d.colllocale)
    ) THEN
      RAISE EXCEPTION 'collation properties changed in %', target;
    END IF;
  END LOOP;
END $$;
DROP SCHEMA collation_src CASCADE;
-- CREATE COLLATION ... FROM copies properties; it adds no source dependency.
SELECT 'tiny' COLLATE collation_empty."C locale" < 'z' COLLATE collation_empty."C locale";
ROLLBACK;
