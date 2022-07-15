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
-- 2021-07-21  MJV FIX: Fixed Issue#47 Fixed resetting search path to what it was before.  Thanks to dpmillerau for this fix.
-- 2022-03-01  MJV FIX: Fixed Issue#61 Fixed more search_path problems. Modified get_table_ddl() to hard code search_path to public. Using set_config() for empty string instead of trying to set empty string directly and incorrectly.
-- 2022-03-01  MJV FIX: Fixed Issue#62 Added comments for indexes only (Thanks to @guignonv).  Still need to add comments for other objects.
-- 2022-03-24  MJV FIX: Fixed Issue#63 Use last used value for sequence not the start value
-- 2022-03-24  MJV FIX: Fixed Issue#59 Implement Rules
-- 2022-03-26  MJV FIX: Fixed Issue#65 Check column availability in selecting query to use for pg_proc table.  Also do some explicit datatype mappings for certain aggregate functions.  Also fixed inheritance derived tables.
-- 2022-03-31  MJV FIX: Fixed Issue#66 Implement Security Policies for RLS
-- 2022-04-02  MJV FIX: Fixed Issue#62 Fixed all comments and reworked the way we generate index comments by @guignonv
-- 2022-04-02  MJV FIX: Fixed Issue#67 Reworked get_table_ddl() so we are not dependent on outside function, pg_get_tabledef().
-- 2022-04-02  MJV FIX: Fixed Issue#42 Fixed copying rows logic with exception of tables with user-defined datatypes in them that have to be done manually, documented in README.
-- 2022-05-01  MJV FIX: Fixed Issue#53 Applied coding style fixes, using pgFormatter as basis for SQL.
-- 2022-05-02  MJV FIX: Fixed Issue#72 Remove original schema references from materialized view definition
-- 2022-05-14  MJV FIX: Fixed Issue#73 Fix dependency order for views depending on other views. Also removed duplicate comment logic for views.
-- 2022-06-12  MJV FIX: Fixed Issue#74 Change comments ddl from source_schema to dest_schema. Policies fix using quote_literal(d.description) instead of hard-coded ticks and escape ticks.
-- 2022-06-13  MJV FIX: Fixed Issue#75 Rows were not being copied correctly for parents.  Needed to move copy rows logic to end, after all DDL is done.
-- 2022-06-15  MJV FIX: Fixed Issue#76 RLS is not being enabled for cloned tables.  Enable it right after the policy for the table is created
-- 2022-06-16  MJV FIX: Fixed Issue#78 Fix case-sensitive object names by using quote_ident() all over the place. Also added restriction to not allow case-sensitive target schemas.
-- 2022-06-16  MJV FIX: Fixed Issue#78 Also, since we deferred row copies until the end, we must also defer foreign key constraints to the end as well. 
-- 2022-06-18  MJV FIX: Fixed Issue#79 Fix copying of rows in tables with user-defined column datatypes using COPY method.
-- 2022-06-29  MJV FIX: Fixed Issue#80 Fix copying of rows reported error due to arrays not being initialized properly.
-- 2022-07-15  MJV FIX: Fixed Issue#81 Fix COPY import format for handling NULLs correctly.
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
    v_src_path_old text := '';
    v_src_path_new text := '';
    v_dummy text;
    v_partbound text;
    v_pgversion int;
    v_parent     text := '';
    v_relopts text := '';
    v_tablespace text;
    v_partition_key text := '';
    v_temp       text;
    bPartitioned bool := False;
    bInheritance bool := False;
    bRelispartition bool;

  BEGIN
    SELECT c.oid, (
        SELECT setting
        FROM pg_settings
        WHERE name = 'server_version_num') INTO v_table_oid, v_pgversion
    FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r', 'p')
        AND c.relname = in_table
        AND n.nspname = in_schema;

    IF (v_table_oid IS NULL) THEN
      RAISE EXCEPTION 'table does not exist';
    END IF;

    -- get user-defined tablespaces if applicable
    SELECT TABLESPACE INTO v_temp
    FROM pg_tables
    WHERE schemaname = in_schema
        AND tablename = in_table
        AND TABLESPACE IS NOT NULL;

    IF v_tablespace IS NULL THEN
      v_tablespace := 'TABLESPACE pg_default';
    ELSE
      v_tablespace := 'TABLESPACE ' || v_temp;
    END IF;

    -- also see if there are any SET commands for this table, ie, autovacuum_enabled=off, fillfactor=70
    WITH relopts AS (
        SELECT unnest(c.reloptions) relopts
        FROM pg_class c, pg_namespace n
        WHERE n.nspname = in_schema
            AND n.oid = c.relnamespace
            AND c.relname = in_table
    )
    SELECT string_agg(r.relopts, ', ') AS relopts INTO v_temp
    FROM relopts r;

    IF v_temp IS NULL THEN
      v_relopts := '';
    ELSE
      v_relopts := ' WITH (' || v_temp || ')';
    END IF;

    -- Issue#61 FIX: set search_path = public before we do anything to force explicit schema qualification but dont forget to set it back before exiting...
    SELECT setting INTO v_src_path_old
    FROM pg_settings
    WHERE name = 'search_path';

    SELECT REPLACE(REPLACE(setting, '"$user"', '$user'), '$user', '"$user"') INTO v_src_path_old
    FROM pg_settings
    WHERE name = 'search_path';

    EXECUTE 'SET search_path = "public"';
    SELECT setting INTO v_src_path_new
    FROM pg_settings
    WHERE name = 'search_path';

    -- grab the oid of the table; https://www.postgresql.org/docs/8.3/catalog-pg-class.html
    SELECT c.oid INTO v_table_oid
    FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE 1 = 1
        AND c.relkind = 'r'
        AND c.relname = in_table
        AND n.nspname = in_schema;

    IF (v_table_oid IS NULL) THEN
      -- Dont give up yet.  It might be a partitioned table
      SELECT c.oid INTO v_table_oid
      FROM pg_catalog.pg_class c
          LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE 1 = 1
          AND c.relkind = 'p'
          AND c.relname = in_table
          AND n.nspname = in_schema;

      IF (v_table_oid IS NULL) THEN
        RAISE EXCEPTION 'table does not exist';
      END IF;
      bPartitioned := True;
    END IF;

    IF v_pgversion < 100000 THEN
      SELECT c2.relname parent INTO v_parent
      FROM pg_class c1, pg_namespace n, pg_inherits i, pg_class c2
      WHERE n.nspname = in_schema
          AND n.oid = c1.relnamespace
          AND c1.relname = in_table
          AND c1.oid = i.inhrelid
          AND i.inhparent = c2.oid
          AND c1.relkind = 'r';

      IF (v_parent IS NOT NULL) THEN
        bPartitioned := True;
        bInheritance  := True;
      END IF;
    ELSE
      SELECT c2.relname parent, c1.relispartition, pg_get_expr(c1.relpartbound, c1.oid, TRUE) INTO v_parent, bRelispartition, v_partbound
      FROM pg_class c1, pg_namespace n, pg_inherits i, pg_class c2
      WHERE n.nspname = in_schema
          AND n.oid = c1.relnamespace
          AND c1.relname = in_table
          AND c1.oid = i.inhrelid
          AND i.inhparent = c2.oid
          AND c1.relkind = 'r';

      IF (v_parent IS NOT NULL) THEN
        bPartitioned   := True;
        IF bRelispartition THEN
          bInheritance := False;
        ELSE
          bInheritance := True;
        END IF;
      END IF;
    END IF;

    -- RAISE NOTICE 'version=%  schema=%  parent=%  relopts=%  tablespace=%  partitioned=%  inherited=%  relispartition=%',v_pgversion, in_schema, v_parent, v_relopts, v_tablespace, bPartitioned, bInheritance, bRelispartition;

    -- start the create definition
    v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || ' (' || E'\n';

    -- define all of the columns in the table; https://stackoverflow.com/a/8153081/3068233
    FOR v_colrec IN
      SELECT c.column_name, c.data_type, c.udt_name, c.character_maximum_length, c.is_nullable, c.column_default, c.numeric_precision, c.numeric_scale, c.is_identity, c.identity_generation
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

    -- end the create table def but add inherits clause if valid
    IF bPartitioned and bInheritance THEN
      v_table_ddl := v_table_ddl || ') INHERITS (' || in_schema || '.' || v_parent || ') ' || v_relopts || ' ' || v_tablespace || ';' || E'\n';
    ELSEIF v_pgversion >= 100000 AND bPartitioned and NOT bInheritance THEN
      -- See if this is a partitioned table (pg_class.relkind = 'p') and add the partitioned key
      SELECT pg_get_partkeydef (c1.oid) AS partition_key INTO v_partition_key
      FROM pg_class c1
          JOIN pg_namespace n ON (n.oid = c1.relnamespace)
          LEFT JOIN pg_partitioned_table p ON (c1.oid = p.partrelid)
      WHERE n.nspname = in_schema
          AND n.oid = c1.relnamespace
          AND c1.relname = in_table
          AND c1.relkind = 'p';
    END IF;

    IF v_partition_key IS NOT NULL AND v_partition_key <> '' THEN
      -- add partition clause
      -- NOTE:  cannot specify default tablespace for partitioned relations
      v_table_ddl := v_table_ddl || ') PARTITION BY ' || v_partition_key || ';' || E'\n';
    ELSEIF bPartitioned AND not bInheritance THEN
      IF v_relopts <> '' THEN
        v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || ' PARTITION OF ' || in_schema || '.' || v_parent || ' ' || v_partbound || v_relopts || ' ' || v_tablespace || '; ' || E'\n';
      ELSE
        v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || ' PARTITION OF ' || in_schema || '.' || v_parent || ' ' || v_partbound || ' ' || v_tablespace || '; ' || E'\n';
      END IF;
    ELSEIF bPartitioned and bInheritance THEN
      -- we already did this above
      v_table_ddl := v_table_ddl;
    ELSEIF v_relopts <> '' THEN
      v_table_ddl := v_table_ddl || ') ' || v_relopts || ' ' || v_tablespace || ';' || E'\n';
    ELSE
      v_table_ddl := v_table_ddl || ') ' || v_tablespace || ';' || E'\n';
    END IF;

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

    -- reset search_path back to what it was
    IF v_src_path_old = '' THEN
      SELECT set_config('search_path', '', false) into v_dummy;
    ELSE
      EXECUTE 'SET search_path = ' || v_src_path_old;
    END IF;

    -- return the ddl
    RETURN v_table_ddl;
  END;
$$;


-- Function: clone_schema(text, text, boolean, boolean, boolean)
-- DROP FUNCTION clone_schema(text, text, boolean, boolean, boolean);

DROP FUNCTION IF EXISTS public.clone_schema(text, text, boolean, boolean);
CREATE OR REPLACE FUNCTION public.clone_schema(
    source_schema text,
    dest_schema text,
    include_recs boolean,
    ddl_only     boolean,
    verbose_     boolean DEFAULT False)
  RETURNS void AS
$BODY$

--  This function will clone all sequences, tables, data, views & functions from any existing schema to a new one
-- SAMPLE CALL:
-- SELECT clone_schema('sample', 'sample_clone2', True, False, False);

DECLARE
  src_oid          oid;
  tbl_oid          oid;
  func_oid         oid;
  object           text;
  buffer           text;
  buffer2          text;
  buffer3          text;
  srctbl           text;
  aname            text;
  default_         text;
  column_          text;
  qry              text;
  ix_old_name      text;
  ix_new_name      text;
  relpersist       text;
  bRelispart       bool;
  bChild           bool;
  relknd           text;
  data_type        text;
  ocomment         text;
  adef             text;
  dest_qry         text;
  v_def            text;
  part_range       text;
  src_path_old     text;
  src_path_new     text;
  aclstr           text;
  -- issue#80 initialize arrays properly
  tblarray         text[] := '{}';
  tblarray2        text[] := '{}';
  tblelement       text;
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
  sq_is_called     boolean := True;
  sq_is_cycled     boolean;
  is_prokind       boolean;
  abool            boolean;
  sq_data_type     text;
  sq_cycled        char(10);
  sq_owned         text;
  sq_version        text;
  sq_server_version text;
  sq_server_version_num integer;
  bWindows         boolean;
  arec             RECORD;
  cnt              integer;
  cnt2             integer;
  cnt3             integer;
  pos              integer;
  tblscopied       integer := 0;
  l_child          integer;
  action           text := 'N/A';
  tblname          text;
  v_ret            text;
  v_diag1          text;
  v_diag2          text;
  v_diag3          text;
  v_diag4          text;
  v_diag5          text;
  v_diag6          text;
  v_dummy          text;
  v_version        text := '1.8  July 15, 2022';

BEGIN
  RAISE NOTICE 'clone_schema version %', v_version;

  -- Get server version info to handle certain things differently based on the version.
  SELECT setting INTO sq_server_version
  FROM pg_settings
  WHERE name = 'server_version';
  SELECT version() INTO sq_version;
  
  IF POSITION('compiled by Visual C++' IN sq_version) > 0 THEN
      bWindows = True;
      RAISE NOTICE 'Windows: %', sq_version;
  ELSE
      bWindows = False;
      RAISE NOTICE 'Linux: %', sq_version;
  END IF;
  SELECT setting INTO sq_server_version_num
  FROM pg_settings
  WHERE name = 'server_version_num';

  IF sq_server_version_num < 100000 THEN
    RAISE WARNING 'Server Version:%  Number:%  PG Versions older than v10 are not supported.', sq_server_version, sq_server_version_num;
    RETURN;
  END IF;

  -- Make sure NOTICE are shown
  set client_min_messages = 'notice';

  -- Check that source_schema exists
  SELECT oid INTO src_oid
  FROM pg_namespace
  WHERE nspname = quote_ident(source_schema);

  IF NOT FOUND
    THEN
    RAISE NOTICE ' source schema % does not exist!', source_schema;
    RETURN ;
  END IF;

  -- Check for case-sensitive target schemas and reject them for now.
  SELECT lower(dest_schema) = dest_schema INTO abool;
  IF not abool THEN
      RAISE NOTICE 'Case-sensitive target schemas are not supported at this time.';
      RETURN;
  END IF;

  -- Check that dest_schema does not yet exist
  PERFORM nspname
  FROM pg_namespace
  WHERE nspname = quote_ident(dest_schema);

  IF FOUND
    THEN
    RAISE NOTICE ' dest schema % already exists!', dest_schema;
    RETURN ;
  END IF;
  IF ddl_only and include_recs THEN
    RAISE WARNING 'You cannot specify to clone data and generate ddl at the same time.';
    RETURN ;
  END IF;

  -- Set the search_path to source schema. Before exiting set it back to what it was before.
  -- In order to avoid issues with the special schema name "$user" that may be
  -- returned unquoted by some applications, we ensure it remains double quoted.
  -- MJV FIX: #47
  SELECT REPLACE(REPLACE(setting, '"$user"', '$user'), '$user', '"$user"') INTO src_path_old
  FROM pg_settings
  WHERE name = 'search_path';

  EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
  SELECT setting INTO src_path_new
  FROM pg_settings
  WHERE name='search_path';

  -- Validate required types exist.  If not, create them.
  SELECT a.objtypecnt, b.permtypecnt INTO cnt, cnt2
  FROM (
      SELECT count(*) AS objtypecnt
      FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
  WHERE (t.typrelid = 0
      OR (
          SELECT c.relkind = 'c'
          FROM pg_catalog.pg_class c
          WHERE c.oid = t.typrelid))
      AND NOT EXISTS (
          SELECT 1
          FROM pg_catalog.pg_type el
          WHERE el.oid = t.typelem
              AND el.typarray = t.oid)
          AND n.nspname <> 'pg_catalog'
          AND n.nspname <> 'information_schema'
          AND pg_catalog.pg_type_is_visible(t.oid)
          AND pg_catalog.format_type(t.oid, NULL) = 'obj_type') a, (
          SELECT count(*) AS permtypecnt
          FROM pg_catalog.pg_type t
          LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
      WHERE (t.typrelid = 0
          OR (
              SELECT c.relkind = 'c'
              FROM pg_catalog.pg_class c
              WHERE c.oid = t.typrelid))
          AND NOT EXISTS (
              SELECT 1
              FROM pg_catalog.pg_type el
              WHERE el.oid = t.typelem
                  AND el.typarray = t.oid)
              AND n.nspname <> 'pg_catalog'
              AND n.nspname <> 'information_schema'
              AND pg_catalog.pg_type_is_visible(t.oid)
              AND pg_catalog.format_type(t.oid, NULL) = 'perm_type') b;

  IF cnt = 0 THEN
    CREATE TYPE obj_type AS ENUM ('TABLE','VIEW','COLUMN','SEQUENCE','FUNCTION','SCHEMA','DATABASE');
  END IF;
  IF cnt2 = 0 THEN
    CREATE TYPE perm_type AS ENUM ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','USAGE','CREATE','EXECUTE','CONNECT','TEMPORARY');
  END IF;

  IF ddl_only THEN
    RAISE NOTICE ' Only generating DDL, not actually creating anything...';
    RAISE INFO 'CREATE SCHEMA %;', quote_ident(dest_schema);
    RAISE INFO 'SET search_path=%;', quote_ident(dest_schema);
  ELSE
    EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) ;
  END IF;

  -- Do system table validations for subsequent system table queries
  -- Issue#65 Fix
  SELECT count(*) into cnt
  FROM pg_attribute
  WHERE  attrelid = 'pg_proc'::regclass AND attname = 'prokind';

  IF cnt = 0 THEN
      is_prokind = False;
  ELSE
      is_prokind = True;
  END IF;

  -- MV: Create Collations
  action := 'Collations';
  cnt := 0;
  IF sq_server_version_num < 100000 THEN
    RAISE NOTICE ' Collation cloning is are not supported in PG versions older than v10.  Current version is %-%', sq_server_version, sq_server_version_num;
  ELSE
    FOR arec IN
      SELECT n.nspname AS schemaname, a.rolname AS ownername, c.collname, c.collprovider, c.collcollate AS locale, 'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || CASE WHEN c.collprovider = 'i' THEN
              'icu'
          WHEN c.collprovider = 'c' THEN
              'libc'
          ELSE
              ''
          END || ', locale = ''' || c.collcollate || ''');' AS COLL_DDL
      FROM pg_collation c
          JOIN pg_namespace n ON (c.collnamespace = n.oid)
          JOIN pg_roles a ON (c.collowner = a.oid)
      WHERE n.nspname = quote_ident(source_schema)
      ORDER BY c.collname
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
  END IF;
  RAISE NOTICE '  COLLATIONS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: Create Domains
  action := 'Domains';
  cnt := 0;
  FOR arec IN
    SELECT n.nspname AS "Schema", t.typname AS "Name", pg_catalog.format_type(t.typbasetype, t.typtypmod) AS "Type", (
            SELECT c.collname
            FROM pg_catalog.pg_collation c, pg_catalog.pg_type bt
            WHERE c.oid = t.typcollation
                AND bt.oid = t.typbasetype
                AND t.typcollation <> bt.typcollation) AS "Collation", CASE WHEN t.typnotnull THEN
            'not null'
        END AS "Nullable", t.typdefault AS "Default", pg_catalog.array_to_string(ARRAY (
                SELECT pg_catalog.pg_get_constraintdef(r.oid, TRUE)
                FROM pg_catalog.pg_constraint r
                -- Issue#78 FIX: handle case-sensitive names with quote_ident() on t.typename
                WHERE t.oid = r.contypid), ' ') AS "Check", 'CREATE DOMAIN ' || quote_ident(dest_schema) || '.' || quote_ident(t.typname) || ' AS ' || pg_catalog.format_type(t.typbasetype, t.typtypmod) ||
                CASE WHEN t.typnotnull IS NOT NULL THEN
            ' NOT NULL '
        ELSE
            ' '
        END || CASE WHEN t.typdefault IS NOT NULL THEN
            'DEFAULT ' || t.typdefault || ' '
        ELSE
            ' '
        END || pg_catalog.array_to_string(ARRAY (
                SELECT pg_catalog.pg_get_constraintdef(r.oid, TRUE)
                FROM pg_catalog.pg_constraint r
                WHERE t.oid = r.contypid), ' ') || ';' AS DOM_DDL
    FROM pg_catalog.pg_type t
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typtype = 'd'
        AND n.nspname = quote_ident(source_schema)
        AND pg_catalog.pg_type_is_visible(t.oid)
    ORDER BY 1, 2
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
    SELECT c.relkind, n.nspname AS schemaname, t.typname AS typname, t.typcategory, CASE WHEN t.typcategory = 'C' THEN
            'CREATE TYPE ' || quote_ident(dest_schema) || '.' || t.typname || ' AS (' || array_to_string(array_agg(a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod)
                ORDER BY c.relname, a.attnum), ', ') || ');'
        WHEN t.typcategory = 'E' THEN
            'CREATE TYPE ' || quote_ident(dest_schema) || '.' || t.typname || ' AS ENUM (' || REPLACE(quote_literal(array_to_string(array_agg(e.enumlabel ORDER BY e.enumsortorder), ',')), ',', ''',''') || ');'
        ELSE
            ''
        END AS type_ddl
    FROM pg_type t
        JOIN pg_namespace n ON (n.oid = t.typnamespace)
        LEFT JOIN pg_enum e ON (t.oid = e.enumtypid)
        LEFT JOIN pg_class c ON (c.reltype = t.oid)
        LEFT JOIN pg_attribute a ON (a.attrelid = c.oid)
    WHERE n.nspname = quote_ident(source_schema)
        AND (c.relkind IS NULL
            OR c.relkind = 'c')
        AND t.typcategory IN ('C', 'E')
    GROUP BY 1, 2, 3, 4
    ORDER BY n.nspname, t.typcategory, t.typname

  LOOP
    BEGIN
      cnt := cnt + 1;
      -- Keep composite and enum types in separate branches for fine tuning later if needed.
      IF arec.typcategory = 'E' THEN
        IF ddl_only THEN
          RAISE INFO '%', arec.type_ddl;
        ELSE
          EXECUTE arec.type_ddl;
        END IF;
      ELSEIF arec.typcategory = 'C' THEN
        IF ddl_only THEN
          RAISE INFO '%', arec.type_ddl;
        ELSE
          EXECUTE arec.type_ddl;
        END IF;
      ELSE
          RAISE NOTICE ' Unhandled type:%-%', arec.typcategory, arec.typname;
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '       TYPES cloned: %', LPAD(cnt::text, 5, ' ');

  -- Create sequences
  action := 'Sequences';
  cnt := 0;
  -- fix#63  get from pg_sequences not information_schema
  -- fix#63  take 2: get it from information_schema.sequences since we need to treat IDENTITY columns differently.
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

    IF sq_server_version_num < 100000 THEN
      EXECUTE 'SELECT last_value, is_called FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';' INTO sq_last_value, sq_is_called;
      EXECUTE 'SELECT maximum_value, start_value, increment, minimum_value, 1 cache_size, cycle_option, data_type
               FROM information_schema.sequences WHERE sequence_schema='|| quote_literal(source_schema) || ' AND sequence_name=' || quote_literal(object) || ';'
               INTO sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_is_cycled, sq_data_type;
      IF sq_is_cycled
        THEN
          sq_cycled := 'CYCLE';
      ELSE
          sq_cycled := 'NO CYCLE';
      END IF;

      qry := 'ALTER SEQUENCE '   || quote_ident(dest_schema) || '.' || quote_ident(object)
             || ' INCREMENT BY ' || sq_increment_by
             || ' MINVALUE '     || sq_min_value
             || ' MAXVALUE '     || sq_max_value
             -- will update current sequence value after this
             || ' START WITH '   || sq_start_value
             || ' RESTART '      || sq_min_value
             || ' CACHE '        || sq_cache_value
             || ' '              || sq_cycled || ' ;' ;
    ELSE
      EXECUTE 'SELECT max_value, start_value, increment_by, min_value, cache_size, cycle, data_type, COALESCE(last_value, 1)
            FROM pg_catalog.pg_sequences WHERE schemaname='|| quote_literal(source_schema) || ' AND sequencename=' || quote_literal(object) || ';'
            INTO sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_is_cycled, sq_data_type, sq_last_value;
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
             -- will update current sequence value after this
             || ' START WITH '   || sq_start_value
             || ' RESTART '      || sq_min_value
             || ' CACHE '        || sq_cache_value
             || ' '              || sq_cycled || ' ;' ;
    END IF;

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
        -- fix#63
        --  RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
        RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
      ELSE
        -- fix#63
        -- EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
        EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
      END IF;

    END IF;
  END LOOP;
  RAISE NOTICE '   SEQUENCES cloned: %', LPAD(cnt::text, 5, ' ');


  -- Create tables including partitioned ones (parent/children) and unlogged ones.  Order by is critical since child partition range logic is dependent on it.
  action := 'Tables';
  cnt := 0;
  -- Issue#61 FIX: use set_config for empty string
  -- SET search_path = '';
  SELECT set_config('search_path', '', false)
  into v_dummy;

  FOR tblname, relpersist, bRelispart, relknd, data_type, ocomment, l_child  IN
    -- 2021-03-08 MJV #39 fix: change sql to get indicator of user-defined columns to issue warnings
    -- select c.relname, c.relpersistence, c.relispartition, c.relkind
    -- FROM pg_class c, pg_namespace n where n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and c.relkind in ('r','p') and
    -- order by c.relkind desc, c.relname
    --Fix#65 add another left join to distinguish child tables by inheritance

    SELECT DISTINCT c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type, obj_description(c.oid), i.inhrelid
    FROM pg_class c
        JOIN pg_namespace n ON (n.oid = c.relnamespace
                AND n.nspname = quote_ident(source_schema)
                AND c.relkind IN ('r', 'p'))
        LEFT JOIN information_schema.columns co ON (co.table_schema = n.nspname
                AND co.table_name = c.relname
                AND co.data_type = 'USER-DEFINED')
        LEFT JOIN pg_inherits i ON (c.oid = i.inhrelid)
    ORDER BY c.relkind DESC, c.relname
  LOOP
    cnt := cnt + 1;
    IF l_child IS NULL THEN
      bChild := False;
    ELSE
      bChild := True;
    END IF;
    -- RAISE NOTICE 'table=%  bRelispart=%  relkind=%  bChild=%',tblname, bRelispart, relknd, bChild;

    IF data_type = 'USER-DEFINED' THEN
      -- RAISE NOTICE ' Table (%) has column(s) with user-defined types so using get_table_ddl() instead of CREATE TABLE LIKE construct.',tblname;
      cnt :=cnt;
    END IF;
    buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);
    buffer2 := '';
    IF relpersist = 'u' THEN
      buffer2 := 'UNLOGGED ';
    END IF;
    IF relknd = 'r' THEN
      IF ddl_only THEN
        IF data_type = 'USER-DEFINED' THEN
          -- FIXED #65, #67
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
          SELECT * INTO buffer3
          FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);

          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
        ELSE
          IF NOT bChild THEN
            RAISE INFO '%', 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL);';
          ELSE
            -- FIXED #65, #67
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
            SELECT * INTO buffer3
            FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);

            buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          END IF;
        END IF;

      ELSE
        IF data_type = 'USER-DEFINED' THEN
          -- FIXED #65, #67
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
          SELECT * INTO buffer3
          FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);

          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          EXECUTE buffer3;
        ELSE
          IF NOT bChild OR bRelispart THEN
            buffer3 := 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL)';
            EXECUTE buffer3;
          ELSE
            -- FIXED #65, #67
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
            SELECT * INTO buffer3
            FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);

            buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
            -- set client_min_messages higher to avoid messages like this:
            -- NOTICE:  merging column "city_id" with inherited definition
            set client_min_messages = 'WARNING';
            EXECUTE buffer3;
            -- reset it back, only get these for inheritance-based tables
            set client_min_messages = 'notice';
          END IF;
        END IF;
        -- Add table comment.
        IF ocomment IS NOT NULL THEN
          EXECUTE 'COMMENT ON TABLE ' || buffer || ' IS ' || quote_literal(ocomment);
        END IF;
      END IF;
    ELSIF relknd = 'p' THEN
      -- define parent table and assume child tables have already been created based on top level sort order.
      SELECT 'CREATE TABLE '
        || quote_ident(dest_schema)
        || '.'
        || pc.relname
        || E'(\n'
        || string_agg(
          pa.attname
            || ' '
            || pg_catalog.format_type(pa.atttypid, pa.atttypmod)
            || coalesce(
              ' DEFAULT '
                || (
                  SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid)
                  FROM pg_catalog.pg_attrdef d
                  WHERE d.adrelid = pa.attrelid
                    AND d.adnum = pa.attnum
                    AND pa.atthasdef
                ),
              ''
            )
            || ' '
            || CASE pa.attnotnull
              WHEN TRUE THEN 'NOT NULL'
              ELSE 'NULL'
              END,
          E',\n'
        )
        || coalesce(
          (
            SELECT
              E',\n'
              || string_agg(
                'CONSTRAINT '
                  || pc1.conname
                  || ' '
                  || pg_get_constraintdef(pc1.oid),
                E',\n'
                ORDER BY pc1.conindid
              )
            FROM pg_constraint pc1
            WHERE pc1.conrelid = pa.attrelid
          ),
          ''
        )
      INTO buffer
      FROM pg_catalog.pg_attribute pa
        JOIN pg_catalog.pg_class pc ON pc.oid = pa.attrelid
          AND pc.relname = quote_ident(tblname)
        JOIN pg_catalog.pg_namespace pn ON pn.oid = pc.relnamespace
          AND pn.nspname = quote_ident(source_schema)
      WHERE pa.attnum > 0
        AND NOT pa.attisdropped
      GROUP BY pn.nspname, pc.relname, pa.attrelid;

      -- append partition keyword to it
      SELECT pg_catalog.pg_get_partkeydef(c.oid::pg_catalog.oid) into buffer2
      FROM pg_catalog.pg_class c  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = quote_ident(tblname) COLLATE pg_catalog.default AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default;

      qry := buffer || ') PARTITION BY ' || buffer2 || ';';
      IF ddl_only THEN
        RAISE INFO '%', qry;
      ELSE
        EXECUTE qry;
      END IF;
      -- loop for child tables and alter them to attach to parent for specific partition method.
      FOR aname, part_range, object IN
        SELECT quote_ident(dest_schema) || '.' || c1.relname as tablename, pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) as partrange, quote_ident(dest_schema) || '.' || c2.relname as object
        FROM pg_catalog.pg_class c1, pg_namespace n, pg_catalog.pg_inherits i, pg_class c2
        WHERE n.nspname = quote_ident(source_schema) AND c1.relnamespace = n.oid AND c1.relkind = 'r' AND
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
        ORDER BY old.indexdef, new.indexdef
    LOOP
      IF ddl_only THEN
        RAISE INFO '%', 'ALTER INDEX ' || quote_ident(dest_schema) || '.'  || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';';
      ELSE
        -- The SELECT query above may return duplicate names when a column is
        -- indexed twice the same manner with 2 different names. Therefore, to
        -- avoid a 'relation "xxx" already exists' we test if the index name
        -- is in use or free. Skipping existing index will fallback on unused
        -- ones and every duplicate will be mapped to distinct old names.
        IF NOT EXISTS (
            SELECT TRUE
            FROM pg_indexes
            WHERE schemaname = dest_schema
              AND tablename = tblname
              AND indexname = quote_ident(ix_old_name))
          AND EXISTS (
            SELECT TRUE
            FROM pg_indexes
            WHERE schemaname = dest_schema
              AND tablename = tblname
              AND indexname = quote_ident(ix_new_name))
          THEN
          EXECUTE 'ALTER INDEX ' || quote_ident(dest_schema) || '.' || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';';
        END IF;
      END IF;
    END LOOP;

    IF include_recs THEN
      -- Insert records from source table

      -- 2021-03-03  MJV FIX
      buffer := dest_schema || '.' || quote_ident(tblname);

      -- 2020/06/18 - Issue #31 fix: add "OVERRIDING SYSTEM VALUE" for IDENTITY columns marked as GENERATED ALWAYS.
      select count(*) into cnt2 from pg_class c, pg_attribute a, pg_namespace n
          where a.attrelid = c.oid and c.relname = quote_ident(tblname) and n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and a.attidentity = 'a';
      buffer3 := '';
      IF cnt2 > 0 THEN
          buffer3 := ' OVERRIDING SYSTEM VALUE';
      END IF;
      -- BUG for inserting rows from tables with user-defined columns
      -- INSERT INTO sample_clone.address OVERRIDING SYSTEM VALUE SELECT * FROM sample.address;
      -- ERROR:  column "id2" is of type sample_clone.udt_myint but expression is of type udt_myint
      IF data_type = 'USER-DEFINED' THEN
        -- RAISE WARNING 'Bypassing copying rows for table (%) with user-defined data types.  You must copy them manually.', tblname;
        -- wont work --> INSERT INTO sample_clone1.address (id2, id3, addr) SELECT cast(id2 as sample_clone1.udt_myint), cast(id3 as sample_clone1.udt_myint), addr FROM sample.address;

        -- Issue#79 implementation follows        
        -- COPY sample.statuses(id, s) TO '/tmp/statuses.txt' WITH DELIMITER AS ',';
	-- COPY sample_clone1.statuses FROM '/tmp/statuses.txt' (DELIMITER ',', NULL '');
	IF bWindows THEN
	    buffer2   := 'COPY ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' TO  ''C:\WINDOWS\TEMP\cloneschema.tmp'' WITH DELIMITER AS '','';';
	    tblarray2 := tblarray2 || buffer2;
	    -- Issue #81 reformat COPY command for upload
	    -- buffer2:= 'COPY ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || '  FROM  ''C:\WINDOWS\TEMP\cloneschema.tmp'' (DELIMITER '','', NULL '''');';
	    buffer2   := 'COPY ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || '  FROM  ''C:\WINDOWS\TEMP\cloneschema.tmp'' (DELIMITER '','', NULL ''\N'', FORMAT CSV);';
	    tblarray2 := tblarray2 || buffer2;
	ELSE
	    buffer2   := 'COPY ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' TO ''/tmp/cloneschema.tmp'' WITH DELIMITER AS '','';';
	    tblarray2 := tblarray2 || buffer2;
	    -- Issue #81 reformat COPY command for upload
	    -- buffer2   := 'COPY ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || '  FROM ''/tmp/cloneschema.tmp'' (DELIMITER '','', NULL '''');';
	    -- works--> COPY sample.timestamptbl2  FROM '/tmp/cloneschema.tmp' WITH (DELIMITER ',', NULL '\N', FORMAT CSV) ;
	    buffer2   := 'COPY ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || '  FROM ''/tmp/cloneschema.tmp'' (DELIMITER '','', NULL ''\N'', FORMAT CSV);';
	    tblarray2 := tblarray2 || buffer2;
	END IF;

      ELSE
        -- bypass child tables since we populate them when we populate the parents
        -- RAISE NOTICE 'tblname=%  bRelispart=%  relknd=%  l_child=%  bChild=%', tblname, bRelispart, relknd, l_child, bChild;
        IF NOT bRelispart AND NOT bChild THEN
          -- Issue#75: Must defer population of tables until child tables have been added to parents
          -- RAISE NOTICE ' Deferring populating of cloned table, %', tblname;
          buffer2 := 'INSERT INTO ' || buffer || buffer3 || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ';';
          tblarray := tblarray || buffer2;
        END IF;

      END IF;
    END IF;

    -- Issue#61 FIX: use set_config for empty string
    -- SET search_path = '';
    SELECT set_config('search_path', '', false) into v_dummy;

    FOR column_, default_ IN
      SELECT column_name::text,
             REPLACE(column_default::text, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.')
      FROM information_schema.COLUMNS
      WHERE table_schema = source_schema
          AND TABLE_NAME = tblname
          AND column_default LIKE 'nextval(%' || quote_ident(source_schema) || '%::regclass)'
    LOOP
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on column name
      buffer2 = 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || quote_ident(column_) || ' SET DEFAULT ' || default_ || ';';
      IF ddl_only THEN
        -- May need to come back and revisit this since previous sql will not return anything since no schema as created!
        RAISE INFO '%', buffer2;
      ELSE
        EXECUTE buffer2;
      END IF;
    END LOOP;
    EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;

  END LOOP;
  RAISE NOTICE '      TABLES cloned: %', LPAD(cnt::text, 5, ' ');

  -- Assigning sequences to table columns.
  action := 'Sequences assigning';
  cnt := 0;
  FOR object IN
    SELECT sequence_name::text
    FROM information_schema.sequences
    WHERE sequence_schema = quote_ident(source_schema)
  LOOP
    cnt := cnt + 1;
    srctbl := quote_ident(source_schema) || '.' || quote_ident(object);

    -- Get owning column, inspired from Sadique Ali post at:
    -- https://sadique.io/blog/2019/05/07/viewing-sequence-ownership-information-in-postgres/
    SELECT ' OWNED BY '
      || quote_ident(dest_schema)
      || '.'
      || quote_ident(dc.relname)
      || '.'
      || quote_ident(a.attname)
    INTO sq_owned
    FROM pg_class AS c
      JOIN pg_depend AS d ON (c.relfilenode = d.objid)
      JOIN pg_class AS dc ON (d.refobjid = dc.relfilenode)
      JOIN pg_attribute AS a ON (
        a.attnum = d.refobjsubid
        AND a.attrelid = d.refobjid
      )
      JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = quote_ident(source_schema)
      AND c.relkind = 'S'
      AND c.relname = object;

    IF sq_owned IS NOT NULL THEN
      qry := 'ALTER SEQUENCE '
        || quote_ident(dest_schema)
        || '.'
        || quote_ident(object)
        || sq_owned
        || ';';

      IF ddl_only THEN
        RAISE INFO '%', qry;
      ELSE
        EXECUTE qry;
      END IF;

    END IF;

  END LOOP;
  RAISE NOTICE '    SEQUENCES set:      %', LPAD(cnt::text, 2, ' ');

  -- Update IDENTITY sequences to the last value
  action := 'Identity updating';
  cnt := 0;
  FOR object, sq_last_value IN
    SELECT sequencename::text, COALESCE(last_value, -999) from pg_sequences where schemaname = quote_ident(source_schema)
    AND NOT EXISTS
    (select 1 from information_schema.sequences where sequence_schema = quote_ident(source_schema) and sequence_name = sequencename)
  LOOP
    IF sq_last_value = -999 THEN
      continue;
    END IF;
    cnt := cnt + 1;
    buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
    IF include_recs THEN
      EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
    ELSE
      if ddl_only THEN
        -- fix#63
        RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
      ELSE
        -- fix#63
        EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
      END IF;
    END IF;
  END LOOP;
  RAISE NOTICE '   IDENTITIES set:      %', LPAD(cnt::text, 2, ' ');



  -- Issue#78 forces us to defer FKeys until the end since we previously did row copies before FKeys
  --  add FK constraint
  -- action := 'FK Constraints';


  -- Issue#62: Add comments on indexes, and then removed them from here and reworked later below.

  -- Create views
  action := 'Views';

  -- Issue#61 FIX: use set_config for empty string
  -- MJV FIX #43: also had to reset search_path from source schema to empty.
  -- SET search_path = '';
  SELECT set_config('search_path', '', false)
  INTO v_dummy;

  cnt := 0;
  --FOR object IN
    -- SELECT table_name::text, view_definition
    -- FROM information_schema.views
    -- WHERE table_schema = quote_ident(source_schema)

  -- Issue#73 replace loop query to handle dependencies
  FOR srctbl, aname, object IN
    WITH RECURSIVE views AS (
       SELECT n.nspname as schemaname, v.relname as tablename, v.oid::regclass AS viewname,
              v.relkind = 'm' AS is_materialized,
              1 AS level
       FROM pg_depend AS d
          JOIN pg_rewrite AS r
             ON r.oid = d.objid
          JOIN pg_class AS v
             ON v.oid = r.ev_class
          JOIN pg_namespace n
             ON n.oid = v.relnamespace
       -- WHERE v.relkind IN ('v', 'm')
       WHERE v.relkind IN ('v')
         AND d.classid = 'pg_rewrite'::regclass
         AND d.refclassid = 'pg_class'::regclass
         AND d.deptype = 'n'
    UNION
       -- add the views that depend on these
       SELECT n.nspname as schemaname, v.relname as tablename, v.oid::regclass AS viewname,
              v.relkind = 'm',
              views.level + 1
       FROM views
          JOIN pg_depend AS d
             ON d.refobjid = views.viewname
          JOIN pg_rewrite AS r
             ON r.oid = d.objid
          JOIN pg_class AS v
             ON v.oid = r.ev_class
          JOIN pg_namespace n
             ON n.oid = v.relnamespace
       -- WHERE v.relkind IN ('v', 'm')
       WHERE v.relkind IN ('v')
         AND d.classid = 'pg_rewrite'::regclass
             AND d.refclassid = 'pg_class'::regclass
         AND d.deptype = 'n'
         AND v.oid <> views.viewname
    )
    SELECT tablename, viewname, format('CREATE OR REPLACE%s VIEW %s AS%s',
                  CASE WHEN is_materialized
                       THEN ' MATERIALIZED'
                       ELSE ''
                  END,
                  viewname,
                  pg_get_viewdef(viewname))
    FROM views
    WHERE schemaname = quote_ident(source_schema)
    GROUP BY schemaname, tablename, viewname, is_materialized
    ORDER BY max(level), schemaname, tablename
  LOOP
    cnt := cnt + 1;
    -- Issue#73 replace logic based on new loop sql
    buffer := quote_ident(dest_schema) || '.' || quote_ident(aname);
    -- MJV FIX: #43
    -- SELECT view_definition INTO v_def
    -- SELECT REPLACE(view_definition, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO v_def
    -- FROM information_schema.views
    -- WHERE table_schema = quote_ident(source_schema)
    --   AND table_name = quote_ident(object);
    SELECT REPLACE(object, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO v_def;
    -- NOTE: definition already includes the closing statement semicolon
    IF ddl_only THEN
      RAISE INFO '%', v_def;
    ELSE
      -- EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def;
      EXECUTE v_def;
      -- Issue#73: commented out comment logic for views since we do it elsewhere now.
    END IF;
  END LOOP;
  RAISE NOTICE '       VIEWS cloned: %', LPAD(cnt::text, 5, ' ');

  -- Create Materialized views
  action := 'Mat. Views';
  cnt := 0;
  FOR object, v_def IN
      SELECT matviewname::text, replace(definition,';','') FROM pg_catalog.pg_matviews WHERE schemaname = quote_ident(source_schema)
  LOOP
      cnt := cnt + 1;
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on target schema and object
      buffer := quote_ident(dest_schema) || '.' || quote_ident(object);

      -- MJV FIX: #72 remove source schema in MV def
      SELECT REPLACE(v_def, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO buffer2;

      IF include_recs THEN
        -- EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || v_def || ' WITH DATA;' ;
        EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH DATA;' ;
      ELSE
        IF ddl_only THEN
          RAISE INFO '%', 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH NO DATA;' ;
        ELSE
          EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH NO DATA;' ;
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
        SELECT indexname, replace(indexdef, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') as newdef FROM pg_indexes where schemaname = quote_ident(source_schema) and tablename = object order by indexname
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
  EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;

  -- Fixed Issue#65
  -- FOR func_oid IN SELECT oid FROM pg_proc WHERE pronamespace = src_oid AND prokind != 'a'
  IF is_prokind THEN
    FOR func_oid IN SELECT oid FROM pg_proc WHERE pronamespace = src_oid AND prokind != 'a'
    LOOP
      cnt := cnt + 1;
      SELECT pg_get_functiondef(func_oid)
      INTO qry;

      SELECT replace(qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO dest_qry;
      IF ddl_only THEN
        RAISE INFO '%;', dest_qry;
      ELSE
        EXECUTE dest_qry;
      END IF;
    END LOOP;
  ELSE
    FOR func_oid IN SELECT oid
                    FROM pg_proc
                    WHERE pronamespace = src_oid AND not proisagg
    LOOP
      cnt := cnt + 1;
      SELECT pg_get_functiondef(func_oid) INTO qry;
      SELECT replace(qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO dest_qry;
      IF ddl_only THEN
        RAISE INFO '%;', dest_qry;
      ELSE
        EXECUTE dest_qry;
      END IF;
    END LOOP;
  END IF;

  -- Create aggregate functions.
  -- Fixed Issue#65
  -- FOR func_oid IN SELECT oid FROM pg_proc WHERE pronamespace = src_oid AND prokind = 'a'
  IF is_prokind THEN
    FOR func_oid IN
        SELECT oid
        FROM pg_proc
        WHERE pronamespace = src_oid AND prokind = 'a'
    LOOP
      cnt := cnt + 1;
      SELECT
        'CREATE AGGREGATE '
        || dest_schema
        || '.'
        || p.proname
        || '('
        -- || format_type(a.aggtranstype, NULL)
        -- Issue#65 Fixes for specific datatype mappings
        || CASE WHEN format_type(a.aggtranstype, NULL) = 'double precision[]' THEN 'float8'
                WHEN format_type(a.aggtranstype, NULL) = 'anyarray'           THEN 'anyelement'
           ELSE format_type(a.aggtranstype, NULL) END
        || ') (sfunc = '
        || regexp_replace(a.aggtransfn::text, '(^|\W)' || quote_ident(source_schema) || '\.', '\1' || quote_ident(dest_schema) || '.')
        || ', stype = '
        -- || format_type(a.aggtranstype, NULL)
        -- Issue#65 Fixes for specific datatype mappings
        || CASE WHEN format_type(a.aggtranstype, NULL) = 'double precision[]' THEN 'float8[]' ELSE format_type(a.aggtranstype, NULL) END
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

      IF ddl_only THEN
        RAISE INFO '%;', dest_qry;
      ELSE
        EXECUTE dest_qry;
      END IF;

    END LOOP;
    RAISE NOTICE '   FUNCTIONS cloned: %', LPAD(cnt::text, 5, ' ');

  ELSE
    FOR func_oid IN SELECT oid FROM pg_proc WHERE pronamespace = src_oid AND proisagg
    LOOP
      cnt := cnt + 1;
      SELECT
        'CREATE AGGREGATE '
        || dest_schema
        || '.'
        || p.proname
        || '('
        -- || format_type(a.aggtranstype, NULL)
        -- Issue#65 Fixes for specific datatype mappings
        || CASE WHEN format_type(a.aggtranstype, NULL) = 'double precision[]' THEN 'float8'
                WHEN format_type(a.aggtranstype, NULL) = 'anyarray'           THEN 'anyelement'
           ELSE format_type(a.aggtranstype, NULL) END
        || ') (sfunc = '
        || regexp_replace(a.aggtransfn::text, '(^|\W)' || quote_ident(source_schema) || '\.', '\1' || quote_ident(dest_schema) || '.')
        || ', stype = '
        -- || format_type(a.aggtranstype, NULL)
        -- Issue#65 Fixes for specific datatype mappings
        || CASE WHEN format_type(a.aggtranstype, NULL) = 'double precision[]' THEN 'float8[]' ELSE format_type(a.aggtranstype, NULL) END
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

      IF ddl_only THEN
        RAISE INFO '%;', dest_qry;
      ELSE
        EXECUTE dest_qry;
      END IF;

    END LOOP;
    RAISE NOTICE '   FUNCTIONS cloned: %', LPAD(cnt::text, 5, ' ');
  END IF;


  -- MV: Create Triggers

  -- MJV FIX: #38
  -- EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;

  -- Issue#61 FIX: use set_config for empty string
  -- SET search_path = '';
  SELECT set_config('search_path', '', false) into v_dummy;

  action := 'Triggers';
  cnt := 0;
  FOR arec IN
    -- 2021-03-09 MJV FIX: #40 fixed sql to get the def using pg_get_triggerdef() sql
    SELECT n.nspname, c.relname, t.tgname, p.proname, REPLACE(pg_get_triggerdef(t.oid), quote_ident(source_schema), quote_ident(dest_schema)) || ';' AS trig_ddl
    FROM pg_trigger t, pg_class c, pg_namespace n, pg_proc p
    WHERE n.nspname = quote_ident(source_schema)
      AND n.oid = c.relnamespace
      AND c.relkind in ('r','p')
      AND n.oid = p.pronamespace
      AND c.oid = t.tgrelid
      AND p.oid = t.tgfoid
      ORDER BY c.relname, t.tgname
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


  -- MV: Create Rules
  -- Fixes Issue#59 Implement Rules
  action := 'Rules';
  cnt := 0;
  FOR arec IN
    SELECT regexp_replace(definition, E'[\\n\\r]+', ' ', 'g' ) as definition
    FROM pg_rules
    WHERE schemaname = quote_ident(source_schema)
  LOOP
    cnt := cnt + 1;
    buffer := REPLACE(arec.definition, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
    IF ddl_only THEN
      RAISE INFO '%', buffer;
    ELSE
      EXECUTE buffer;
    END IF;
  END LOOP;
  RAISE NOTICE '    RULES    cloned: %', LPAD(cnt::text, 5, ' ');


  -- MV: Create Policies
  -- Fixes Issue#66 Implement Security policies for RLS
  action := 'Policies';
  cnt := 0;
  FOR arec IN
    -- Issue#78 FIX: handle case-sensitive names with quote_ident() on policy, tablename
    SELECT schemaname as schemaname, tablename as tablename, 'CREATE POLICY ' || policyname || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(tablename) || ' AS ' || permissive || ' FOR ' || cmd || ' TO '
    ||  array_to_string(roles, ',', '*') || ' USING (' || regexp_replace(qual, E'[\\n\\r]+', ' ', 'g' ) || ')'
    || CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' ELSE '' END || coalesce(with_check, '') || CASE WHEN with_check IS NOT NULL THEN ');' ELSE ';' END as definition
    FROM pg_policies
    WHERE schemaname = quote_ident(source_schema)
    ORDER BY policyname
  LOOP
    cnt := cnt + 1;
    IF ddl_only THEN
      RAISE INFO '%', arec.definition;
    ELSE
      EXECUTE arec.definition;
    END IF;
    
    -- Issue#76: Enable row security if indicated
    SELECT c.relrowsecurity INTO abool FROM pg_class c, pg_namespace n where n.nspname = quote_ident(arec.schemaname) AND n.oid = c.relnamespace AND c.relname = quote_ident(arec.tablename) and c.relkind = 'r';
    IF abool THEN
      buffer = 'ALTER TABLE ' || dest_schema || '.' || arec.tablename || ' ENABLE ROW LEVEL SECURITY;';
      IF ddl_only THEN
        RAISE INFO '%', buffer;
      ELSE
        EXECUTE buffer;
      END IF;
    END IF;
  END LOOP;
  RAISE NOTICE '    POLICIES cloned: %', LPAD(cnt::text, 5, ' ');


  -- MJV Fixed #62 for comments (PASS 1)
  action := 'Comments1';
  cnt := 0;
  FOR qry IN
    -- Issue#74 Fix: Change schema from source to target. Also, do not include comments on foreign tables since we do not clone foreign tables at this time.
    SELECT 'COMMENT ON ' || CASE WHEN c.relkind in ('r','p') AND a.attname IS NULL THEN 'TABLE ' WHEN c.relkind in ('r','p') AND
    a.attname IS NOT NULL THEN 'COLUMN ' WHEN c.relkind = 'f' THEN 'FOREIGN TABLE ' WHEN c.relkind = 'm' THEN 'MATERIALIZED VIEW ' WHEN c.relkind = 'v' THEN 'VIEW '
    WHEN c.relkind = 'i' THEN 'INDEX ' WHEN c.relkind = 'S' THEN 'SEQUENCE ' ELSE 'XX' END || quote_ident(dest_schema) || '.' || CASE WHEN c.relkind in ('r','p') AND
    -- Issue#78: handle case-sensitive names with quote_ident()
    a.attname IS NOT NULL THEN quote_ident(c.relname) || '.' || a.attname ELSE quote_ident(c.relname) END ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_class c
    JOIN pg_namespace n ON (n.oid = c.relnamespace)
    LEFT JOIN pg_description d ON (c.oid = d.objoid)
    LEFT JOIN pg_attribute a ON (c.oid = a.attrelid
      AND a.attnum > 0 and a.attnum = d.objsubid)
    WHERE c.relkind <> 'f' AND d.description IS NOT NULL AND n.nspname = quote_ident(source_schema)
    ORDER BY ddl
  LOOP
    cnt := cnt + 1;
    
    -- BAD : "COMMENT ON SEQUENCE sample_clone2.CaseSensitive_ID_seq IS 'just a comment on CaseSensitive sequence';"
    -- GOOD: "COMMENT ON SEQUENCE "CaseSensitive_ID_seq" IS 'just a comment on CaseSensitive sequence';"
    
    IF ddl_only THEN
      RAISE INFO '%', qry;
    ELSE
      EXECUTE qry;
    END IF;
  END LOOP;
  RAISE NOTICE ' COMMENTS(1) cloned: %', LPAD(cnt::text, 5, ' ');

  -- MJV Fixed #62 for comments (PASS 2)
  action := 'Comments2';
  cnt2 := 0;
  IF is_prokind THEN
  FOR qry IN
    -- Issue#74 Fix: Change schema from source to target.
    SELECT 'COMMENT ON SCHEMA ' || dest_schema ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    from pg_namespace n, pg_description d where d.objoid = n.oid and n.nspname = quote_ident(source_schema)
    UNION
    -- Issue#74 Fix: need to replace source schema inline
    -- SELECT 'COMMENT ON TYPE ' || pg_catalog.format_type(t.oid, NULL) || ' IS ''' || pg_catalog.obj_description(t.oid, 'pg_type') || ''';' as ddl
    SELECT 'COMMENT ON TYPE ' || REPLACE(pg_catalog.format_type(t.oid, NULL), quote_ident(source_schema), quote_ident(dest_schema)) || ' IS ''' || pg_catalog.obj_description(t.oid, 'pg_type') || ''';' as ddl
    FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default
      AND pg_catalog.obj_description(t.oid, 'pg_type') IS NOT NULL and t.typtype = 'c'
    UNION
    -- Issue#78: handle case-sensitive names with quote_ident()
    SELECT 'COMMENT ON COLLATION ' || quote_ident(dest_schema) || '.' || quote_ident(c.collname) || ' IS ''' || pg_catalog.obj_description(c.oid, 'pg_collation') || ''';' as ddl
    FROM pg_catalog.pg_collation c, pg_catalog.pg_namespace n
    WHERE n.oid = c.collnamespace AND c.collencoding IN (-1, pg_catalog.pg_char_to_encoding(pg_catalog.getdatabaseencoding()))
      AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default AND pg_catalog.obj_description(c.oid, 'pg_collation') IS NOT NULL
    UNION
    SELECT 'COMMENT ON ' || CASE WHEN p.prokind = 'f' THEN 'FUNCTION ' WHEN p.prokind = 'p' THEN 'PROCEDURE ' WHEN p.prokind = 'a' THEN 'AGGREGATE ' END ||
    dest_schema || '.' || p.proname || ' (' || oidvectortypes(p.proargtypes) || ')'
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_catalog.pg_namespace n
    JOIN pg_catalog.pg_proc p ON p.pronamespace = n.oid
    JOIN pg_description d ON (d.objoid = p.oid)
    WHERE n.nspname = quote_ident(source_schema)
    UNION
    SELECT 'COMMENT ON POLICY ' || p1.policyname || ' ON ' || dest_schema || '.' || p1.tablename ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_policies p1, pg_policy p2, pg_class c, pg_namespace n, pg_description d
    WHERE p1.schemaname = n.nspname AND p1.tablename = c.relname AND n.oid = c.relnamespace
      AND c.relkind in ('r','p') AND p1.policyname = p2.polname AND d.objoid = p2.oid AND p1.schemaname = quote_ident(source_schema)
    UNION
    SELECT 'COMMENT ON DOMAIN ' || dest_schema || '.' || t.typname ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_catalog.pg_type t
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_catalog.pg_description d ON d.classoid = t.tableoid AND d.objoid = t.oid AND d.objsubid = 0
    WHERE t.typtype = 'd' AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default
    ORDER BY 1
  LOOP
    cnt2 := cnt2 + 1;
    IF ddl_only THEN
      RAISE INFO '%', qry;
    ELSE
      EXECUTE qry;
    END IF;
  END LOOP;
  ELSE -- must be v 10 or less
  FOR qry IN
    -- Issue#74 Fix: Change schema from source to target.
    SELECT 'COMMENT ON SCHEMA ' || dest_schema ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    from pg_namespace n, pg_description d where d.objoid = n.oid and n.nspname = quote_ident(source_schema)
    UNION
    -- Issue#74 Fix: need to replace source schema inline
    -- SELECT 'COMMENT ON TYPE ' || pg_catalog.format_type(t.oid, NULL) || ' IS ''' || pg_catalog.obj_description(t.oid, 'pg_type') || ''';' as ddl
    SELECT 'COMMENT ON TYPE ' || REPLACE(pg_catalog.format_type(t.oid, NULL), quote_ident(source_schema), quote_ident(dest_schema)) || ' IS ''' || pg_catalog.obj_description(t.oid, 'pg_type') || ''';' as ddl
    FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c'
                              FROM pg_catalog.pg_class c
                              WHERE c.oid = t.typrelid))
      AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el
                     WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default
      AND pg_catalog.obj_description(t.oid, 'pg_type') IS NOT NULL and t.typtype = 'c'
    UNION
    SELECT 'COMMENT ON COLLATION ' || dest_schema || '.' || c.collname || ' IS ''' || pg_catalog.obj_description(c.oid, 'pg_collation') || ''';' as ddl
    FROM pg_catalog.pg_collation c, pg_catalog.pg_namespace n
    WHERE n.oid = c.collnamespace AND c.collencoding IN (-1, pg_catalog.pg_char_to_encoding(pg_catalog.getdatabaseencoding()))
      AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default AND pg_catalog.obj_description(c.oid, 'pg_collation') IS NOT NULL
    UNION
    SELECT 'COMMENT ON ' || CASE WHEN proisagg THEN 'AGGREGATE ' ELSE 'FUNCTION ' END ||
    dest_schema || '.' || p.proname || ' (' || oidvectortypes(p.proargtypes) || ')'
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_catalog.pg_namespace n
    JOIN pg_catalog.pg_proc p ON p.pronamespace = n.oid
    JOIN pg_description d ON (d.objoid = p.oid)
    WHERE n.nspname = quote_ident(source_schema)
    UNION
    SELECT 'COMMENT ON POLICY ' || p1.policyname || ' ON ' || dest_schema || '.' || p1.tablename ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_policies p1, pg_policy p2, pg_class c, pg_namespace n, pg_description d
    WHERE p1.schemaname = n.nspname AND p1.tablename = c.relname AND n.oid = c.relnamespace
      AND c.relkind in ('r','p') AND p1.policyname = p2.polname AND d.objoid = p2.oid AND p1.schemaname = quote_ident(source_schema)
    UNION
    SELECT 'COMMENT ON DOMAIN ' || dest_schema || '.' || t.typname ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_catalog.pg_type t
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_catalog.pg_description d ON d.classoid = t.tableoid AND d.objoid = t.oid AND d.objsubid = 0
    WHERE t.typtype = 'd' AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default
    ORDER BY 1
  LOOP
    cnt2 := cnt2 + 1;
    IF ddl_only THEN
      RAISE INFO '%', qry;
    ELSE
      EXECUTE qry;
    END IF;
  END LOOP;
  END IF;
  RAISE NOTICE ' COMMENTS(2) cloned: %', LPAD(cnt2::text, 5, ' ');


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
    FROM pg_catalog.pg_default_acl d LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = d.defaclnamespace)
    WHERE n.nspname IS NOT NULL AND n.nspname = quote_ident(source_schema)
    ORDER BY 3, 2, 1
  LOOP
    BEGIN
      -- RAISE NOTICE ' owner=%  type=%  defaclacl=%  defaclstr=%', arec.owner, arec.atype, arec.defaclacl, arec.defaclstr;

      FOREACH aclstr IN ARRAY arec.defaclacl
      LOOP
          cnt := cnt + 1;
          -- RAISE NOTICE ' aclstr=%', aclstr;
          -- break up into grantor, grantee, and privs, mydb_update=rwU/mydb_owner
          SELECT split_part(aclstr, '=',1) INTO grantee;
          SELECT split_part(aclstr, '=',2) INTO grantor;
          SELECT split_part(grantor, '/',1) INTO privs;
          SELECT split_part(grantor, '/',2) INTO grantor;
          -- RAISE NOTICE ' grantor=%  grantee=%  privs=%', grantor, grantee, privs;

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
    FROM pg_catalog.pg_namespace AS n
    CROSS JOIN pg_catalog.pg_roles AS r
    CROSS JOIN (VALUES ('USAGE'), ('CREATE')) AS p(perm)
    WHERE n.nspname = quote_ident(source_schema) AND NOT r.rolsuper AND has_schema_privilege(r.oid, n.oid, p.perm)
    ORDER BY r.rolname, p.perm::perm_type
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
    -- Issue#78 FIX: handle case-sensitive names with quote_ident() on t.relname
    SELECT 'GRANT ' || p.perm::perm_type || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(t.relname::text) || ' TO "' || r.rolname || '";' as seq_ddl
    FROM pg_catalog.pg_class AS t
    CROSS JOIN pg_catalog.pg_roles AS r
    CROSS JOIN (VALUES ('SELECT'), ('USAGE'), ('UPDATE')) AS p(perm)
    WHERE t.relnamespace::regnamespace::name = quote_ident(source_schema) AND t.relkind = 'S'  AND NOT r.rolsuper AND has_sequence_privilege(r.oid, t.oid, p.perm)
  LOOP
    BEGIN
      cnt := cnt + 1;
      -- RAISE NOTICE 'DEBUG: ddl=%', arec.seq_ddl;
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

  -- Issue#61 FIX: use set_config for empty string
  -- SET search_path = '';
  SELECT set_config('search_path', '', false) into v_dummy;

  -- RAISE NOTICE ' source_schema=%  dest_schema=%',source_schema, dest_schema;
  FOR arec IN
    -- 2021-03-05 MJV FIX: issue#35: caused exception in some functions with parameters and gave privileges to other users that should not have gotten them.
    -- SELECT 'GRANT EXECUTE ON FUNCTION ' || quote_ident(dest_schema) || '.' || replace(regexp_replace(f.oid::regprocedure::text, '^((("[^"]*")|([^"][^.]*))\.)?', ''), source_schema, dest_schema) || ' TO "' || r.rolname || '";' as func_ddl
    -- FROM pg_catalog.pg_proc f CROSS JOIN pg_catalog.pg_roles AS r WHERE f.pronamespace::regnamespace::name = quote_ident(source_schema) AND NOT r.rolsuper AND has_function_privilege(r.oid, f.oid, 'EXECUTE')
    -- order by regexp_replace(f.oid::regprocedure::text, '^((("[^"]*")|([^"][^.]*))\.)?', '')

    -- 2021-03-05 MJV FIX: issue#37: defaults cause problems, use system function that returns args WITHOUT DEFAULTS
    -- COALESCE(r.routine_type, 'FUNCTION'): for aggregate functions, information_schema.routines contains NULL as routine_type value.
    -- Issue#78 FIX: handle case-sensitive names with quote_ident() on rp.routine_name
    SELECT 'GRANT ' || rp.privilege_type || ' ON ' || COALESCE(r.routine_type, 'FUNCTION') || ' ' || quote_ident(dest_schema) || '.' || quote_ident(rp.routine_name) || ' (' || pg_get_function_identity_arguments(p.oid) || ') TO ' || string_agg(distinct rp.grantee, ',') || ';' as func_dcl
    FROM information_schema.routine_privileges rp, information_schema.routines r, pg_proc p, pg_namespace n
    WHERE rp.routine_schema = quote_ident(source_schema)
      AND rp.is_grantable = 'YES'
      AND rp.routine_schema = r.routine_schema
      AND rp.routine_name = r.routine_name
      AND rp.routine_schema = n.nspname
      AND n.oid = p.pronamespace
      AND p.proname = r.routine_name
    GROUP BY rp.privilege_type, r.routine_type, rp.routine_name, pg_get_function_identity_arguments(p.oid)
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
    -- Issue#78 FIX: handle case-sensitive names with quote_ident() on t.relname      
    quote_ident(dest_schema) || '.' || quote_ident(tb.table_name) || ' TO ' || string_agg(tb.grantee, ',') || ';' as tbl_dcl
    FROM information_schema.table_privileges tb, pg_class c, pg_namespace n
    WHERE tb.table_schema = quote_ident(source_schema) AND tb.table_name = c.relname AND c.relkind in ('r', 'p', 'v', 'm')
      AND c.relnamespace = n.oid AND n.nspname = quote_ident(source_schema)
      GROUP BY c.relkind, tb.privilege_type, tb.table_schema, tb.table_name
  LOOP
    BEGIN
      cnt := cnt + 1;
      -- RAISE NOTICE 'DEBUG: ddl=%', arec.tbl_dcl;
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


  -- LOOP for regular tables and populate them if specified
  -- Issue#75 moved from big table loop above to here.
  IF include_recs THEN
    EXECUTE 'SET search_path = ' || quote_ident(dest_schema) ;
    action := 'Copy Rows';
    FOREACH tblelement IN ARRAY tblarray
    LOOP 
       EXECUTE tblelement;       
       GET DIAGNOSTICS cnt = ROW_COUNT;  
       buffer = substring(tblelement, 13);
       SELECT POSITION(' OVERRIDING SYSTEM VALUE SELECT ' IN buffer) INTO cnt2; 
       IF cnt2 = 0 THEN
           SELECT POSITION(' SELECT ' IN buffer) INTO cnt2;
           buffer = substring(buffer,1, cnt2);       
       ELSE
           buffer = substring(buffer,1, cnt2);       
       END IF;
       SELECT RPAD(buffer, 35, ' ') INTO buffer;
       IF verbose_ THEN
           RAISE NOTICE ' Populated cloned table, %   Rows Copied: %', buffer, cnt;
       END IF;
       tblscopied := tblscopied + 1;
    END LOOP;
    
    -- Issue#79 implementation
    -- Do same for tables with user-defined elements
    FOREACH tblelement IN ARRAY tblarray2
    LOOP 
       EXECUTE tblelement;       
       GET DIAGNOSTICS cnt = ROW_COUNT;  
       cnt2 = POSITION(' FROM ' IN tblelement::text);
       IF cnt2 > 0 THEN
           buffer = substring(tblelement, 1, cnt2);
           buffer = substring(buffer, 6);
           SELECT RPAD(buffer, 35, ' ') INTO buffer;
           IF verbose_ THEN           
               RAISE NOTICE ' Populated cloned table, %   Rows Copied: %', buffer, cnt;
           END IF;
           tblscopied := tblscopied + 1;
       END IF;
    END LOOP;    

  END IF;
  RAISE NOTICE '      TABLES copied: %', LPAD(tblscopied::text, 5, ' ');

  
  -- Issue#78 forces us to defer FKeys until the end since we previously did row copies before FKeys
  --  add FK constraint
  action := 'FK Constraints';
  cnt := 0;

  -- Issue#61 FIX: use set_config for empty string
  -- SET search_path = '';
  SELECT set_config('search_path', '', false) into v_dummy;

  FOR qry IN
    SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname)
                          || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || REPLACE(pg_get_constraintdef(ct.oid), 'REFERENCES ' || quote_ident(source_schema) || '.', 'REFERENCES ' 
                          || quote_ident(dest_schema) || '.') || ';'
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


  IF src_path_old = '' THEN
    -- RAISE NOTICE 'Restoring old search_path to empty string';
    SELECT set_config('search_path', '', false) into v_dummy;
  ELSE
    -- RAISE NOTICE 'Restoring old search_path to:%', src_path_old;
    EXECUTE 'SET search_path = ' || src_path_old;
  END IF;

  EXCEPTION
     WHEN others THEN
     BEGIN
         GET STACKED DIAGNOSTICS v_diag1 = MESSAGE_TEXT, v_diag2 = PG_EXCEPTION_DETAIL, v_diag3 = PG_EXCEPTION_HINT, v_diag4 = RETURNED_SQLSTATE, v_diag5 = PG_CONTEXT, v_diag6 = PG_EXCEPTION_CONTEXT;
         -- v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1 || ' .' || v_diag2 || ' .' || v_diag3;
         v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1;
         RAISE EXCEPTION 'Action: %  Diagnostics: %',action, v_ret;

         IF src_path_old = '' THEN
           -- RAISE NOTICE 'setting old search_path to empty string';
           SELECT set_config('search_path', '', false);
         ELSE
           -- RAISE NOTICE 'setting old search_path to:%', src_path_old;
           EXECUTE 'SET search_path = ' || src_path_old;
         END IF;

         RETURN;
     END;

RETURN;
END;

$BODY$
  LANGUAGE plpgsql VOLATILE  COST 100;
-- ALTER FUNCTION public.clone_schema(text, text, boolean, boolean, boolean) OWNER TO postgres;


