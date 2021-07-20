-- Change History:
-- 2021-03-03  MJV FIX: Fixed population of tables with rows section. "buffer" variable was not initialized correctly. Used new variable, tblname, to fix it.
-- 2021-03-03  MJV FIX: Fixed Issue#34 where user-defined types in declare section of functions caused runtime errors.
-- 2021-03-04  MJV FIX: Fixed Issue#35 where privileges for functions were not being set correctly causing the program to bomb and giving privileges to other users that should not have gotten them.
-- 2021-03-05  MJV FIX: Fixed Issue#36 Fixed table and other object permissions
-- 2021-03-05  MJV FIX: Fixed Issue#37 Fixed function grants again for case where parameters have default values.
-- 2021-03-08  MJV FIX: Fixed Issue#38 fixed issue where source schema specified for executed trigger function action
-- 2021-03-08  MJV FIX: Fixed Issue#39 Add warnings for table columns that are user-defined since the probably refer back to the source schema!  No fix for it at this time.
-- 2021-03-09  MJV FIX: Fixed Issue#40 Rewrote trigger SQL instead to simply things for all cases
-- 2021-03-19  MJV FIX: Fixed Issue#39 Added new function to generate table ddl instead of using the CREATE TABLE LIKE statement only for use cases with user-defined column datatypes.
-- 2021-04-02  MJV FIX: Fixed Issue#43 Fixed views case where view was created successfully in target schema, but referenced table was not.
-- 2021-06-30  MJV FIX: Fixed Issue#46 Invalid record reference, tbl_ddl.  Changed to tbl_dcl in PRIVS section.
-- 2021-06-30  MJV FIX: Fixed Issue#46 Invalid record reference, tbl_ddl.  Changed to tbl_dcl in PRIVS section. Thanks to dpmillerau for this fix.
-- 2021-06-30  MJV FIX: Fixed Issue#47 Fixed resetting search path to what it was before.  Thanks to dpmillerau for this fix.

-- count validations:
-- \set aschema sample
-- select rt.tbls_regular as tbls_regular, ut.unlogged_tables as tbls_unlogged, pt.partitions as tbls_child, pn.parents as tbls_parents, rt.tbls_regular + ut.unlogged_tables + pt.partitions + pn.parents as tbls_total, se.sequences as sequences, ix.indexes as indexes, vi.views as views, pv.pviews as pub_views, mv.mats as mat_views, fn.functions as functions, ty.types as types, tf.trigfuncs, tr.triggers as triggers, co.collations as collations, dom.domains as domains from (select count(*) as tbls_regular from pg_class c, pg_tables t, pg_namespace n where t.schemaname = :'aschema' and t.tablename = c.relname and c.relkind = 'r' and n.oid = c.relnamespace and n.nspname = t.schemaname and c.relpersistence = 'p' and c.relispartition is false) rt, (select count(distinct (t.schemaname, t.tablename)) as unlogged_tables from pg_tables t, pg_class c where t.schemaname = :'aschema' and t.tablename = c.relname and c.relkind = 'r' and c.relpersistence = 'u' ) ut, (SELECT count(*) as sequences FROM pg_class c, pg_namespace n where n.oid = c.relnamespace and c.relkind = 'S' and n.nspname = :'aschema') se, (select count(*) as indexes from pg_class c, pg_namespace n, pg_indexes i where n.nspname = :'aschema' and n.oid = c.relnamespace and c.relkind <> 'p' and n.nspname = i.schemaname and c.relname = i.tablename) ix, (select count(*) as views from pg_views where schemaname = :'aschema') vi, (select count(*) as pviews from pg_views where schemaname = 'public') pv, (select count(c.relname) as parents from pg_class c join pg_namespace n on (c.relnamespace = n.oid)  where n.nspname = :'aschema' and c.relkind = 'p') pn, (SELECT count(*) as partitions FROM pg_inherits JOIN pg_class AS c ON (inhrelid=c.oid) JOIN pg_class as p ON (inhparent=p.oid) JOIN pg_namespace pn ON pn.oid = p.relnamespace JOIN pg_namespace cn ON cn.oid = c.relnamespace WHERE pn.nspname = :'aschema' and c.relkind = 'r') pt, (SELECT count(*) as functions FROM pg_proc p INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid) WHERE ns.nspname = :'aschema') fn, (SELECT count(*) as types FROM pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid)) AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid) AND n.nspname = :'aschema') ty, (SELECT count(*) as trigfuncs FROM pg_catalog.pg_proc p LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace LEFT JOIN pg_catalog.pg_language l ON l.oid = p.prolang WHERE pg_catalog.pg_get_function_result(p.oid) = 'trigger' and n.nspname = :'aschema') tf, (SELECT count(distinct (trigger_schema, trigger_name, event_object_table, action_statement, action_orientation, action_timing)) as triggers  FROM information_schema.triggers WHERE trigger_schema = :'aschema') tr, (select count(distinct(n.nspname, c.relname)) as mats from pg_class c, pg_namespace n where c.relnamespace = n.oid and c.relkind = 'm') mv, (SELECT count(*) as collations FROM pg_collation c JOIN pg_namespace n ON (c.collnamespace = n.oid) JOIN pg_authid a ON (c.collowner = a.oid) WHERE n.nspname = :'aschema') co, (SELECT count(*) as domains FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace WHERE t.typtype = 'd' AND n.nspname OPERATOR(pg_catalog.~) '^(:aschema)$' COLLATE pg_catalog.default) dom;

-- SELECT * FROM public.get_table_ddl('sample', 'address', True);

CREATE OR REPLACE FUNCTION public.get_table_ddl(
  in_schema varchar,
  in_table varchar,
  bfkeys  boolean
)
RETURNS text
LANGUAGE plpgsql VOLATILE
AS
$$
  DECLARE
    -- the ddl we're building
    v_table_ddl text;

    -- data about the target table
    v_table_oid int;

    -- records for looping
    v_colrec record;
    v_constraintrec record;
    v_indexrec record;
    v_primary boolean := False;
    v_constraint_name text;
  BEGIN
    -- grab the oid of the table; https://www.postgresql.org/docs/8.3/catalog-pg-class.html
    SELECT c.oid INTO v_table_oid
    FROM pg_catalog.pg_class c
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE 1=1
      AND c.relkind = 'r' -- r = ordinary table; https://www.postgresql.org/docs/9.3/catalog-pg-class.html
      AND c.relname = in_table -- the table name
      AND n.nspname = in_schema; -- the schema

    -- throw an error if table was not found
    IF (v_table_oid IS NULL) THEN
      RAISE EXCEPTION 'table does not exist';
    END IF;

    -- start the create definition
    v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || ' (' || E'\n';

    -- define all of the columns in the table; https://stackoverflow.com/a/8153081/3068233
    FOR v_colrec IN
      SELECT
        c.column_name,
        c.data_type,
        c.udt_name,
        c.character_maximum_length,
        c.is_nullable,
        c.column_default,
        c.numeric_precision, c.numeric_scale, c.is_identity, c.identity_generation        
      FROM information_schema.columns c
      WHERE (table_schema, table_name) = (in_schema, in_table)
      ORDER BY ordinal_position
    LOOP
      v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
        || v_colrec.column_name || ' '
        || CASE WHEN v_colrec.data_type = 'USER-DEFINED' THEN in_schema || '.' || v_colrec.udt_name ELSE v_colrec.data_type END 
        || CASE WHEN v_colrec.is_identity = 'YES' THEN CASE WHEN v_colrec.identity_generation = 'ALWAYS' THEN ' GENERATED ALWAYS AS IDENTITY' ELSE ' GENERATED BY DEFAULT AS IDENTITY' END ELSE '' END
        || CASE WHEN v_colrec.character_maximum_length IS NOT NULL THEN ('(' || v_colrec.character_maximum_length || ')') 
                WHEN v_colrec.numeric_precision > 0 AND v_colrec.numeric_scale > 0 THEN '(' || v_colrec.numeric_precision || ',' || v_colrec.numeric_scale || ')' 
           ELSE '' END || ' '
        || CASE WHEN v_colrec.is_nullable = 'NO' THEN 'NOT NULL' ELSE 'NULL' END
        || CASE WHEN v_colrec.column_default IS NOT null THEN (' DEFAULT ' || v_colrec.column_default) ELSE '' END
        || ',' || E'\n';
    END LOOP;

    -- define all the constraints in the; https://www.postgresql.org/docs/9.1/catalog-pg-constraint.html && https://dba.stackexchange.com/a/214877/75296
    FOR v_constraintrec IN
      SELECT
        con.conname as constraint_name,
        con.contype as constraint_type,
        CASE
          WHEN con.contype = 'p' THEN 1 -- primary key constraint
          WHEN con.contype = 'u' THEN 2 -- unique constraint
          WHEN con.contype = 'f' THEN 3 -- foreign key constraint
          WHEN con.contype = 'c' THEN 4
          ELSE 5
        END as type_rank,
        pg_get_constraintdef(con.oid) as constraint_definition
      FROM pg_catalog.pg_constraint con
      JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
      JOIN pg_catalog.pg_namespace nsp ON nsp.oid = connamespace
      WHERE nsp.nspname = in_schema
      AND rel.relname = in_table
      ORDER BY type_rank
    LOOP
      IF v_constraintrec.type_rank = 1 THEN
          v_primary := True;
          v_constraint_name := v_constraintrec.constraint_name;
      END IF;
      IF NOT bfkeys AND v_constraintrec.constraint_type = 'f' THEN
          continue;
      END IF;
      v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
        || 'CONSTRAINT' || ' '
        || v_constraintrec.constraint_name || ' '
        || v_constraintrec.constraint_definition
        || ',' || E'\n';
    END LOOP;

    -- drop the last comma before ending the create statement
    v_table_ddl = substr(v_table_ddl, 0, length(v_table_ddl) - 1) || E'\n';

    -- end the create definition
    v_table_ddl := v_table_ddl || ');' || E'\n';

    -- suffix create statement with all of the indexes on the table
    FOR v_indexrec IN
      SELECT indexdef, indexname
      FROM pg_indexes
      WHERE (schemaname, tablename) = (in_schema, in_table)
    LOOP
      IF v_indexrec.indexname = v_constraint_name THEN
          continue;
      END IF;
      v_table_ddl := v_table_ddl
        || v_indexrec.indexdef
        || ';' || E'\n';
    END LOOP;

    -- return the ddl
    RETURN v_table_ddl;
  END;
$$;

-- Function: clone_schema(text, text, boolean, boolean) 

-- DROP FUNCTION clone_schema(text, text, boolean, boolean);

CREATE OR REPLACE FUNCTION public.clone_schema(
    source_schema text,
    dest_schema text,
    include_recs boolean,
    ddl_only     boolean)
  RETURNS void AS
$BODY$

--  This function will clone all sequences, tables, data, views & functions from any existing schema to a new one
-- SAMPLE CALL:
-- SELECT clone_schema('sample', 'sample_clone2', True, False);

DECLARE
  src_oid          oid;
  tbl_oid          oid;
  func_oid         oid;
  object           text;
  buffer           text;
  buffer2          text;
  buffer3          text;  
  srctbl           text;
  default_         text;
  column_          text;
  qry              text;
  ix_old_name      text;
  ix_new_name      text;
  aname            text;
  relpersist       text;
  relispart        text;
  relknd           text;
  data_type        text;
  adef             text;
  dest_qry         text;
  v_def            text;
  part_range       text;
  src_path_old     text;
  aclstr           text;
  grantor          text;
  grantee          text;
  privs            text;
  seqval           bigint;
  sq_last_value    bigint;
  sq_max_value     bigint;
  sq_start_value   bigint;
  sq_increment_by  bigint;
  sq_min_value     bigint;
  sq_cache_value   bigint;
  sq_is_called     boolean;
  sq_is_cycled     boolean;
  sq_data_type     text;
  sq_cycled        char(10);
  arec             RECORD;
  cnt              integer;
  cnt2             integer;
  pos              integer;
  action           text := 'N/A';
  tblname          text;
  v_ret            text;
  v_diag1          text;
  v_diag2          text;
  v_diag3          text;
  v_diag4          text;
  v_diag5          text;
  v_diag6          text;

BEGIN

  -- Make sure NOTICE are shown
  set client_min_messages = 'notice';
  
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
  IF ddl_only and include_recs THEN
    RAISE WARNING 'You cannot specify to clone data and generate ddl at the same time.';
    RETURN ;
  END IF;

  -- Set the search_path to source schema. Before exiting set it back to what it was before.
  SELECT setting INTO src_path_old FROM pg_settings WHERE name='search_path';
  EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
  -- RAISE NOTICE 'Using source search_path=%', buffer;

  -- Validate required types exist.  If not, create them.
  select a.objtypecnt, b.permtypecnt INTO cnt, cnt2 FROM
  (SELECT count(*) as objtypecnt FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
  WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
  AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
  AND n.nspname <> 'pg_catalog' AND n.nspname <> 'information_schema' AND pg_catalog.pg_type_is_visible(t.oid) AND pg_catalog.format_type(t.oid, NULL) = 'obj_type') a,
  (SELECT count(*) as permtypecnt FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
  WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
  AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
  AND n.nspname <> 'pg_catalog' AND n.nspname <> 'information_schema' AND pg_catalog.pg_type_is_visible(t.oid) AND pg_catalog.format_type(t.oid, NULL) = 'perm_type') b;
  IF cnt = 0 THEN
    CREATE TYPE obj_type AS ENUM ('TABLE','VIEW','COLUMN','SEQUENCE','FUNCTION','SCHEMA','DATABASE');
  END IF;
  IF cnt2 = 0 THEN
    CREATE TYPE perm_type AS ENUM ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','USAGE','CREATE','EXECUTE','CONNECT','TEMPORARY');
  END IF;

  IF ddl_only THEN
    RAISE NOTICE 'Only generating DDL, not actually creating anything...';
  END IF;

  IF ddl_only THEN
    RAISE NOTICE '%', 'CREATE SCHEMA ' || quote_ident(dest_schema);
  ELSE
    EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) ;
  END IF;

  -- MV: Create Collations
  action := 'Collations';
  cnt := 0;
  FOR arec IN
    SELECT n.nspname as schemaname, a.rolname as ownername , c.collname, c.collprovider,  c.collcollate as locale,
    'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || CASE WHEN c.collprovider = 'i' THEN 'icu' WHEN c.collprovider = 'c' THEN 'libc' ELSE '' END || ', locale = ''' || c.collcollate || ''');' as COLL_DDL
    FROM pg_collation c JOIN pg_namespace n ON (c.collnamespace = n.oid) JOIN pg_roles a ON (c.collowner = a.oid) WHERE n.nspname = quote_ident(source_schema) order by c.collname
  LOOP
    BEGIN
      cnt := cnt + 1;
      IF ddl_only THEN
        RAISE INFO '%', arec.coll_ddl;
      ELSE
        EXECUTE arec.coll_ddl;
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '  COLLATIONS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: Create Domains
  action := 'Domains';
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
      IF ddl_only THEN
        RAISE INFO '%', arec.dom_ddl;
      ELSE
        EXECUTE arec.dom_ddl;
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '     DOMAINS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: Create types
  action := 'Types';
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
      IF ddl_only THEN
        RAISE INFO '%', arec.type_ddl;
      ELSE
        EXECUTE arec.type_ddl;
      END IF;

      ELSEIF arec.typcategory = 'C' THEN
        -- RAISE NOTICE '%', arec.type_ddl;
        IF ddl_only THEN
          RAISE INFO '%', arec.type_ddl;
        ELSE
          EXECUTE arec.type_ddl;
        END IF;
      ELSE
          RAISE NOTICE 'Unhandled type:%-%', arec.typcategory, arec.typname;
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '       TYPES cloned: %', LPAD(cnt::text, 5, ' ');

  -- Create sequences
  action := 'Sequences';
  cnt := 0;
  -- TODO: Find a way to make this sequence's owner is the correct table.
  FOR object IN
    SELECT sequence_name::text
      FROM information_schema.sequences
     WHERE sequence_schema = quote_ident(source_schema)
  LOOP
    cnt := cnt + 1;
    IF ddl_only THEN
      RAISE INFO '%', 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(object) || ';';
    ELSE
      EXECUTE 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(object);
    END IF;
    srctbl := quote_ident(source_schema) || '.' || quote_ident(object);

    EXECUTE 'SELECT last_value, is_called
              FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';'
              INTO sq_last_value, sq_is_called;

    EXECUTE 'SELECT max_value, start_value, increment_by, min_value, cache_size, cycle, data_type
              FROM pg_catalog.pg_sequences WHERE schemaname='|| quote_literal(source_schema) || ' AND sequencename=' || quote_literal(object) || ';'
              INTO sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_is_cycled, sq_data_type ;

    IF sq_is_cycled
      THEN
        sq_cycled := 'CYCLE';
    ELSE
        sq_cycled := 'NO CYCLE';
    END IF;

    qry := 'ALTER SEQUENCE '   || quote_ident(dest_schema) || '.' || quote_ident(object)
           || ' AS ' || sq_data_type
           || ' INCREMENT BY ' || sq_increment_by
           || ' MINVALUE '     || sq_min_value
           || ' MAXVALUE '     || sq_max_value
           || ' START WITH '   || sq_start_value
           || ' RESTART '      || sq_min_value
           || ' CACHE '        || sq_cache_value
           || ' '              || sq_cycled || ' ;' ;

    IF ddl_only THEN
      RAISE INFO '%', qry;
    ELSE
      EXECUTE qry;
    END IF;

    buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
    IF include_recs THEN
      EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
    ELSE
      if ddl_only THEN
        RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
      ELSE
        EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
      END IF;

    END IF;
  END LOOP;
  RAISE NOTICE '   SEQUENCES cloned: %', LPAD(cnt::text, 5, ' ');

-- Create tables including partitioned ones (parent/children) and unlogged ones.  Order by is critical since child partition range logic is dependent on it.
  action := 'Tables';
  cnt := 0;
  -- SET search_path = '';
  -- We want objects used in table definitions to be taken from the new schema,
  -- however some objects may not have been created yet so we use source schema
  -- as source first and will reassign things to the new schema later.
  EXECUTE 'SET search_path = ' || quote_ident(source_schema);
  FOR tblname, relpersist, relispart, relknd, data_type  IN
    -- 2021-03-08 MJV #39 fix: change sql to get indicator of user-defined columns to issue warnings
    -- select c.relname, c.relpersistence, c.relispartition, c.relkind
    -- FROM pg_class c, pg_namespace n where n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and c.relkind in ('r','p') and 
    -- order by c.relkind desc, c.relname
    SELECT distinct c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type
    FROM pg_class c JOIN pg_namespace n ON (n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and c.relkind in ('r','p')) 
    LEFT JOIN information_schema.columns co ON (co.table_schema = n.nspname and co.table_name = c.relname and co.data_type = 'USER-DEFINED')
    ORDER BY c.relkind desc, c.relname
  LOOP
    cnt := cnt + 1;
    IF data_type = 'USER-DEFINED' THEN
        -- RAISE WARNING ' Table (%) has column(s) with user-defined types that will reference the source schema after they are created with the CREATE TABLE LIKE construct. Please modify after cloning.',tblname;
        RAISE WARNING ' Table (%) has column(s) with user-defined types so using get_table_ddl() instead of CREATE TABLE LIKE construct.',tblname;
    END IF;
    
    buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);
    buffer2 := '';
    IF relpersist = 'u' THEN
      buffer2 := 'UNLOGGED ';
    END IF;
    
    IF relknd = 'r' THEN
      IF ddl_only THEN
        IF data_type = 'USER-DEFINED' THEN      
          SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- RAISE INFO '%', buffer3;
        ELSE
          RAISE INFO '%', 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL)';
        END IF;

      ELSE
        IF data_type = 'USER-DEFINED' THEN            
          SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- RAISE INFO '%', buffer3;
          EXECUTE buffer3;
        ELSE
          EXECUTE 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL)';
        END IF;
      END IF;
    ELSIF relknd = 'p' THEN
      -- define parent table and assume child tables have already been created based on top level sort order.
      SELECT 'CREATE TABLE ' || quote_ident(dest_schema) || '.' || pc.relname || E'(\n' || string_agg(pa.attname || ' ' || pg_catalog.format_type(pa.atttypid, pa.atttypmod) || 
      coalesce(' DEFAULT ' || (SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid) FROM pg_catalog.pg_attrdef d  
      WHERE d.adrelid = pa.attrelid AND d.adnum = pa.attnum AND pa.atthasdef), '') || ' ' || CASE pa.attnotnull WHEN TRUE THEN 'NOT NULL' ELSE 'NULL' END, E',\n') || 
      coalesce((SELECT E',\n' || string_agg('CONSTRAINT ' || pc1.conname || ' ' || pg_get_constraintdef(pc1.oid), E',\n' ORDER BY pc1.conindid) 
      FROM pg_constraint pc1 WHERE pc1.conrelid = pa.attrelid), '') into buffer FROM pg_catalog.pg_attribute pa JOIN pg_catalog.pg_class pc ON pc.oid = pa.attrelid AND 
      pc.relname = quote_ident(tblname) JOIN pg_catalog.pg_namespace pn ON pn.oid = pc.relnamespace AND pn.nspname = quote_ident(source_schema) 
      WHERE pa.attnum > 0 AND NOT pa.attisdropped GROUP BY pn.nspname, pc.relname, pa.attrelid;
      
      -- append partition keyword to it
      SELECT pg_catalog.pg_get_partkeydef(c.oid::pg_catalog.oid) into buffer2 FROM pg_catalog.pg_class c  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace 
      WHERE c.relname = quote_ident(tblname) COLLATE pg_catalog.default AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default;
  
      -- RAISE NOTICE ' buffer = %   buffer2 = %',buffer, buffer2;
      qry := buffer || ') PARTITION BY ' || buffer2 || ';';
      IF ddl_only THEN
        RAISE INFO '%', qry;
      ELSE
        EXECUTE qry;
      END IF;

      -- loop for child tables and alter them to attach to parent for specific partition method.
      FOR aname, part_range, object IN
        SELECT quote_ident(dest_schema) || '.' || c1.relname as tablename, pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) as partrange, quote_ident(dest_schema) || '.' || c2.relname as object
        FROM pg_catalog.pg_class c1, pg_namespace n, pg_catalog.pg_inherits i, pg_class c2 WHERE n.nspname = quote_ident(source_schema) AND c1.relnamespace = n.oid AND c1.relkind = 'r' AND 
        c1.relispartition AND c1.oid=i.inhrelid AND i.inhparent = c2.oid AND c2.relnamespace = n.oid ORDER BY pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) = 'DEFAULT', c1.oid::pg_catalog.regclass::pg_catalog.text  
      LOOP
        qry := 'ALTER TABLE ONLY ' || object || ' ATTACH PARTITION ' || aname || ' ' || part_range || ';';
        IF ddl_only THEN
          RAISE INFO '%', qry;
        ELSE
          EXECUTE qry;
        END IF;
        
      END LOOP;    
    END IF;

    -- INCLUDING ALL creates new index names, we restore them to the old name.
    -- There should be no conflicts since they live in different schemas
    FOR ix_old_name, ix_new_name IN
      SELECT old.indexname, new.indexname
      FROM pg_indexes old, pg_indexes new
      WHERE old.schemaname = source_schema
        AND new.schemaname = dest_schema
        AND old.tablename = new.tablename
        AND old.tablename = tblname
        AND old.indexname <> new.indexname
        AND regexp_replace(old.indexdef, E'.*USING','') = regexp_replace(new.indexdef, E'.*USING','')
        ORDER BY old.indexname, new.indexname
    LOOP
      IF ddl_only THEN
        RAISE INFO '%', 'ALTER INDEX ' || quote_ident(dest_schema) || '.'  || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';';
      ELSE
        EXECUTE 'ALTER INDEX ' || quote_ident(dest_schema) || '.'  || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';';
      END IF;
    END LOOP;

    IF include_recs
      THEN
      -- Insert records from source table
      
      -- 2021-03-03  MJV FIX
      RAISE NOTICE 'Populating cloned table, %', tblname;
      buffer := dest_schema || '.' || quote_ident(tblname);
	  
      -- 2020/06/18 - Issue #31 fix: add "OVERRIDING SYSTEM VALUE" for IDENTITY columns marked as GENERATED ALWAYS.
      select count(*) into cnt from pg_class c, pg_attribute a, pg_namespace n  
	  where a.attrelid = c.oid and c.relname = quote_ident(tblname) and n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and a.attidentity = 'a';
      buffer3 := '';
      IF cnt > 0 THEN
          buffer3 := ' OVERRIDING SYSTEM VALUE';
      END IF;
      EXECUTE 'INSERT INTO ' || buffer || buffer3 || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ';';
    END IF;
  END LOOP;
  RAISE NOTICE '      TABLES cloned: %', LPAD(cnt::text, 5, ' ');

  --  add FK constraint
  action := 'FK Constraints';
  cnt := 0;
  SET search_path = '';
  FOR qry IN
    SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname)
                          || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || REPLACE(pg_get_constraintdef(ct.oid), 'REFERENCES ' ||quote_ident(source_schema), 'REFERENCES ' || quote_ident(dest_schema)) || ';'
      FROM pg_constraint ct
      JOIN pg_class rn ON rn.oid = ct.conrelid
     WHERE connamespace = src_oid
       AND rn.relkind = 'r'
       AND ct.contype = 'f'
  LOOP
    cnt := cnt + 1;
    IF ddl_only THEN
      RAISE INFO '%', qry;
    ELSE
      EXECUTE qry;
    END IF;
  END LOOP;
  EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
  RAISE NOTICE '       FKEYS cloned: %', LPAD(cnt::text, 5, ' ');

-- Create views
  action := 'Views';
  -- MJV FIX #43: also had to reset search_path from source schema to empty.
  SET search_path = '';
  cnt := 0;
  FOR object IN
    SELECT table_name::text,
           view_definition
      FROM information_schema.views
     WHERE table_schema = quote_ident(source_schema)

  LOOP
    cnt := cnt + 1;
    buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
    -- MJV FIX: #43
    -- SELECT view_definition INTO v_def
    SELECT REPLACE(view_definition, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO v_def 
      FROM information_schema.views
     WHERE table_schema = quote_ident(source_schema)
       AND table_name = quote_ident(object);

    -- NOTE: definition already includes the closing statement semicolon
    IF ddl_only THEN
      -- RAISE INFO '%', 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def || ';' ;
      RAISE INFO '%', 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def;
    ELSE
    -- EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def || ';' ;
    EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def;
    END IF;
  END LOOP;
  RAISE NOTICE '       VIEWS cloned: %', LPAD(cnt::text, 5, ' ');

  -- Create Materialized views
    action := 'Mat. Views';
    cnt := 0;
    -- RAISE INFO 'mat views start1';
    FOR object, v_def IN
      SELECT matviewname::text, replace(definition,';','') FROM pg_catalog.pg_matviews WHERE schemaname = quote_ident(source_schema)
    LOOP
      cnt := cnt + 1;
      buffer := dest_schema || '.' || quote_ident(object);
      IF include_recs THEN
        EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || v_def || ' WITH DATA;' ;
      ELSE
        IF ddl_only THEN
          RAISE INFO '%', 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || v_def || ' WITH NO DATA;' ;
        ELSE
          EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || v_def || ' WITH NO DATA;' ;
        END IF;
      END IF;
      SELECT coalesce(obj_description(oid), '') into adef from pg_class where relkind = 'm' and relname = object;
      IF adef <> '' THEN
        IF ddl_only THEN
          RAISE INFO '%', 'COMMENT ON MATERIALIZED VIEW ' || quote_ident(dest_schema) || '.' || object || ' IS ''' || adef || ''';';
        ELSE
          EXECUTE 'COMMENT ON MATERIALIZED VIEW ' || quote_ident(dest_schema) || '.' || object || ' IS ''' || adef || ''';';
        END IF;	 		 
      END IF;

      FOR aname, adef IN
        SELECT indexname, replace(indexdef, quote_ident(source_schema), quote_ident(dest_schema)) as newdef FROM pg_indexes where schemaname = quote_ident(source_schema) and tablename = object order by indexname
      LOOP
        IF ddl_only THEN
          RAISE INFO '%', adef || ';';
        ELSE
          EXECUTE adef || ';';
        END IF;
      END LOOP;

    END LOOP;
    RAISE NOTICE '   MAT VIEWS cloned: %', LPAD(cnt::text, 5, ' ');


-- Create functions
  action := 'Functions';
  cnt := 0;
  -- MJV FIX per issue# 34
  -- SET search_path = '';
  -- We want to use objects in the new schema by default.
  EXECUTE 'SET search_path = ' || quote_ident(dest_schema);

  -- First pass to create prototype functions for function inter-dependencies.
  FOR func_oid IN
    SELECT oid
      FROM pg_proc
     WHERE pronamespace = src_oid
       AND prokind != 'a'
  LOOP
    SELECT pg_get_functiondef(func_oid) INTO qry;
    -- Replace function body by an empty body in plpgsql language.
    SELECT regexp_replace(qry, '\sLANGUAGE\s+''?\w+''?(.*?)\sAS\s+.*', ' LANGUAGE plpgsql \1 AS $_$BEGIN END;$_$;', 'i') INTO dest_qry;
    SELECT replace(dest_qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO dest_qry;
    IF NOT ddl_only THEN
      EXECUTE dest_qry;
    END IF;
  END LOOP;

  -- Create aggregate functions.
  FOR func_oid IN
    SELECT oid
    FROM pg_proc
    WHERE
      pronamespace = src_oid
      AND prokind = 'a'
  LOOP
    cnt := cnt + 1;
    SELECT
      'CREATE AGGREGATE '
      || dest_schema
      || '.'
      || p.proname
      || '('
      || format_type(a.aggtranstype, NULL)
      || ') (sfunc = '
      || regexp_replace(a.aggtransfn::text, '(^|\W)' || quote_ident(source_schema) || '\.', '\1' || quote_ident(dest_schema) || '.')
      || ', stype = '
      || format_type(a.aggtranstype, NULL)
      || CASE
          WHEN op.oprname IS NULL THEN ''
          ELSE ', sortop = ' || op.oprname
        END
      || CASE
          WHEN a.agginitval IS NULL THEN ''
          ELSE ', initcond = ''' || a.agginitval || ''''
        END
      || ')'
    INTO dest_qry
    FROM pg_proc p
      JOIN pg_aggregate a ON a.aggfnoid = p.oid
      LEFT JOIN pg_operator op ON op.oid = a.aggsortop
    WHERE p.oid = func_oid;
    EXECUTE dest_qry;
  END LOOP;

  -- Second pass to add full function definition.
  FOR func_oid IN
    SELECT oid
      FROM pg_proc
     WHERE pronamespace = src_oid
       AND prokind != 'a'
  LOOP
    cnt := cnt + 1;
    SELECT pg_get_functiondef(func_oid) INTO qry;
    SELECT regexp_replace(qry, '^\s*CREATE\s+FUNCTION', 'CREATE OR REPLACE FUNCTION', 'i') INTO dest_qry;
    SELECT replace(dest_qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO dest_qry;
    IF ddl_only THEN
      RAISE INFO '%', dest_qry;
    ELSE
      EXECUTE dest_qry;
    END IF;

  END LOOP;
  
  -- Third pass on tables to update columns and indexes to make them use the new
  -- schema functions.
  EXECUTE 'SET search_path = ' || quote_ident(dest_schema);
  FOR tblname  IN
    SELECT DISTINCT c.relname
    FROM pg_class c
      JOIN pg_namespace n ON (
        n.oid = c.relnamespace
        AND n.nspname = quote_ident(source_schema)
        AND c.relkind = 'r'
      )
    ORDER BY c.relname
  LOOP
    buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);

    -- Update columns defaults.
    FOR column_, default_ IN
      SELECT column_name::text,
             regexp_replace(column_default::text, '(^|\W)' || quote_ident(source_schema) || '\.', '\1' || quote_ident(dest_schema) || '.')
        FROM information_schema.COLUMNS
       WHERE table_schema = source_schema
         AND TABLE_NAME = tblname
         AND column_default ~* ('(^|\W)' || quote_ident(source_schema) || '\.')
    LOOP
      IF ddl_only THEN
        -- May need to come back and revisit this since previous sql will not return anything since no schema as created!
        RAISE INFO '%', 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || column_ || ' SET DEFAULT ' || default_ || ';';
      ELSE
        EXECUTE 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || column_ || ' SET DEFAULT ' || default_;
      END IF;
    END LOOP;

    -- Update indexes.
    FOR buffer IN
      SELECT indexdef
      FROM pg_indexes
      WHERE
        tablename = tblname
        AND schemaname = dest_schema
    LOOP
      -- Only change indexes with the old schema name.
      IF buffer ~* ('\W' || quote_ident(source_schema) || '\.') THEN
        IF ddl_only THEN
          -- Drop previous definition.
          RAISE INFO '%', regexp_replace(buffer::text, '^\s*CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?([\w\$]+)\s+ON\s+.+$', 'DROP INDEX ' || quote_ident(dest_schema) || '.\1;');
          -- Recreate it.
          RAISE INFO '%', regexp_replace(buffer::text, '(\W)' || quote_ident(source_schema) || '\.', '\1' || quote_ident(dest_schema) || '.');
        ELSE
          -- Drop previous definition.
          EXECUTE regexp_replace(buffer::text, '^\s*CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?([\w\$]+)\s+ON\s+.+$', 'DROP INDEX ' || quote_ident(dest_schema) || '.\1;');
          -- Recreate it.
          EXECUTE regexp_replace(buffer::text, '(\W)' || quote_ident(source_schema) || '\.', '\1' || quote_ident(dest_schema) || '.');
        END IF;
      END IF;
    END LOOP;

  END LOOP;
  RAISE NOTICE '   FUNCTIONS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: Create Triggers

  -- MJV FIX: #38
  -- EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
  set search_path = '';
  
  action := 'Triggers';
  cnt := 0;
  FOR arec IN
    -- SELECT trigger_schema, trigger_name, event_object_table, action_order, action_condition, action_statement, action_orientation, action_timing, array_to_string(array_agg(event_manipulation::text), ' OR '),
    -- 'CREATE TRIGGER ' || trigger_name || ' ' || action_timing || ' ' || array_to_string(array_agg(event_manipulation::text), ' OR ') || ' ON ' || quote_ident(dest_schema) || '.' || event_object_table ||
    -- ' FOR EACH ' || action_orientation || ' ' || action_statement || ';' as TRIG_DDL
    -- FROM information_schema.triggers where trigger_schema = quote_ident(source_schema) GROUP BY 1,2,3,4,5,6,7,8
    -- 2021-03-08 MJV FIX: #38 fixed issue where source schema specified for executed trigger function action    
    -- SELECT trigger_schema, trigger_name, event_object_table, action_order, action_condition, action_statement, action_orientation, action_timing, array_to_string(array_agg(event_manipulation::text), ' OR '),
    -- 'CREATE TRIGGER ' || trigger_name || ' ' || action_timing || ' ' || array_to_string(array_agg(event_manipulation::text), ' OR ') || ' ON ' || quote_ident(dest_schema) || '.' || event_object_table ||
    -- ' FOR EACH ' || action_orientation || ' ' || REPLACE (action_statement, quote_ident(source_schema), quote_ident(dest_schema)) || ';' as TRIG_DDL
    -- FROM information_schema.triggers where trigger_schema = quote_ident(source_schema) GROUP BY 1,2,3,4,5,6,7,8
    -- 2021-03-09 MJV FIX: #40 fixed sql to get the def using pg_get_triggerdef() sql
    SELECT n.nspname, c.relname, t.tgname, p.proname, REPLACE(pg_get_triggerdef(t.oid), quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') || ';' AS trig_ddl FROM pg_trigger t, pg_class c, pg_namespace n, pg_proc p
    WHERE n.nspname = quote_ident(source_schema) and n.oid = c.relnamespace and c.relkind in ('r','p') and n.oid = p.pronamespace and c.oid = t.tgrelid and p.oid = t.tgfoid ORDER BY c.relname, t.tgname
  LOOP
    BEGIN
      cnt := cnt + 1;
      IF ddl_only THEN
        RAISE INFO '%', arec.trig_ddl;
      ELSE
        EXECUTE arec.trig_ddl;
      END IF;

    END;
  END LOOP;
  RAISE NOTICE '    TRIGGERS cloned: %', LPAD(cnt::text, 5, ' ');

  -- ---------------------
  -- MV: Permissions: Defaults
  -- ---------------------
  EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
  action := 'PRIVS: Defaults';
  cnt := 0;
  FOR arec IN
    SELECT pg_catalog.pg_get_userbyid(d.defaclrole) AS "owner", n.nspname AS schema,
    CASE d.defaclobjtype WHEN 'r' THEN 'table' WHEN 'S' THEN 'sequence' WHEN 'f' THEN 'function' WHEN 'T' THEN 'type' WHEN 'n' THEN 'schema' END AS atype,
    d.defaclacl as defaclacl, pg_catalog.array_to_string(d.defaclacl, ',') as defaclstr
    FROM pg_catalog.pg_default_acl d LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = d.defaclnamespace) WHERE n.nspname IS NOT NULL and n.nspname = quote_ident(source_schema) ORDER BY 3, 2, 1
  LOOP
    BEGIN
      -- RAISE NOTICE 'owner=%  type=%  defaclacl=%  defaclstr=%', arec.owner, arec.atype, arec.defaclacl, arec.defaclstr;

      FOREACH aclstr IN ARRAY arec.defaclacl
      LOOP
          cnt := cnt + 1;
          -- RAISE NOTICE 'aclstr=%', aclstr;
          -- break up into grantor, grantee, and privs, mydb_update=rwU/mydb_owner
          SELECT split_part(aclstr, '=',1) INTO grantee;
          SELECT split_part(aclstr, '=',2) INTO grantor;
          SELECT split_part(grantor, '/',1) INTO privs;
          SELECT split_part(grantor, '/',2) INTO grantor;
          -- RAISE NOTICE 'grantor=%  grantee=%  privs=%', grantor, grantee, privs;

          IF arec.atype = 'function' THEN
            -- Just having execute is enough to grant all apparently.
            buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ALL ON FUNCTIONS TO "' || grantee || '";';
            IF ddl_only THEN
              RAISE INFO '%', buffer;
            ELSE
              EXECUTE buffer;
            END IF;

          ELSIF arec.atype = 'sequence' THEN
            IF POSITION('r' IN privs) > 0 AND POSITION('w' IN privs) > 0 AND POSITION('U' IN privs) > 0 THEN
              -- arU is enough for all privs
              buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ALL ON SEQUENCES TO "' || grantee || '";';
              IF ddl_only THEN
                RAISE INFO '%', buffer;
              ELSE
                EXECUTE buffer;
              END IF;

            ELSE
              -- have to specify each priv individually
              buffer2 := '';
              IF POSITION('r' IN privs) > 0 THEN
                    buffer2 := 'SELECT';
              END IF;
              IF POSITION('w' IN privs) > 0 THEN
                IF buffer2 = '' THEN
                  buffer2 := 'UPDATE';
                ELSE
                  buffer2 := buffer2 || ', UPDATE';
                END IF;
              END IF;
              IF POSITION('U' IN privs) > 0 THEN
                    IF buffer2 = '' THEN
                  buffer2 := 'USAGE';
                ELSE
                  buffer2 := buffer2 || ', USAGE';
                END IF;
              END IF;
              buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ' || buffer2 || ' ON SEQUENCES TO "' || grantee || '";';
              IF ddl_only THEN
                RAISE INFO '%', buffer;
              ELSE
                EXECUTE buffer;
              END IF;
            END IF;
			
          ELSIF arec.atype = 'table' THEN
            -- do each priv individually, jeeeesh!
            buffer2 := '';
            IF POSITION('a' IN privs) > 0 THEN
              buffer2 := 'INSERT';
            END IF;
            IF POSITION('r' IN privs) > 0 THEN
              IF buffer2 = '' THEN
                buffer2 := 'SELECT';
              ELSE
                buffer2 := buffer2 || ', SELECT';
              END IF;
            END IF;
            IF POSITION('w' IN privs) > 0 THEN
              IF buffer2 = '' THEN
                buffer2 := 'UPDATE';
              ELSE
                buffer2 := buffer2 || ', UPDATE';
              END IF;
            END IF;
            IF POSITION('d' IN privs) > 0 THEN
              IF buffer2 = '' THEN
                buffer2 := 'DELETE';
              ELSE
                buffer2 := buffer2 || ', DELETE';
              END IF;
            END IF;
            IF POSITION('t' IN privs) > 0 THEN
              IF buffer2 = '' THEN
                buffer2 := 'TRIGGER';
              ELSE
                buffer2 := buffer2 || ', TRIGGER';
              END IF;
            END IF;
            IF POSITION('T' IN privs) > 0 THEN
              IF buffer2 = '' THEN
                buffer2 := 'TRUNCATE';
              ELSE
                buffer2 := buffer2 || ', TRUNCATE';
              END IF;
            END IF;
            buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ' || buffer2 || ' ON TABLES TO "' || grantee || '";';
            IF ddl_only THEN
              RAISE INFO '%', buffer;
            ELSE
              EXECUTE buffer;
            END IF;

          ELSIF arec.atype = 'type' THEN
            IF POSITION('r' IN privs) > 0 AND POSITION('w' IN privs) > 0 AND POSITION('U' IN privs) > 0 THEN
              -- arU is enough for all privs
              buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ALL ON TYPES TO "' || grantee || '";';
              IF ddl_only THEN
                RAISE INFO '%', buffer;
              ELSE
                EXECUTE buffer;
              END IF;
			ELSIF POSITION('U' IN privs) THEN
              buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT USAGE ON TYPES TO "' || grantee || '";';
              IF ddl_only THEN
                RAISE INFO '%', buffer;
              ELSE
                EXECUTE buffer;
              END IF;			
			ELSE  
              RAISE WARNING 'Unhandled TYPE Privs:: type=%  privs=%  owner=%   defaclacl=%  defaclstr=%  grantor=%  grantee=% ', arec.atype, privs, arec.owner, arec.defaclacl, arec.defaclstr, grantor, grantee;
            END IF;

          ELSE
		      RAISE WARNING 'Unhandled Privs:: type=%  privs=%  owner=%   defaclacl=%  defaclstr=%  grantor=%  grantee=% ', arec.atype, privs, arec.owner, arec.defaclacl, arec.defaclstr, grantor, grantee;
          END IF;
      END LOOP;
    END;
  END LOOP;

  RAISE NOTICE '  DFLT PRIVS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: PRIVS: schema
  -- crunchy data extension, check_access
  -- SELECT role_path, base_role, as_role, objtype, schemaname, objname, array_to_string(array_agg(privname),',') as privs  FROM all_access()
  -- WHERE base_role != CURRENT_USER and objtype = 'schema' and schemaname = 'public' group by 1,2,3,4,5,6;

  action := 'PRIVS: Schema';
  cnt := 0;
  FOR arec IN
    SELECT 'GRANT ' || p.perm::perm_type || ' ON SCHEMA ' || quote_ident(dest_schema) || ' TO "' || r.rolname || '";' as schema_ddl
    FROM pg_catalog.pg_namespace AS n CROSS JOIN pg_catalog.pg_roles AS r CROSS JOIN (VALUES ('USAGE'), ('CREATE')) AS p(perm)
    WHERE n.nspname = quote_ident(source_schema) AND NOT r.rolsuper AND has_schema_privilege(r.oid, n.oid, p.perm) order by r.rolname, p.perm::perm_type
  LOOP
    BEGIN
      cnt := cnt + 1;
      IF ddl_only THEN
        RAISE INFO '%', arec.schema_ddl;
      ELSE
        EXECUTE arec.schema_ddl;
      END IF;

    END;
  END LOOP;
  RAISE NOTICE 'SCHEMA PRIVS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: PRIVS: sequences
  action := 'PRIVS: Sequences';
  cnt := 0;
  FOR arec IN
    SELECT 'GRANT ' || p.perm::perm_type || ' ON ' || quote_ident(dest_schema) || '.' || t.relname::text || ' TO "' || r.rolname || '";' as seq_ddl
    FROM pg_catalog.pg_class AS t CROSS JOIN pg_catalog.pg_roles AS r CROSS JOIN (VALUES ('SELECT'), ('USAGE'), ('UPDATE')) AS p(perm)
    WHERE t.relnamespace::regnamespace::name = quote_ident(source_schema) AND t.relkind = 'S'  AND NOT r.rolsuper AND has_sequence_privilege(r.oid, t.oid, p.perm)
  LOOP
    BEGIN
      cnt := cnt + 1;
      IF ddl_only THEN
        RAISE INFO '%', arec.seq_ddl;
      ELSE
        EXECUTE arec.seq_ddl;
      END IF;

    END;
  END LOOP;
  RAISE NOTICE '  SEQ. PRIVS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: PRIVS: functions
  action := 'PRIVS: Functions/Procedures';
  cnt := 0;
  -- EXECUTE 'SET search_path = ' || quote_ident(dest_schema) ;
  set search_path = '';
  -- RAISE NOTICE 'source_schema=%  dest_schema=%',source_schema, dest_schema;
  FOR arec IN
    -- 2021-03-05 MJV FIX: issue#35: caused exception in some functions with parameters and gave privileges to other users that should not have gotten them.
    -- SELECT 'GRANT EXECUTE ON FUNCTION ' || quote_ident(dest_schema) || '.' || replace(regexp_replace(f.oid::regprocedure::text, '^((("[^"]*")|([^"][^.]*))\.)?', ''), source_schema, dest_schema) || ' TO "' || r.rolname || '";' as func_ddl 
    -- FROM pg_catalog.pg_proc f CROSS JOIN pg_catalog.pg_roles AS r WHERE f.pronamespace::regnamespace::name = quote_ident(source_schema) AND NOT r.rolsuper AND has_function_privilege(r.oid, f.oid, 'EXECUTE')
    -- order by regexp_replace(f.oid::regprocedure::text, '^((("[^"]*")|([^"][^.]*))\.)?', '')
    
    -- 2021-03-05 MJV FIX: issue#37: defaults cause problems, use system function that returns args WITHOUT DEFAULTS
    SELECT 'GRANT ' || rp.privilege_type || ' ON ' || r.routine_type || ' ' || quote_ident(dest_schema) || '.' || rp.routine_name || ' (' || pg_get_function_identity_arguments(p.oid) || ') TO ' || string_agg(distinct rp.grantee, ',') || ';' as func_dcl
    FROM information_schema.routine_privileges rp, information_schema.routines r, pg_proc p, pg_namespace n 
    where rp.routine_schema = quote_ident(source_schema) and rp.is_grantable = 'YES' and rp.routine_schema = r.routine_schema and rp.routine_name = r.routine_name and rp.routine_schema = n.nspname and n.oid = p.pronamespace and p.proname = r.routine_name 
    group by rp.privilege_type, r.routine_type, rp.routine_name, pg_get_function_identity_arguments(p.oid)
  LOOP
    BEGIN
      cnt := cnt + 1;
      IF ddl_only THEN
        RAISE INFO '%', arec.func_dcl;
      ELSE
        EXECUTE arec.func_dcl;
      END IF;

    END;
  END LOOP;
  EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
  RAISE NOTICE '  FUNC PRIVS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: PRIVS: tables
  action := 'PRIVS: Tables';
  -- regular, partitioned, and foreign tables plus view and materialized view permissions. TODO: implement foreign table defs.
  cnt := 0;
  FOR arec IN
    -- SELECT 'GRANT ' || p.perm::perm_type || CASE WHEN t.relkind in ('r', 'p', 'f') THEN ' ON TABLE ' WHEN t.relkind in ('v', 'm')  THEN ' ON ' END || quote_ident(dest_schema) || '.' || t.relname::text || ' TO "' || r.rolname || '";' as tbl_ddl,
    -- has_table_privilege(r.oid, t.oid, p.perm) AS granted, t.relkind
    -- FROM pg_catalog.pg_class AS t CROSS JOIN pg_catalog.pg_roles AS r CROSS JOIN (VALUES (TEXT 'SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) AS p(perm)
    -- WHERE t.relnamespace::regnamespace::name = quote_ident(source_schema)  AND t.relkind in ('r', 'p', 'f', 'v', 'm')  AND NOT r.rolsuper AND has_table_privilege(r.oid, t.oid, p.perm) order by t.relname::text, t.relkind
    -- 2021-03-05  MJV FIX: Fixed Issue#36 for tables
    SELECT c.relkind, 'GRANT ' || tb.privilege_type || CASE WHEN c.relkind in ('r', 'p') THEN ' ON TABLE ' WHEN c.relkind in ('v', 'm')  THEN ' ON ' END || 
    quote_ident(dest_schema) || '.' || tb.table_name || ' TO ' || string_agg(tb.grantee, ',') || ';' as tbl_dcl 
    FROM information_schema.table_privileges tb, pg_class c, pg_namespace n where tb.table_schema = quote_ident(source_schema) and tb.table_name = c.relname and c.relkind in ('r', 'p', 'v', 'm') and 
    c.relnamespace = n.oid and n.nspname = quote_ident(source_schema) group by c.relkind, tb.privilege_type, tb.table_schema, tb.table_name
  LOOP
    BEGIN
      cnt := cnt + 1;
      -- RAISE NOTICE 'ddl=%', arec.tbl_dcl;
      -- Issue#46. Fixed reference to invalid record name (tbl_ddl --> tbl_dcl).
      IF arec.relkind = 'f' THEN
        RAISE WARNING 'Foreign tables are not currently implemented, so skipping privs for them. ddl=%', arec.tbl_dcl;
      ELSE
          IF ddl_only THEN
              RAISE INFO '%', arec.tbl_dcl;
          ELSE
              EXECUTE arec.tbl_dcl;
          END IF;
    END IF;
    END;
  END LOOP;
  RAISE NOTICE ' TABLE PRIVS cloned: %', LPAD(cnt::text, 5, ' ');

  -- Set the search_path back to what it was before
  -- MJV FIX: Issue#47
  -- EXECUTE 'SET search_path = ' || src_path_old;
  EXECUTE 'SET search_path = ' || quote_literal(src_path_old);  
  

  EXCEPTION
     WHEN others THEN
     BEGIN
         GET STACKED DIAGNOSTICS v_diag1 = MESSAGE_TEXT, v_diag2 = PG_EXCEPTION_DETAIL, v_diag3 = PG_EXCEPTION_HINT, v_diag4 = RETURNED_SQLSTATE, v_diag5 = PG_CONTEXT, v_diag6 = PG_EXCEPTION_CONTEXT;
         -- v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1 || ' .' || v_diag2 || ' .' || v_diag3;
         v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1;
         RAISE EXCEPTION 'Action: %  Diagnostics: %',action, v_ret;
         -- Set the search_path back to what it was before
         -- MJV FIX: Issue#47
         -- EXECUTE 'SET search_path = ' || src_path_old;
         EXECUTE 'SET search_path = ' || quote_literal(src_path_old);           
         RETURN;
     END;

RETURN;
END;

$BODY$
  LANGUAGE plpgsql VOLATILE  COST 100;
-- ALTER FUNCTION public.clone_schema(text, text, boolean, boolean) OWNER TO postgres;
