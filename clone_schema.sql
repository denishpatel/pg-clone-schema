-- Function: clone_schema(text, text)

-- DROP FUNCTION clone_schema(text, text);

CREATE OR REPLACE FUNCTION public.clone_schema(
    source_schema text,
    dest_schema text,
    include_recs boolean)
  RETURNS void AS
$BODY$

--  This function will clone all sequences, tables, data, views & functions from any existing schema to a new one
-- SAMPLE CALL:
-- SELECT clone_schema('public', 'new_schema', TRUE);

DECLARE
  src_oid          oid;
  tbl_oid          oid;
  func_oid         oid;
  object           text;
  buffer           text;
  srctbl           text;
  default_         text;
  column_          text;
  qry              text;
  dest_qry         text;
  v_def            text;
  seqval           bigint;
  sq_last_value    bigint;
  sq_max_value     bigint;
  sq_start_value   bigint;
  sq_increment_by  bigint;
  sq_min_value     bigint;
  sq_cache_value   bigint;
  sq_log_cnt       bigint;
  sq_is_called     boolean;
  sq_is_cycled     boolean;
  sq_cycled        char(10);
  arec             RECORD;
  cnt              integer;

BEGIN

-- Check that source_schema exists
  SELECT oid INTO src_oid
    FROM pg_namespace
   WHERE nspname = quote_ident(source_schema);
  IF NOT FOUND
    THEN
    RAISE NOTICE 'source schema % does not exist!', source_schema;
    RETURN ;
  END IF;

  -- Check that dest_schema does not yet exist
  PERFORM nspname
    FROM pg_namespace
   WHERE nspname = quote_ident(dest_schema);
  IF FOUND
    THEN
    RAISE NOTICE 'dest schema % already exists!', dest_schema;
    RETURN ;
  END IF;

  EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) ;

  -- MV: Create Collations
  cnt := 0;
  FOR arec IN 
    SELECT n.nspname as schemaname, a.rolname as ownername , c.collname, c.collprovider,  c.collcollate as locale,
    'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || CASE WHEN c.collprovider = 'i' THEN 'icu' WHEN c.collprovider = 'c' THEN 'libc' ELSE '' END || ', locale = ''' || c.collcollate || ''');' as COLL_DDL
    FROM pg_collation c JOIN pg_namespace n ON (c.collnamespace = n.oid) JOIN pg_authid a ON (c.collowner = a.oid) WHERE n.nspname = quote_ident(source_schema) order by c.collname
  LOOP
    BEGIN
      cnt := cnt + 1;
      EXECUTE arec.coll_ddl;
    END;          
  END LOOP;
  RAISE NOTICE 'COLLATIONS cloned: %', LPAD(cnt::text, 5, ' '); 
 
  -- MV: Create Domains
  cnt := 0;
  FOR arec IN 
    SELECT n.nspname as "Schema", t.typname as "Name", pg_catalog.format_type(t.typbasetype, t.typtypmod) as "Type",
    (SELECT c.collname FROM pg_catalog.pg_collation c, pg_catalog.pg_type bt WHERE c.oid = t.typcollation AND 
    bt.oid = t.typbasetype AND t.typcollation <> bt.typcollation) as "Collation", 
    CASE WHEN t.typnotnull THEN 'not null' END as "Nullable", t.typdefault as "Default", 
    pg_catalog.array_to_string(ARRAY(SELECT pg_catalog.pg_get_constraintdef(r.oid, true) FROM pg_catalog.pg_constraint r WHERE t.oid = r.contypid), ' ') as "Check",
    'CREATE DOMAIN ' || quote_ident(dest_schema) || '.' || t.typname || ' AS ' || pg_catalog.format_type(t.typbasetype, t.typtypmod) || 
    CASE WHEN t.typnotnull IS NOT NULL THEN ' NOT NULL ' ELSE ' ' END || CASE WHEN t.typdefault IS NOT NULL THEN 'DEFAULT ' || t.typdefault || ' ' ELSE ' ' END || 
    pg_catalog.array_to_string(ARRAY(SELECT pg_catalog.pg_get_constraintdef(r.oid, true) FROM pg_catalog.pg_constraint r WHERE t.oid = r.contypid), ' ') || ';' AS DOM_DDL 
    FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typtype = 'd' AND n.nspname = quote_ident(source_schema) AND pg_catalog.pg_type_is_visible(t.oid) ORDER BY 1, 2
  LOOP
    BEGIN
      cnt := cnt + 1;
      EXECUTE arec.dom_ddl;
    END;          
  END LOOP;
  RAISE NOTICE '   DOMAINS cloned: %', LPAD(cnt::text, 5, ' '); 
  
  -- MV: Create types
  cnt := 0;
  FOR arec IN 
    SELECT c.relkind, n.nspname AS schemaname, t.typname AS typname, t.typcategory, CASE WHEN t.typcategory='C' THEN 
    'CREATE TYPE ' || quote_ident(dest_schema) || '.' || t.typname || ' AS (' || array_to_string(array_agg(a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod) ORDER BY c.relname, a.attnum),', ') || ');'
    WHEN t.typcategory='E' THEN 
    'CREATE TYPE ' || quote_ident(dest_schema) || '.' || t.typname || ' AS ENUM (' || REPLACE(quote_literal(array_to_string(array_agg(e.enumlabel ORDER BY e.enumsortorder),',')), ',', ''',''') || ');'
    ELSE '' END AS type_ddl FROM pg_type t JOIN pg_namespace n ON (n.oid = t.typnamespace)
    LEFT JOIN pg_enum e ON (t.oid = e.enumtypid)
    LEFT JOIN pg_class c ON (c.reltype = t.oid) LEFT JOIN pg_attribute a ON (a.attrelid = c.oid)
    WHERE n.nspname = quote_ident(source_schema) and (c.relkind IS NULL or c.relkind = 'c') and t.typcategory in ('C', 'E') group by 1,2,3,4 order by n.nspname, t.typcategory, t.typname
  LOOP
    BEGIN
      cnt := cnt + 1;
      -- Keep composite and enum types in separate branches for fine tuning later if needed.
      IF arec.typcategory = 'E' THEN
          -- RAISE NOTICE '%', arec.type_ddl;
          EXECUTE arec.type_ddl;
      ELSEIF arec.typcategory = 'C' THEN
          -- RAISE NOTICE '%', arec.type_ddl;
          EXECUTE arec.type_ddl;
      ELSE
          RAISE NOTICE 'Unhandled type:%-%', arec.typcategory, arec.typname;
      END IF;
    END;          
  END LOOP;
  RAISE NOTICE '     TYPES cloned: %', LPAD(cnt::text, 5, ' ');
  
  -- Create sequences
  cnt := 0;
  -- TODO: Find a way to make this sequence's owner is the correct table.
  FOR object IN
    SELECT sequence_name::text
      FROM information_schema.sequences
     WHERE sequence_schema = quote_ident(source_schema)
  LOOP
    cnt := cnt + 1;
    EXECUTE 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(object);
    srctbl := quote_ident(source_schema) || '.' || quote_ident(object);

    EXECUTE 'SELECT last_value, log_cnt, is_called
              FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';'
              INTO sq_last_value, sq_log_cnt,sq_is_called ;

    EXECUTE 'SELECT max_value, start_value, increment_by, min_value, cache_size, cycle
              FROM pg_catalog.pg_sequences WHERE schemaname='''|| quote_ident(source_schema) || ''' AND sequencename=''' || quote_ident(object) || ''';'
              INTO sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_is_cycled ;

    IF sq_is_cycled
      THEN
        sq_cycled := 'CYCLE';
    ELSE
        sq_cycled := 'NO CYCLE';
    END IF;

    EXECUTE 'ALTER SEQUENCE '   || quote_ident(dest_schema) || '.' || quote_ident(object)
            || ' INCREMENT BY ' || sq_increment_by
            || ' MINVALUE '     || sq_min_value
            || ' MAXVALUE '     || sq_max_value
            || ' START WITH '   || sq_start_value
            || ' RESTART '      || sq_min_value
            || ' CACHE '        || sq_cache_value
            || sq_cycled || ' ;' ;

    buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
    IF include_recs
        THEN
            EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
    ELSE
            EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
    END IF;

  END LOOP;
  RAISE NOTICE ' SEQUENCES cloned: %', LPAD(cnt::text, 5, ' ');
  
-- Create tables
  cnt := 0;
  FOR object IN
    SELECT TABLE_NAME::text
      FROM information_schema.tables
     WHERE table_schema = quote_ident(source_schema)
       AND table_type = 'BASE TABLE'

  LOOP
    cnt := cnt + 1;
    buffer := dest_schema || '.' || quote_ident(object);
    EXECUTE 'CREATE TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(object) || ' INCLUDING ALL)';
    IF include_recs
      THEN
      -- Insert records from source table
      RAISE NOTICE 'Populating cloned table, %', buffer;      
      EXECUTE 'INSERT INTO ' || buffer || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';';
    END IF;

    FOR column_, default_ IN
      SELECT column_name::text,
             REPLACE(column_default::text, source_schema, dest_schema)
        FROM information_schema.COLUMNS
       WHERE table_schema = dest_schema
         AND TABLE_NAME = object
         AND column_default LIKE 'nextval(%' || quote_ident(source_schema) || '%::regclass)'
    LOOP
      EXECUTE 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || column_ || ' SET DEFAULT ' || default_;
    END LOOP;

  END LOOP;
  RAISE NOTICE '    TABLES cloned: %', LPAD(cnt::text, 5, ' ');
    
--  add FK constraint
  cnt := 0;
  FOR qry IN
    SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname)
                          || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || pg_get_constraintdef(ct.oid) || ';'
      FROM pg_constraint ct
      JOIN pg_class rn ON rn.oid = ct.conrelid
     WHERE connamespace = src_oid
       AND rn.relkind = 'r'
       AND ct.contype = 'f'

    LOOP
      cnt := cnt + 1;
      EXECUTE qry;

    END LOOP;
  RAISE NOTICE '     FKEYS cloned: %', LPAD(cnt::text, 5, ' ');
  
-- Create views
  cnt := 0;
  FOR object IN
    SELECT table_name::text,
           view_definition
      FROM information_schema.views
     WHERE table_schema = quote_ident(source_schema)

  LOOP
    cnt := cnt + 1;
    buffer := dest_schema || '.' || quote_ident(object);
    SELECT view_definition INTO v_def
      FROM information_schema.views
     WHERE table_schema = quote_ident(source_schema)
       AND table_name = quote_ident(object);

    EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def || ';' ;

  END LOOP;
  RAISE NOTICE '     VIEWS cloned: %', LPAD(cnt::text, 5, ' ');
  
  -- Create Materialized views
    cnt := 0;
    FOR object IN
      SELECT matviewname::text,
             definition
        FROM pg_catalog.pg_matviews
       WHERE schemaname = quote_ident(source_schema)

    LOOP
      cnt := cnt + 1;
      buffer := dest_schema || '.' || quote_ident(object);
      SELECT replace(definition,';','') INTO v_def
        FROM pg_catalog.pg_matviews
       WHERE schemaname = quote_ident(source_schema)
         AND matviewname = quote_ident(object);

         IF include_recs
           THEN
           EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || v_def || ';' ;
           ELSE
           EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || v_def || ' WITH NO DATA;' ;
         END IF;

    END LOOP;
    RAISE NOTICE ' MAT VIEWS cloned: %', LPAD(cnt::text, 5, ' ');
    
-- Create functions
  cnt := 0;
  FOR func_oid IN
    SELECT oid
      FROM pg_proc
     WHERE pronamespace = src_oid
  LOOP
    cnt := cnt + 1;
    SELECT pg_get_functiondef(func_oid) INTO qry;
    SELECT replace(qry, source_schema, dest_schema) INTO dest_qry;
    EXECUTE dest_qry;
  END LOOP;
  RAISE NOTICE ' FUNCTIONS cloned: %', LPAD(cnt::text, 5, ' ');
RETURN;  
END;


$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.clone_schema(text, text, boolean) OWNER TO postgres;
