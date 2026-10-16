-- Run through run.sql in a disposable database. All names are transaction-local fixtures.
CREATE SCHEMA binding_src;
SET LOCAL search_path = binding_src, public;
CREATE TABLE sample (id bigint);
CREATE TYPE payload AS (id bigint);
INSERT INTO sample VALUES (11);
DO $$
BEGIN
  FOR i IN 0..54 LOOP
    EXECUTE format('CREATE FUNCTION binding_src.echo_%s(value sample) RETURNS sample LANGUAGE SQL AS $body$ SELECT value $body$', i);
  END LOOP;
END $$;
CREATE FUNCTION echo_0(value bigint) RETURNS bigint LANGUAGE SQL AS $$ SELECT value $$;
CREATE FUNCTION array_echo(value sample[]) RETURNS sample[] LANGUAGE SQL AS $$ SELECT value $$;
CREATE FUNCTION payload_echo(value payload) RETURNS payload LANGUAGE SQL AS $$ SELECT value $$;
CREATE FUNCTION default_row(value sample DEFAULT ROW(7)::sample) RETURNS TABLE(result sample)
  LANGUAGE SQL AS $$ SELECT value $$;
CREATE FUNCTION out_row(IN value sample, OUT result sample) LANGUAGE SQL AS $$ SELECT value $$;
CREATE FUNCTION rows() RETURNS SETOF sample LANGUAGE SQL AS $$ SELECT * FROM sample $$;
CREATE FUNCTION pinned_rows() RETURNS SETOF sample LANGUAGE SQL SET search_path = binding_src, public
  AS $$ SELECT * FROM sample $$;
CREATE PROCEDURE accept_row(value sample) LANGUAGE SQL AS $$ SELECT value $$;
CREATE FUNCTION "Quoted Echo"(value sample) RETURNS sample LANGUAGE SQL AS $$ SELECT value $$;
COMMENT ON FUNCTION "Quoted Echo"(sample) IS 'composite comment';
COMMENT ON FUNCTION default_row(sample) IS 'default comment';
COMMENT ON PROCEDURE accept_row(sample) IS 'procedure comment';
CREATE VIEW later_view AS SELECT id FROM sample;
CREATE MATERIALIZED VIEW later_matview AS SELECT id FROM sample;
CREATE FUNCTION view_rows() RETURNS SETOF bigint LANGUAGE SQL AS $$ SELECT id FROM later_view $$;
CREATE FUNCTION matview_rows() RETURNS SETOF bigint LANGUAGE SQL AS $$ SELECT id FROM later_matview $$;

-- Reusable assertions also allow clients to validate replayed DDLONLY output.
CREATE FUNCTION pg_temp.assert_bindings(target text, expected_id bigint) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  p record;
  result bigint;
  routine_count integer := 0;
BEGIN
  FOR p IN SELECT * FROM pg_proc WHERE pronamespace = target::regnamespace LOOP
    routine_count := routine_count + 1;
    IF EXISTS (
      SELECT FROM pg_type t WHERE t.typnamespace = 'binding_src'::regnamespace
      AND (t.oid = ANY(p.proargtypes::oid[]) OR t.oid = p.prorettype OR t.oid = ANY(p.proallargtypes))
    ) THEN
      RAISE EXCEPTION 'Source type binding in %.%', target, p.proname;
    END IF;
    IF p.proowner <> (SELECT oid FROM pg_roles WHERE rolname = current_user) THEN
      RAISE EXCEPTION 'Unexpected owner for %', p.proname;
    END IF;
  END LOOP;
  IF routine_count <> 66 THEN RAISE EXCEPTION 'Expected 66 routines, found %', routine_count; END IF;
  PERFORM set_config('search_path', format('%I, public', target), true);
  EXECUTE 'SELECT (echo_0(ROW(42)::sample)).id + echo_0(9::bigint)' INTO result;
  IF result <> 51 THEN RAISE EXCEPTION 'Overload invocation'; END IF;
  EXECUTE 'SELECT ((array_echo(ARRAY[ROW(8)::sample]))[1]).id' INTO result;
  IF result <> 8 THEN RAISE EXCEPTION 'Array invocation'; END IF;
  EXECUTE 'SELECT (payload_echo(ROW(6)::payload)).id' INTO result;
  IF result <> 6 THEN RAISE EXCEPTION 'Composite type invocation'; END IF;
  EXECUTE 'SELECT id FROM default_row()' INTO result;
  IF result <> 7 THEN RAISE EXCEPTION 'Default/TABLE invocation'; END IF;
  EXECUTE 'SELECT (out_row(ROW(5)::sample)).id' INTO result;
  IF result <> 5 THEN RAISE EXCEPTION 'OUT invocation'; END IF;
  EXECUTE 'CALL accept_row(ROW(3)::sample)';
  EXECUTE 'SELECT id FROM rows()' INTO result;
  IF result IS DISTINCT FROM expected_id THEN RAISE EXCEPTION 'Body resolved outside destination'; END IF;
  EXECUTE 'SELECT * FROM view_rows()' INTO result;
  IF result IS DISTINCT FROM expected_id THEN RAISE EXCEPTION 'View body'; END IF;
  -- NODATA intentionally leaves materialized views unpopulated.
  EXECUTE 'REFRESH MATERIALIZED VIEW later_matview';
  EXECUTE 'SELECT * FROM matview_rows()' INTO result;
  IF result IS DISTINCT FROM expected_id THEN RAISE EXCEPTION 'Materialized view body'; END IF;
  IF (SELECT proconfig FROM pg_proc WHERE pronamespace = target::regnamespace AND proname = 'pinned_rows')
     IS DISTINCT FROM ARRAY['search_path=binding_src, public'] THEN
    RAISE EXCEPTION 'Explicit function-local search_path was changed';
  END IF;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = target::regnamespace
      AND obj_description(oid, 'pg_proc') IN ('composite comment', 'default comment', 'procedure comment')) <> 3 THEN
    RAISE EXCEPTION 'Missing routine comments';
  END IF;
    IF EXISTS (SELECT FROM pg_proc routine WHERE pronamespace = target::regnamespace
      AND NOT has_function_privilege(current_user, routine.oid, 'EXECUTE')) THEN
    RAISE EXCEPTION 'Missing owner EXECUTE privilege';
  END IF;
END $$;

-- SQL string bodies referencing views require the caller's documented setting.
SET LOCAL check_function_bodies = off;
DO $$
DECLARE
  options public.cloneparms[];
  target text;
  result integer;
  saved_path text;
BEGIN
  FOR i IN 1..3 LOOP
    target := 'binding_dst_' || i;
    options := CASE i WHEN 1 THEN ARRAY['NODATA']::public.cloneparms[]
                     WHEN 2 THEN ARRAY['DATA']::public.cloneparms[]
                     ELSE ARRAY['NODATA','NOOWNER','NOACL']::public.cloneparms[] END;
    PERFORM set_config('search_path', 'public', true);
    saved_path := current_setting('search_path');
    result := public.clone_schema('binding_src', target, VARIADIC options);
    IF result <> 0 THEN RAISE EXCEPTION 'clone_schema returned %', result; END IF;
    IF current_setting('search_path') <> saved_path OR current_setting('check_function_bodies') <> 'off' THEN
      RAISE EXCEPTION 'Caller settings changed';
    END IF;
    PERFORM pg_temp.assert_bindings(target, CASE WHEN i = 2 THEN 11::bigint ELSE NULL::bigint END);
    RAISE NOTICE 'PASS composite bindings mode % (66 routines)', options;
  END LOOP;
END $$;

CREATE SCHEMA binding_empty;
DO $$
DECLARE
  setting text;
  saved_path text;
BEGIN
  FOREACH setting IN ARRAY ARRAY['on','off'] LOOP
    PERFORM set_config('check_function_bodies', setting, true);
    PERFORM set_config('search_path', '', true);
    saved_path := current_setting('search_path');
    IF public.clone_schema('binding_empty', 'binding_empty_' || setting, 'NODATA') <> 0 THEN
      RAISE EXCEPTION 'Empty clone failed';
    END IF;
    IF current_setting('search_path') <> saved_path OR current_setting('check_function_bodies') <> setting THEN
      RAISE EXCEPTION 'Empty clone settings changed';
    END IF;
    RAISE NOTICE 'PASS empty clone, validation %', setting;
  END LOOP;
END $$;

-- DDLONLY must not install routines or change the caller's validation setting.
SET LOCAL check_function_bodies = off;
SET LOCAL search_path = public;
DO $$
BEGIN
  IF public.clone_schema('binding_src', 'binding_ddl', 'DDLONLY') <> 0 THEN
    RAISE EXCEPTION 'DDLONLY failed';
  END IF;
  IF to_regnamespace('binding_ddl') IS NOT NULL
     OR current_setting('search_path') <> 'public'
     OR current_setting('check_function_bodies') <> 'off' THEN
    RAISE EXCEPTION 'DDLONLY changed database objects or caller settings';
  END IF;
  RAISE NOTICE 'PASS DDLONLY generation and settings';
END $$;