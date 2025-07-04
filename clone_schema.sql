/******************************************************************************

MIT License

Copyright (c) 2019 -2025  Denish Patel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

******************************************************************************/

-- Change History: 
-- 2021-03-03  MJV FIX: Fixed population of tables with rows section. "buffer" variable was not initialized correctly. Used new variable, tblname, to fix it.
-- 2021-03-03  MJV FIX: Fixed Issue#34  where user-defined types in declare section of functions caused runtime errors.
-- 2021-03-04  MJV FIX: Fixed Issue#35  where privileges for functions were not being set correctly causing the program to bomb and giving privileges to other users that should not have gotten them.
-- 2021-03-05  MJV FIX: Fixed Issue#36  Fixed table and other object permissions
-- 2021-03-05  MJV FIX: Fixed Issue#37  Fixed function grants again for case where parameters have default values.
-- 2021-03-08  MJV FIX: Fixed Issue#38  fixed issue where source schema specified for executed trigger function action
-- 2021-03-08  MJV FIX: Fixed Issue#39  Add warnings for table columns that are user-defined since the probably refer back to the source schema!  No fix for it at this time.
-- 2021-03-09  MJV FIX: Fixed Issue#40  Rewrote trigger SQL instead to simply things for all cases
-- 2021-03-19  MJV FIX: Fixed Issue#39  Added new function to generate table ddl instead of using the CREATE TABLE LIKE statement only for use cases with user-defined column datatypes.
-- 2021-04-02  MJV FIX: Fixed Issue#43  Fixed views case where view was created successfully in target schema, but referenced table was not.
-- 2021-06-30  MJV FIX: Fixed Issue#46  Invalid record reference, tbl_ddl.  Changed to tbl_dcl in PRIVS section.
-- 2021-06-30  MJV FIX: Fixed Issue#46  Invalid record reference, tbl_ddl.  Changed to tbl_dcl in PRIVS section. Thanks to dpmillerau for this fix.
-- 2021-07-21  MJV FIX: Fixed Issue#47  Fixed resetting search path to what it was before.  Thanks to dpmillerau for this fix.
-- 2022-03-01  MJV FIX: Fixed Issue#61  Fixed more search_path problems. Modified get_table_ddl() to hard code search_path to public. Using set_config() for empty string instead of trying to set empty string directly and incorrectly.
-- 2022-03-01  MJV FIX: Fixed Issue#62  Added comments for indexes only (Thanks to @guignonv).  Still need to add comments for other objects.
-- 2022-03-24  MJV FIX: Fixed Issue#63  Use last used value for sequence not the start value
-- 2022-03-24  MJV FIX: Fixed Issue#59  Implement Rules
-- 2022-03-26  MJV FIX: Fixed Issue#65  Check column availability in selecting query to use for pg_proc table.  Also do some explicit datatype mappings for certain aggregate functions.  Also fixed inheritance derived tables.
-- 2022-03-31  MJV FIX: Fixed Issue#66  Implement Security Policies for RLS
-- 2022-04-02  MJV FIX: Fixed Issue#62  Fixed all comments and reworked the way we generate index comments by @guignonv
-- 2022-04-02  MJV FIX: Fixed Issue#67  Reworked get_table_ddl() so we are not dependent on outside function, pg_get_tabledef().
-- 2022-04-02  MJV FIX: Fixed Issue#42  Fixed copying rows logic with exception of tables with user-defined datatypes in them that have to be done manually, documented in README.
-- 2022-05-01  MJV FIX: Fixed Issue#53  Applied coding style fixes, using pgFormatter as basis for SQL.
-- 2022-05-02  MJV FIX: Fixed Issue#72  Remove original schema references from materialized view definition
-- 2022-05-14  MJV FIX: Fixed Issue#73  Fix dependency order for views depending on other views. Also removed duplicate comment logic for views.
-- 2022-06-12  MJV FIX: Fixed Issue#74  Change comments ddl from source_scshema to dest_schema. Policies fix using quote_literal(d.description) instead of hard-coded ticks and escape ticks.
-- 2022-06-13  MJV FIX: Fixed Issue#75  Rows were not being copied correctly for parents.  Needed to move copy rows logic to end, after all DDL is done.
-- 2022-06-15  MJV FIX: Fixed Issue#76  RLS is not being enabled for cloned tables.  Enable it right after the policy for the table is created
-- 2022-06-16  MJV FIX: Fixed Issue#78  Fix case-sensitive object names by using quote_ident() all over the place. Also added restriction to not allow case-sensitive target schemas.
-- 2022-06-16  MJV FIX: Fixed Issue#78  Also, since we deferred row copies until the end, we must also defer foreign key constraints to the end as well. 
-- 2022-06-18  MJV FIX: Fixed Issue#79  Fix copying of rows in tables with user-defined column datatypes using COPY method.
-- 2022-06-29  MJV FIX: Fixed Issue#80  Fix copying of rows reported error due to arrays not being initialized properly.
-- 2022-07-15  MJV FIX: Fixed Issue#81  Fix COPY import format for handling NULLs correctly.
-- 2022-09-16  MJV FIX: Fixed Issue#82  Set search_path to public when creating user-defined columns in tables to handle public datatypes like PostGIS. Also fixed a bug in DDL only mode.
-- 2022-09-19  MJV FIX: Fixed Issue#83  Tables with CONSTRAINT DEFs are duplicated as CREATE INDEX statements. Removed CREATE INDEX statements if already defined as CONSTRAINTS.
-- 2022-09-27  MJV FIX: Fixed Issue#85  v13 postgres needs stricter type casting than v14
-- 2022-09-29  MJV FIX: Fixed Issue#86  v12+ handle generated columns by not trying to insert rows into them
-- 2022-09-29  MJV FIX: Fixed Issue#87  v10 requires double quotes around collation name, 11+ doesnt care
-- 2022-12-02  MJV FIX: Fixed Issue#90  Clone functions before views to avoid cloning error for views that call functions.
-- 2022-12-02  MJV FIX: Fixed Issue#91  Fix ownership of objects.  Currently it is defaulting to the one running this script. Let it be the same owner as the source schema to preserve access control.
-- 2022-12-02  MJV FIX: Fixed Issue#92  Default privileges error: Must set the role before executing the command.
-- 2022-12-03  MJV FIX: Fixed Issue#94  Make parameters variadic
-- 2022-12-04  MJV FIX: Fixed Issue#96  PG15 may not populate the collcollate and collctype columns of the pg_collation table.  Handle this.
-- 2022-12-04  MJV FIX: Fixed Issue#97  Regression testing: invalid CASE STATEMENT syntax found.  PG13 is stricter than PG14 and up.  Remove CASE from END CASE to terminate CASE statements.
-- 2022-12-05  MJV FIX: Fixed Issue#95  Implemented owner/ACL rules.
-- 2022-12-06  MJV FIX: Fixed Issue#98  Materialized Views are not populated because they are created before the regular tables are populated. Defer until after tables are populated.
-- 2022-12-07  MJV FIX: Fixed Issue#99  Tables and indexes should mimic the same tablespace used in the source schema.  Only indexes where doing this. Fixed now so both use the same source tablespace.
-- 2022-12-22  MJV FIX: Fixed Issue#100 Fixed case for user-defined type in public schema not handled: citext. See #82 issue that missed this one.
-- 2022-12-22  MJV FIX: Fixed Issue#101 Enhancement: More debugging info, exceptions print out version.
-- 2023-01-10  MJV FIX: Fixed Issue#102 Add alternative to export/import for UDTs, use "text" as an intermediate cast.
--                                      ex: INSERT INTO clone1.address2 (id2, id3, addr) SELECT id2::text::clone1.udt_myint, id3::text::clone1.udt_myint, addr FROM sample.address;
-- 2023-05-17  MJV FIX: Fixed Issue#103 2 problems: handling multiple partitioned tables and not creating FKEYS on partitioned tables since the FKEY created on the parent already propagated down to the partitions.
--                                      The first problem is fixed by modifying the query to work with the current table only.  The 2nd one??????
-- 2023-07-07  EVK FIX: Merged          Fixed problems with the parameters to FUNCTION clone_schema being (text, text, cloneparms[]) instead of (text, text, boolean, boolean) 
--                                      which resulted in the example grant and the drop not working correctly. Also removed some trailing whitespace. Cheers, Ellert van Koperen.
-- 2023-08-04  MJV FIX: Fixed Issue#105 Use the extension's schema not the table's schema.  Don't assume public schema.
-- 2023-09-07  MJV FIX: Fixed Issue#107 Fixed via pull request#109. Increased output length of sequences and identities from 2 to 5.  Also changed SQL for gettting identities owner.
-- 2023-09-07  MJV FIX: Fixed Issue#108:enclose double-quote roles with special characters for setting "OWNER TO"
-- 2024-01-15	 MJV FIX: Fixed Issue#114: varchar arrays cause problems use pg_col_def func() from pg_get_tabledef to fix the problem
-- 2024-01-21  MJV ENH: Add more debug info when sql excecution errors (lastsql variable)
-- 2024-01-22  MJV FIX: Fixed Issue#113: quote_ident() the policy name, and also do not use "qual" column when policy is an INSERT command since it is always null.
-- 2024-01-23  MJV FIX: Fixed Issue#111: defer triggers til after we populate the tables, just like we did with FKeys (Issue#78). See example with emp table and emp_stamp trigger that updates inserted row.
-- 2024-01-24  MJV FIX: Fixed Issue#116: defer creation of materialized view indexes until after we create the deferred materialized views via issue#98.
-- 2024-01-28  MJV FIX: Fixed Issue#117: Fix getting table privs SQL: string_agg wasn't working and no need to double-quote the grantee, that was only intended for owner DDL (Issue#108)
-- 2024-02-20  MJV FIX: Fixed Issue#121: Fix handling of autogenerated columns besides IDENTITY ones.  This required major rewrite to how we get table definition.
--                                       We get it from another gihub project owned by the primary coder of this project, Michael Vitale (https://github.com/MichaelDBA/pg_get_tabledef).
-- 2024-02-22  MJV FIX: Fixed Issue#120: Set sequence owner to column to tie it to the table with the sequence.
-- 2024-02-22  MJV FIX: Fixed Issue#124: Cloning a cloned schema will cause identity column mismatches that could cause subsequent foreign key defs to fail. Use OVERRIDING SYSTEM VALUE.
-- 2024-02-23  MJV FIX: Fixed Issue#123: Do not assign anything to system roles.
-- 2024-03-05  MJV FIX: Fixed Issue#125: Fix case where tablespace def occurs after the WHERE clause of a partial index creation.  It must occur BEFORE the WHERE clause. Corresponds to pg_get_tabledef issue#25.
-- 2024-03-05  MJV FIX: Fixed Issue#126: Fix search path to pick up public stuff as well as source schema stuff --> search_path = '<source schema>','public'\
-- 2024-04-15  MJV FIX: Fixed Issue#130: Apply pg_get_tabledef() fix (#26), refreshed function paste.
-- 2024-09-11  MJV FIX: Fixed Issue#132: Fix case where NOT NULL appended twice to IDENTITY columns. Corresponds to pg_get_tabledef issue#28.
-- 2024-10-01  MJV FIX: Fixed Issue#136: Fixed issue#30 in pg_get_tabledef().
-- 2024-10-21  MJV FIX: Fixed Issue#133: Defer creation of Views dependent on MVs.  Also, for cases where DATA is specified, needed to change the order of things...Also, had to fix bug with altering index names.
--                                       When a table is created with the LIKE condition, the index names do not match the original.  They take the form, <table name>_<column name>_idx.  Multiple <column_name> if composite index.
--                                       so don't try to rename anymore if we can't match new to original.
-- 2024-10-29  MJV FIX: Fixed Issue#131: Use double-quotes around schemas with funky chars
-- 2024-10-30  MJV FIX: Fixed Issue#138: conversion changes for PG v17: fixed queries for domains.
-- 2024-11-05  MJV FIX: Fixed Issue#139: change return type from VOID to INTEGER for programatic error handling.
-- 2024-11-08  MJV FIX: Fixed Issue#141: Remove/rename function types (obj_type-->objj_type, perm_type-->permm_type) before exiting function and put them in the public schema so they don't get propagated during the cloning process.
-- 2024-11-14  MJV FIX: Fixed Issue#140: More issues with non-standard schema names requiring quoting. Also required changes to pg_get_tabledef().
-- 2024-11-16  MJV FIX: Fixed Issue#142: Totally rewrote how sequences, serial, and identity columns were being created, altered, and setval for them.
-- 2024-11-20  MJV FIX: Fixed Issue#143: Apply changes to pg_get_tabledef() related to issue#32.  Also removed debugging from pg_get_tabledef() when called from here in verbose mode.  Call it directly to debug.
-- 2024-11-24  MJV FIX: Fixed Issue#143: Apply changes to pg_get_tabledef() related to issue#27.  Implements outputting optional owner acl, but not used by clone_schema at the present time.
-- 2024-11-26  MJV FIX: Fixed Issue#145: Apply changes to pg_get_tabledef() related to issue#36.  Bugs related to PG version 10.
-- 2024-12-07  MJV FIX: Fixed Issue#146: Apply changes to pg_get_tabledef() related to duplicate nextval statements for sequences.
-- 2024-12-12  MJV FIX: Fixed Issue#147: Handle case where trigger function resides in the public schema.  Right now, only source schema is considered for trigger functions.  Only the trigger def needs to be in the source schema.
-- 2024-12-14  MJV FIX: Fixed Issue#148: Handle case-sensitive TYPEs correctly.  Required fix to underlying function, pg_get_tabledef() as well.
-- 2024-12-19  MJV FIX: Fixed Issue#149: Handle case-sensitive USER-DEFINED column types when copying data directly. Workaround is to use the FILECOPY option.
-- 2024-12-24  MJV FIX: Fixed Issue#150: Major clean up DDLONLY output: (1) Prefix UNIQUE indexes with "INFO:  ". (2) fixed case-sensitive problem with ALTER TABLE. (3) fixed problem with child tables created before parent.
-- 2024-12-24  MJV FIX: Fixed Issue#150: Major clean up continued:      (4) Added SET ROLE logic after creating DEFAULT PRIVS. (5) Added "INFO:" lines when creating indexes. See "Issue#150" for all fixes.
-- 2025-06-18  MJV FIX: Fixed Issue#152: a tablespace clause must appear before the WHERE clause in an index definition for case-sensitive schemas.  Required fix to pg_get_tabledef(), issue#39

do $$ 
<<first_block>>
DECLARE
    cnt int;
BEGIN
  DROP TYPE IF EXISTS public.cloneparms CASCADE;
  CREATE TYPE public.cloneparms AS ENUM ('DATA', 'NODATA','DDLONLY','NOOWNER','NOACL','VERBOSE','DEBUG','FILECOPY','DEBUGEXEC');
  -- END IF;
end first_block $$;

DROP FUNCTION IF EXISTS public.get_insert_stmt_ddl(text, text, text, boolean, boolean);
-- select * from public.get_insert_stmt_ddl('clone1','sample','address');
CREATE OR REPLACE FUNCTION public.get_insert_stmt_ddl(
  source_schema text,
  target_schema text,
  atable text,
  bTextCast boolean default False,
  bIdentity boolean default False
)
RETURNS text
LANGUAGE plpgsql VOLATILE
AS
$$
  DECLARE
    -- the ddl we're building
    v_insert_ddl text := '';
    v_cols       text := '';
    v_cols_sel   text := '';
    v_cnt        int  := 0;
    v_colrec     record;
    v_schema     text;
  BEGIN
    FOR v_colrec IN
      -- Issue#149  Handle case-sensitive and keywords for user-defined types
      -- SELECT c.column_name, c.data_type, c.udt_name, c.udt_schema, c.character_maximum_length, c.is_nullable, c.column_default, c.numeric_precision, c.numeric_scale, c.is_identity, c.identity_generation, c.is_generated 
      SELECT quote_ident(c.column_name) as column_name, c.data_type, quote_ident(c.udt_name) as udt_name, c.udt_schema, c.character_maximum_length, c.is_nullable, c.column_default, c.numeric_precision, c.numeric_scale, c.is_identity, c.identity_generation, c.is_generated 
      FROM information_schema.columns c WHERE (table_schema, table_name) = (source_schema, atable) ORDER BY ordinal_position
    LOOP
      IF v_colrec.udt_schema = 'public' THEN
        v_schema = 'public';
      ELSE
        v_schema = target_schema;
      END IF;
      
      v_cnt = v_cnt + 1;
      -- RAISE NOTICE 'DEBUG atable=%  colname=%  datatype=%  udtname=%  coldflt=%  isidentity=%  identgen=%  isgenerated=%', atable, v_colrec.column_name,v_colrec.data_type,v_colrec.udt_name,v_colrec.column_default,v_colrec.is_identity,v_colrec.identity_generation,v_colrec.is_generated;
      IF v_colrec.is_identity = 'YES' AND v_colrec.identity_generation = 'ALWAYS' THEN
        -- Issue#124: we don't skip identity columns anymore just override them
        -- skip
        -- continue;
        bIdentity = True;
        -- RAISE NOTICE 'not skipping identity columns so that we can override and use exact values instead of starting with the nextval!';
      ELSEIF v_colrec.is_generated = 'ALWAYS' THEN
          -- we do skip these
          -- RAISE NOTICE 'DEBUG skipping autogenerated column, %.%',atable,v_colrec.column_name;
          continue;
      END IF;

      IF v_colrec.data_type = 'USER-DEFINED' THEN
        IF v_cols = '' THEN
          v_cols     = v_colrec.column_name;
          IF bTextCast THEN 
            -- v_cols_sel = v_colrec.column_name || '::text::' || v_schema || '.' || v_colrec.udt_name;
            IF v_schema = 'public' THEN
              v_cols_sel = v_colrec.column_name || '::' || v_schema || '.' || v_colrec.udt_name;
            ELSE
              v_cols_sel = v_colrec.column_name || '::text::' || v_colrec.udt_name;
            END IF;
          ELSE
            v_cols_sel = v_colrec.column_name || '::' || v_schema || '.' || v_colrec.udt_name;
          END IF;
        ELSE 
          v_cols     = v_cols     || ', ' || v_colrec.column_name;
          IF bTextCast THEN 
            -- v_cols_sel = v_cols_sel || ', ' || v_colrec.column_name || '::text::' || v_schema || '.' || v_colrec.udt_name;
            IF v_schema = 'public' THEN
              v_cols_sel = v_cols_sel || ', ' || v_colrec.column_name || '::' || v_schema || '.' || v_colrec.udt_name;
            ELSE
              v_cols_sel = v_cols_sel || ', ' || v_colrec.column_name || '::text::' || v_colrec.udt_name;
            END IF;
          ELSE
            v_cols_sel = v_cols_sel || ', ' || v_colrec.column_name || '::' || v_schema || '.' || v_colrec.udt_name;
          END IF;
        END IF;
      ELSE
        IF v_cols = '' THEN
          v_cols     = v_colrec.column_name;
          v_cols_sel = v_colrec.column_name;
        ELSE 
          v_cols     = v_cols     || ', ' || v_colrec.column_name;
          v_cols_sel = v_cols_sel || ', ' || v_colrec.column_name;
        END IF;
      END IF;
    END LOOP;
 
    -- Issue#140: abort if no columns detected, shouldn't happen
    IF v_cols = '' THEN
        RAISE WARNING 'No columns detected for schema:% and table:%', source_schema, atable;
        RETURN '';
    END IF;
    
    -- put it all together and return the insert statement
    -- INSERT INTO clone1.address2 (id2, id3, addr) SELECT id2::text::clone1.udt_myint, id3::text::clone1.udt_myint, addr FROM sample.address;  
    IF bIdentity THEN
        -- Issue#124 Fix
        -- Issue#140
        -- v_insert_ddl = 'INSERT INTO ' || target_schema || '.' || atable || ' (' || v_cols || ') OVERRIDING SYSTEM VALUE ' || 'SELECT ' || v_cols_sel || ' FROM ' || source_schema || '.' || atable || ';';    
        v_insert_ddl = 'INSERT INTO ' || quote_ident(target_schema) || '.' || atable || ' (' || v_cols || ') OVERRIDING SYSTEM VALUE ' || 'SELECT ' || v_cols_sel || ' FROM ' || quote_ident(source_schema) || '.' || atable || ';';    
    ELSE
        -- Issue#140
        -- v_insert_ddl = 'INSERT INTO ' || target_schema || '.' || atable || ' (' || v_cols || ') ' || 'SELECT ' || v_cols_sel || ' FROM ' || source_schema || '.' || atable || ';';
        v_insert_ddl = 'INSERT INTO ' || quote_ident(target_schema) || '.' || atable || ' (' || v_cols || ') ' || 'SELECT ' || v_cols_sel || ' FROM ' || quote_ident(source_schema) || '.' || atable || ';';
        
    END IF;
    RETURN v_insert_ddl;
  END;
$$;

-- Issue#121: removed deprecated function, public.get_table_ddl()
-- Issue#121: removed deprecated function, public.get_table_ddl_complex()
-- Issue#121: add external project function, pg_get_tabledef() as a replacement.
-- Issue#130: apply pg_get_tabledef() fix (#26)

/****************************************************/
/*  Drop In function pg_get_tabledef starts here... */
/****************************************************/

/* ********************************************************************************
COPYRIGHT NOTICE FOLLOWS.  DO NOT REMOVE
Copyright (c) 2021-2025 SQLEXEC LLC

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

************************************************************************************ */

-- History:
-- Date	     Description
-- ==========   ======================================================================  
-- 2021-03-20   Original coding using some snippets from 
--              https://stackoverflow.com/questions/2593803/how-to-generate-the-create-table-sql-statement-for-an-existing-table-in-postgr
-- 2021-03-21   --------  Added partitioned table support, i.e., PARTITION BY clause.
-- 2021-03-21   --------  Added WITH clause logic where storage parameters for tables are set.
-- 2021-03-22   --------  Added tablespace logic for tables and indexes.
-- 2021-03-24   --------  Added inheritance-based partitioning support for PG 9.6 and lower.
-- 2022-09-12   Issue#1:  Added fix for PostGIS columns where we do not presume the schema, leave without schema to imply public schema
-- 2022-09-19   Issue#2:  Do not add CREATE INDEX statements if the indexes are defined within the Table definition as ADD CONSTRAINT.
-- 2022-12-03   --------  Handle NULL condition for ENUMs
-- 2022-12-07   --------  not setting tablespace correctly for user defined tablespaces
-- 2023-04-12   Issue#6:  Handle array types: int, bigint, varchar, even varchars with precisions.
-- 2023-04-13   Issue#7:  Incomplete fixing of issue#6
-- 2023-04-21   Issue#8:  previously returns actual sequence info (aka \d) instead of serial/bigserial def.
-- 2023-04-21   Issue#10: Consolidated comments into one place under function prototype heading.
-- 2023-05-17   Issue#13: do not specify FKEY for partitions. It is done on the parent and implied on the partitions, else you get "fkey already exists" error
-- 2023-05-20   --------  syntax error, missing THEN keyword
-- 2023-05-20   Issue#11: Handle parent of table being in another schema
-- 2023-07-24   Issue#14: If multiple triggers are defined on a table, show them all not just the first one.
-- 2023-08-03   Issue#15: use utd_schema with USER-DEFINED data types, not defaulting to table schema.
-- 2023-08-03   Issue#16: Make it optional to define the PKEY as external instead of internal.
-- 2023-08-24   Issue#17: Handle case-sensitive tables.
-- 2023-08-26   Issue#17: Had to remove quote_ident when identifying case sensitive tables
-- 2023-08-28   Issue#19: Identified in pull request#18: double-quote reserved keywords
-- 2024-01-25   Issue#20: Handle output for specifying PKEY_EXTERNAL and FKEYS_EXTERNAL options, which misses all other non-primary constraints.
-- 2024-02-18   Issue#22: Handle FKEYS_NONE input option, which was previously ignored.
-- 2024-02-19   Issue#23: Handle complex autogenerated columns. Also append NOT NULL to IDENTITY columns even though technically not necessary.
-- 2024-02-23   Issue#24: Fix empty table problem where we accidentally removed the closing paren thinking a column delimited commas was there...
-- 2024-03-05   Issue#25: Fix case where tablespace def occurs after the WHERE clause of a partial index creation.  It must occur BEFORE the WHERE clause.
-- 2024-04-15   Issue#26: Fix case for partition table unique indexes by adding the IF NOT EXISTS phrase, which we already do for non-unique indexes
-- 2024-09-11   Issue#28: Avoid duplication of NOT NULL for identity columns.
-- 2024-09-20   Issue#29: added verbose info for searchpath problems.
-- 2024-10-01   Issue#30: Fixed column def with geometry point defined - geometry geometry(Point, 4326) 
-- 2024-11-13   Issue#31: Case-sensitive schemas not handled correctly.
-- 2024-11-20   Issue#32: Show explicit sequence default output, not SERIAL types to emulate the way PG does it. Also use dt2 (formatted), not dt1
-- 2024-11-20   Issue#33: Show partition info for parent table if SHOWPARTS enumeration specified
-- 2024-11-24   Issue#27: V 2.0 NEW Feature: Add owner info if requested through 'OWNER_ACL' 
-- 2024-11-25   Issue#35: V 2.0 NEW featrue: Add option for all other ACLs for a table in addition to the owner, option='ALL_ACLS', including policies (row security).
-- 2024-11-26   Issue#36: Fixed issue with PG v9.6 not calling pg_get_coldef() correctly. Also removed attgenerated since not in PG v10 and not used anywhere anyhows
-- 2024-12-15   Issue#37: Fixed issue with case-sensitive user-defined types are not being enclosed with double-quotes.
-- 2024-12-26   --------: Updated License info for GNU
-- 2025-04-15   Issue#38: Updated License info to specify MIT instead of GNU since MIT is more permissive
-- 2025-06-18   Issue#39: Handle tablespace location where schema is case-sensitive. Also, discovered that tablespace not being added to PG 9.6 versions.

DROP TYPE IF EXISTS public.tabledefs CASCADE;
CREATE TYPE public.tabledefs AS ENUM ('PKEY_INTERNAL','PKEY_EXTERNAL','FKEYS_INTERNAL', 'FKEYS_EXTERNAL', 'COMMENTS', 'FKEYS_NONE', 'INCLUDE_TRIGGERS', 'NO_TRIGGERS', 'SHOWPARTS', 'ACL_OWNER', 'ACL_DCL','ACL_POLICIES');

-- SELECT * FROM public.pg_get_coldef('sample','orders','id');
-- DROP FUNCTION public.pg_get_coldef(text,text,text,boolean);
CREATE OR REPLACE FUNCTION public.pg_get_coldef(
  in_schema text,
  in_table  text,
  in_column text,
  oldway    boolean default False
)
RETURNS text
LANGUAGE plpgsql VOLATILE
AS
$$
DECLARE
v_coldef     text;
v_dt1        text;
v_dt2        text;
v_dt3        text;
v_nullable   boolean;
v_position   int; 
v_identity   text; 
v_hasdflt    boolean; 
v_dfltexpr   text;

BEGIN
  IF oldway THEN 
    SELECT pg_catalog.format_type(a.atttypid, a.atttypmod) INTO v_coldef FROM pg_namespace n, pg_class c, pg_attribute a, pg_type t 
    WHERE n.nspname = in_schema AND n.oid = c.relnamespace AND c.relname = in_table AND a.attname = in_column and a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum;
    -- RAISE NOTICE 'DEBUG: oldway=%',v_coldef;
  ELSE
    -- a.attrelid::regclass::text, a.attname
    -- Issue#32: bypass the following query which converts to serial and bypasses explicit sequence defs
    -- SELECT CASE WHEN a.atttypid = ANY ('{int,int8,int2}'::regtype[]) AND EXISTS (SELECT FROM pg_attrdef ad WHERE ad.adrelid = a.attrelid AND ad.adnum   = a.attnum AND 
	  -- pg_get_expr(ad.adbin, ad.adrelid) = 'nextval(''' || (pg_get_serial_sequence (a.attrelid::regclass::text, a.attname))::regclass || '''::regclass)') THEN CASE a.atttypid 
	  -- WHEN 'int'::regtype  THEN 'serial' WHEN 'int8'::regtype THEN 'bigserial' WHEN 'int2'::regtype THEN 'smallserial' END ELSE format_type(a.atttypid, a.atttypmod) END AS data_type  
	  -- INTO v_coldef FROM pg_namespace n, pg_class c, pg_attribute a, pg_type t 
	  -- WHERE n.nspname = in_schema AND n.oid = c.relnamespace AND c.relname = in_table AND a.attname = in_column and a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum;
	  -- RAISE NOTICE 'DEBUG: newway=%',v_coldef;
	  
	  -- WHERE n.nspname = 'sequences' AND n.oid = c.relnamespace AND c.relname = 'atable' AND a.attname = 'key' and a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum;	  	  
	  --  data_type
		-- -----------
		--  serial

	  -- WHERE n.nspname = 'sequences' AND n.oid = c.relnamespace AND c.relname = 'vectors3' AND a.attname = 'id' and a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum;	  
    -- data_type
    -- -----------
    -- bigint

    -- Issue#32: show integer types, not serial types as output
    SELECT a.atttypid::regtype AS dt1, format_type(a.atttypid, a.atttypmod) as dt2, t.typname as dt3, CASE WHEN not(a.attnotnull) THEN True ELSE False END AS nullable, 
    -- Issue#36: removed column attgenerated since we do not use it anywhere and not in PGv10
    -- a.attnum, a.attidentity, a.attgenerated, a.atthasdef, pg_get_expr(ad.adbin, ad.adrelid) dfltexpr 
    -- INTO v_dt1, v_dt2, v_dt3, v_nullable, v_position, v_identity, v_generated, v_hasdflt, v_dfltexpr 
    a.attnum, a.attidentity, a.atthasdef, pg_get_expr(ad.adbin, ad.adrelid) dfltexpr 
    INTO v_dt1, v_dt2, v_dt3, v_nullable, v_position, v_identity, v_hasdflt, v_dfltexpr 
    FROM pg_attribute a JOIN pg_class c ON (a.attrelid = c.oid) JOIN pg_type t ON (a.atttypid = t.oid) LEFT JOIN pg_attrdef ad ON (a.attrelid = ad.adrelid AND a.attnum = ad.adnum) 
    -- WHERE c.relkind in ('r','p') AND a.attnum > 0 AND NOT a.attisdropped AND c.relnamespace::regnamespace::text = in_schema AND c.relname = in_table AND a.attname = in_column;
    WHERE c.relkind in ('r','p') AND a.attnum > 0 AND NOT a.attisdropped AND c.relnamespace::regnamespace::text = quote_ident(in_schema) AND c.relname = in_table AND a.attname = in_column;
	  -- RAISE NOTICE 'schema=%  table=%  column=%  dt1=%  dt2=%  dt3=%  nullable=%  pos=%  identity=%   HasDefault=%  DeftExpr=%', in_schema, in_table, in_column, v_dt1,v_dt2,v_dt3,v_nullable,v_position,v_identity,v_hasdflt,v_dfltexpr;

	  --   WHERE c.relkind in ('r','p') AND a.attnum > 0 AND NOT a.attisdropped AND c.relnamespace::regnamespace::text = 'sequences' AND c.relname = 'atable' AND a.attname = 'key';
		--    dt1   |   dt2   | dt3  | nullable | attnum | attidentity | attgenerated | atthasdef |                      dfltexpr
		-- ---------+---------+------+----------+--------+-------------+--------------+-----------+-----------------------------------------------------
		--  integer | integer | int4 | f        |      1 |             |              | t         | nextval('sequences.explicitsequence_key'::regclass)
		
		--     WHERE c.relkind in ('r','p') AND a.attnum > 0 AND NOT a.attisdropped AND c.relnamespace::regnamespace::text = 'sequences' AND c.relname = 'vectors3' AND a.attname = 'id';
		--   dt1   |  dt2   | dt3  | nullable | attnum | attidentity | attgenerated | atthasdef | dfltexpr
		-- --------+--------+------+----------+--------+-------------+--------------+-----------+----------
		--  bigint | bigint | int8 | f        |      1 | d           |              | f         |

    -- Issue#32 handled in calling routine, not here
 	  -- CREATE TABLE atable (key integer NOT NULL default nextval('explicitsequence_key'), avalue text);
	  -- IF v_dfltexpr IS NULL OR v_dfltexpr = '' THEN
    -- v_coldef = v_dt1;
    v_coldef = v_dt2;
	  
  END IF;
  RETURN v_coldef;
END;
$$;

-- SELECT * FROM public.pg_get_tabledef('sample', 'address', false);
DROP FUNCTION IF EXISTS public.pg_get_tabledef(character varying,character varying,boolean,tabledefs[]);
CREATE OR REPLACE FUNCTION public.pg_get_tabledef(
  in_schema varchar,
  in_table varchar,
  _verbose boolean,
  VARIADIC arr public.tabledefs[] DEFAULT '{}':: public.tabledefs[]
)
RETURNS text
LANGUAGE plpgsql VOLATILE
AS
$$
  DECLARE
    v_version        text := '2.3 December 26, 2024  GNU General Public License 3.0';
    v_schema    text := '';
    v_coldef    text := '';
    v_qualified text := '';
    v_table_ddl text;
    v_table_oid int;
    v_colrec record;
    v_constraintrec record;
    v_trigrec       record;
    v_indexrec record;
    v_rec           record;
    v_constraint_name text;
    v_constraint_def  text;
    v_pkey_def        text := '';
    v_fkey_def        text := '';
    v_fkey_defs       text := '';
    v_trigger text := '';
    v_partition_key text := '';
    v_partbound text;
    v_parent text;
    v_parent_schema text;
    v_persist text;
    v_seqname text := '';
    v_temp  text := ''; 
    v_temp2 text;
    v_relopts text;
    v_tablespace text;
    v_pgversion int;
    v_context text := '';
    bSerial boolean;
    bPartition boolean;
    bInheritance boolean;
    bRelispartition boolean;
    constraintarr text[] := '{}';
    constraintelement text;
    bSkip boolean;
	  bVerbose boolean := False;
	  v_cnt1   integer;
	  v_cnt2   integer;
	  search_path_old text := '';
	  search_path_new text := '';
	  v_partial    boolean;
	  v_pos        integer;
	  v_partinfo   text := '';
	  v_oid        oid;
	  v_partkeydef text := '';
	  v_owner      text := '';
	  v_acl        text := '';

    -- assume defaults for ENUMs at the getgo	
  	pkcnt            int := 0;
  	fkcnt            int := 0;
	  trigcnt          int := 0;
	  cmtcnt           int := 0;
	  showpartscnt     int := 0;
	  aclownercnt      int := 0;
	  acldclcnt        int := 0;
	  aclpolicycnt     int := 0;
    pktype           public.tabledefs := 'PKEY_INTERNAL';
    fktype           public.tabledefs := 'FKEYS_INTERNAL';
    trigtype         public.tabledefs := 'NO_TRIGGERS';
    arglen           integer;
  	vargs            text;
	  avarg            public.tabledefs;

    -- exception variables
    v_ret            text;
    v_diag1          text;
    v_diag2          text;
    v_diag3          text;
    v_diag4          text;
    v_diag5          text;
    v_diag6          text;
	
  BEGIN
    SET client_min_messages = 'notice';
    IF _verbose THEN bVerbose = True; END IF;
    
    SELECT setting from pg_settings where name = 'server_version_num' INTO v_pgversion;
    IF bVerbose THEN RAISE NOTICE 'pg_get_tabledef() version=%    PG version=%', v_version, v_pgversion; END IF;
    
    -- v17 fix: handle case-sensitive  
    -- v_qualified = in_schema || '.' || in_table;
	
    arglen := array_length($4, 1);
    IF arglen IS NULL THEN
        -- nothing to do, so assume defaults
        NULL;
    ELSE
        -- loop thru args
        -- IF 'NO_TRIGGERS' = ANY ($4)
        -- select array_to_string($4, ',', '***') INTO vargs;
        IF bVerbose THEN RAISE NOTICE 'arguments=%', $4; END IF;
        FOREACH avarg IN ARRAY $4 LOOP
            IF bVerbose THEN RAISE NOTICE 'arg=%', avarg; END IF;
            IF avarg = 'FKEYS_INTERNAL' OR avarg = 'FKEYS_EXTERNAL' OR avarg = 'FKEYS_NONE' THEN
                fkcnt = fkcnt + 1;
                fktype = avarg;
            ELSEIF avarg = 'INCLUDE_TRIGGERS' OR avarg = 'NO_TRIGGERS' THEN
                trigcnt = trigcnt + 1;
                trigtype = avarg;
            ELSEIF avarg = 'PKEY_EXTERNAL' THEN
                pkcnt = pkcnt + 1;
                pktype = avarg;				                
            ELSEIF avarg = 'COMMENTS' THEN
                cmtcnt = cmtcnt + 1;
            -- Issue#33 check for dups
            ELSEIF avarg = 'SHOWPARTS' THEN
                showpartscnt = showpartscnt + 1;                
            -- Issue#27
            ELSEIF avarg = 'ACL_OWNER' THEN
                aclownercnt = aclownercnt + 1;                                
            -- Issue#35
            ELSEIF avarg = 'ACL_DCL' THEN
                acldclcnt = acldclcnt + 1;                                                
            ELSEIF avarg = 'ACL_POLICIES' THEN
                aclpolicycnt = aclpolicycnt + 1;                     
                
            END IF;
        END LOOP;
        IF fkcnt > 1 THEN 
  	        RAISE WARNING 'Only one foreign key option can be provided. You provided %', fkcnt;
	          RETURN '';
        ELSEIF trigcnt > 1 THEN 
            RAISE WARNING 'Only one trigger option can be provided. You provided %', trigcnt;
            RETURN '';
        ELSEIF pkcnt > 1 THEN 
            RAISE WARNING 'Only one pkey option can be provided. You provided %', pkcnt;
            RETURN '';			
        ELSEIF cmtcnt > 1 THEN 
            RAISE WARNING 'Only one comments option can be provided. You provided %', cmtcnt;
            RETURN '';			
        ELSEIF showpartscnt > 1 THEN 
            RAISE WARNING 'Only one SHOWPARTS option can be provided. You provided %', showpartscnt;
            RETURN '';			
        -- Issue#27
        ELSEIF aclownercnt > 1 THEN 
            RAISE WARNING 'Only one ACL_OWNER option can be provided. You provided %', aclownercnt;
            RETURN '';			
        -- Issue#35            
        ELSEIF acldclcnt > 1 THEN 
            RAISE WARNING 'Only one ACL_DCL option can be provided. You provided %', acldclcnt;
            RETURN '';			
        ELSEIF aclpolicycnt > 1 THEN 
            RAISE WARNING 'Only one ACL_POLICIES option can be provided. You provided %', aclpolicycnt;
            RETURN '';			
            
        END IF;		   		   
    END IF;

    -- Issue#31 - always handle case-sensitive schemas
    v_schema = quote_ident(in_schema);
    -- RAISE NOTICE 'DEBUG: schema qualified:%  before:%', v_schema, in_schema;

    -- Issue#27 get owner info too
    SELECT c.oid, pg_catalog.pg_get_userbyid(c.relowner) INTO v_table_oid, v_owner FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind in ('r','p') AND c.relname = in_table AND n.nspname = in_schema;

   -- set search_path = public before we do anything to force explicit schema qualification but dont forget to set it back before exiting...
    SELECT setting INTO search_path_old FROM pg_settings WHERE name = 'search_path';

    SELECT REPLACE(REPLACE(setting, '"$user"', '$user'), '$user', '"$user"') INTO search_path_old
    FROM pg_settings
    WHERE name = 'search_path';
    -- RAISE NOTICE 'DEBUG tableddl: saving old search_path: ***%***', search_path_old;
    EXECUTE 'SET search_path = "public"';
    SELECT setting INTO search_path_new FROM pg_settings WHERE name = 'search_path';
    -- RAISE NOTICE 'DEBUG tableddl: using new search path=***%***', search_path_new;
    
    -- throw an error if table was not found
    IF (v_table_oid IS NULL) THEN
      RAISE EXCEPTION 'schema(%) table(%) does not exist %', v_schema, in_table, v_schema || '.' || in_table;
    END IF;    

    -- get user-defined tablespaces if applicable
    SELECT tablespace INTO v_temp FROM pg_tables WHERE schemaname = in_schema and tablename = in_table and tablespace IS NOT NULL;
    IF v_temp IS NULL THEN
      v_tablespace := 'TABLESPACE pg_default';
    ELSE
      v_tablespace := 'TABLESPACE ' || v_temp;
    END IF;
    
    -- also see if there are any SET commands for this table, ie, autovacuum_enabled=off, fillfactor=70
    WITH relopts AS (SELECT unnest(c.reloptions) relopts FROM pg_class c, pg_namespace n WHERE n.nspname = in_schema and n.oid = c.relnamespace and c.relname = in_table) 
    SELECT string_agg(r.relopts, ', ') as relopts INTO v_temp from relopts r;
    IF v_temp IS NULL THEN
      v_relopts := '';
    ELSE
      v_relopts := ' WITH (' || v_temp || ')';
    END IF;
    
    -- Issue#27: set owner ACL info
    IF aclownercnt = 1 OR acldclcnt = 1 THEN
        v_acl = 'ALTER TABLE IF EXISTS ' || quote_ident(in_schema) || '.' || quote_ident(in_table) || ' OWNER TO ' || v_owner || ';' || E'\n' || E'\n';
    END IF;
    
    -- Issue#35: add all other ACL info if directed
    -- only valid in PG 13 and above
    IF acldclcnt = 1 THEN
        -- do the revokes first
        Select 'REVOKE ALL ON TABLE ' || rtg.table_schema || '.' || rtg.table_name || ' FROM ' ||  string_agg(distinct rtg.grantee, ',' ORDER BY rtg.grantee) || ';' INTO v_temp 
		    FROM information_schema.role_table_grants rtg, pg_class c, pg_namespace n  WHERE n.nspname = quote_ident(in_schema) AND n.oid = c.relnamespace AND c.relkind in ('r','p') AND quote_ident(c.relname) = quote_ident(in_table)
        AND n.nspname = rtg.table_schema AND c.relname = rtg.table_name AND pg_catalog.pg_get_userbyid(c.relowner) <> rtg.grantee GROUP BY rtg.table_schema, rtg.table_name ORDER BY 1;
        IF v_temp <> '' THEN
            v_acl = v_acl || v_temp || E'\n' || E'\n';
        END IF;
        
        -- do the grants
        FOR v_rec IN
        WITH ACLs AS (SELECT rtg.grantee as arole,  
				CASE WHEN string_agg(rtg.privilege_type, ',' ORDER BY rtg.privilege_type) = 'DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE' THEN 'ALL' ELSE string_agg(rtg.privilege_type, ',' ORDER BY rtg.privilege_type) END as privs 
				FROM information_schema.role_table_grants rtg, pg_class c, pg_namespace n  WHERE n.nspname = quote_ident(in_schema) AND n.oid = c.relnamespace AND c.relkind in ('r','p') AND c.relname = quote_ident(in_table)
				AND n.nspname = rtg.table_schema AND c.relname = rtg.table_name AND pg_catalog.pg_get_userbyid(c.relowner) <> rtg.grantee AND rtg.grantor <> rtg.grantee GROUP BY 1 ORDER BY 1)
        SELECT 'GRANT ' || acls.privs || ' ON TABLE ' || quote_ident(in_schema) || '.' || quote_ident(in_table) || ' TO ' || acls.arole || ';' as grants FROM ACLs
        LOOP
            v_acl = v_acl || v_rec.grants || E'\n';
        END LOOP;
    END IF;
    
    -- Issue#35: RLS/policies only started in PG version 13
    IF aclpolicycnt = 1 AND v_pgversion > 130000 THEN     
        v_acl = v_acl || E'\n';
        
        -- Enable row security if called for
        SELECT CASE WHEN p.polpermissive IS TRUE THEN 'true' ELSE 'false' END INTO v_temp 
        FROM pg_class c, pg_namespace n, pg_policy p WHERE n.nspname = quote_ident(in_schema) AND c.relkind in ('p','r') AND c.relname = quote_ident(in_table) AND c.oid = p.polrelid limit 1;
        IF v_temp = 'true' THEN
            v_acl =  v_acl || 'ALTER TABLE ' || quote_ident(in_schema) || '.' || quote_ident(in_table) || ' ENABLE ROW LEVEL SECURITY;' || E'\n';
        END IF;
        
        -- get policies if found
        -- For other cases to handle see examples in: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
        FOR v_rec IN
        SELECT c.oid, n.nspname, c.relname, c.relrowsecurity, p.polname, p.polpermissive, pg_get_expr(p.polqual, p.polrelid) _using, pg_get_expr(p.polwithcheck, p.polrelid) acheck, 
        CASE WHEN p.polroles = '{0}' THEN '' ELSE pg_catalog.array_to_string(array(select rolname from pg_catalog.pg_roles where oid = any (p.polroles) order by 1),',') END polroles, p.polcmd, 
        'CREATE POLICY ' ||  p.polname || ' ON ' || n.nspname || '.' || c.relname || CASE WHEN p.polpermissive THEN ' AS PERMISSIVE ' ELSE ' ' END  || 
        CASE p.polcmd WHEN 'r' THEN 'FOR SELECT' WHEN 'a' THEN 'FOR SELECT' WHEN 'w' THEN 'FOR UPDATE' WHEN 'd' THEN 'FOR DELETE' ELSE 'FOR ALL'    END || ' TO ' || 
        CASE WHEN p.polroles = '{0}' THEN 'public' ELSE pg_catalog.array_to_string(array(select rolname from pg_catalog.pg_roles where oid = any (p.polroles) order by 1),',') END || 
        CASE WHEN pg_get_expr(p.polqual, p.polrelid) IS NOT NULL THEN ' USING (' || pg_get_expr(p.polqual, p.polrelid) || ')' ELSE '' END ||
        CASE WHEN pg_get_expr(p.polwithcheck, p.polrelid) IS NOT NULL THEN ' WITH CHECK (' || pg_get_expr(p.polwithcheck, p.polrelid) || ')' ELSE '' END || ';' as apolicy
        FROM pg_class c, pg_namespace n, pg_policy p WHERE n.nspname = quote_ident(in_schema) AND c.relkind in ('p','r') AND c.relname = quote_ident(in_table) AND c.oid = p.polrelid ORDER BY apolicy
        LOOP
           v_acl  = v_acl || v_rec.apolicy || E'\n'; 
        END LOOP;
    END IF;
    
    -- -----------------------------------------------------------------------------------
    -- Create table defs for partitions/children using inheritance or declarative methods.
    -- inheritance: pg_class.relkind = 'r'   pg_class.relispartition=false   pg_class.relpartbound is NULL
    -- declarative: pg_class.relkind = 'r'   pg_class.relispartition=true    pg_class.relpartbound is NOT NULL
    -- -----------------------------------------------------------------------------------
    v_partbound := '';
    bPartition := False;
    bInheritance := False;
    IF v_pgversion < 100000 THEN
      -- Issue#11: handle parent schema
      SELECT c2.relname parent, c2.relnamespace::regnamespace INTO v_parent, v_parent_schema from pg_class c1, pg_namespace n, pg_inherits i, pg_class c2
      WHERE n.nspname = in_schema and n.oid = c1.relnamespace and c1.relname = in_table and c1.oid = i.inhrelid and i.inhparent = c2.oid and c1.relkind = 'r';      
      IF (v_parent IS NOT NULL) THEN
        bPartition   := True;
        bInheritance := True;
      END IF;
    ELSE
      -- Issue#11: handle parent schema
      SELECT c2.relname parent, c1.relispartition, pg_get_expr(c1.relpartbound, c1.oid, true), c2.relnamespace::regnamespace INTO v_parent, bRelispartition, v_partbound, v_parent_schema from pg_class c1, pg_namespace n, pg_inherits i, pg_class c2
      WHERE n.nspname = in_schema and n.oid = c1.relnamespace and c1.relname = in_table and c1.oid = i.inhrelid and i.inhparent = c2.oid and c1.relkind = 'r';
      IF (v_parent IS NOT NULL) THEN
        bPartition   := True;
        IF bRelispartition THEN
          bInheritance := False;
        ELSE
          bInheritance := True;
        END IF;
      END IF;
    END IF;
    IF bPartition THEN
      --Issue#17 fix for case-sensitive tables
		  -- SELECT count(*) INTO v_cnt1 FROM information_schema.tables t WHERE EXISTS (SELECT REGEXP_MATCHES(s.table_name, '([A-Z]+)','g') FROM information_schema.tables s 
		  -- WHERE t.table_schema=s.table_schema AND t.table_name=s.table_name AND t.table_schema = quote_ident(in_schema) AND t.table_name = quote_ident(in_table) AND t.table_type = 'BASE TABLE');      
		  SELECT count(*) INTO v_cnt1 FROM information_schema.tables t WHERE EXISTS (SELECT REGEXP_MATCHES(s.table_name, '([A-Z]+)','g') FROM information_schema.tables s 
		  WHERE t.table_schema=s.table_schema AND t.table_name=s.table_name AND t.table_schema = in_schema AND t.table_name = in_table AND t.table_type = 'BASE TABLE');      		  
		  
      --Issue#19 put double-quotes around SQL keyword column names
      -- Issue#121: fix keyword lookup for table name not column name that does not apply here
      -- SELECT COUNT(*) INTO v_cnt2 FROM pg_get_keywords() WHERE word = v_colrec.column_name AND catcode = 'R';
      SELECT COUNT(*) INTO v_cnt2 FROM pg_get_keywords() WHERE word = in_table AND catcode = 'R';
		  
      IF bInheritance THEN
        -- inheritance-based
        IF v_cnt1 > 0 OR v_cnt2 > 0 THEN
          -- Issue#31 fix
          -- v_table_ddl := 'CREATE TABLE ' || in_schema || '."' || in_table || '"( '|| E'\n';        
          v_table_ddl := 'CREATE TABLE ' || v_schema || '."' || in_table || '"( '|| E'\n';        
        ELSE
          -- Issue#31 fix
          -- v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || '( '|| E'\n';                
          v_table_ddl := 'CREATE TABLE ' || v_schema || '.' || in_table || '( '|| E'\n';                
        END IF;

        -- Jump to constraints section to add the check constraints
      ELSE
        -- declarative-based
        IF v_relopts <> '' THEN
          IF v_cnt1 > 0 OR v_cnt2 > 0 THEN
            -- Issue#31 fix
            -- v_table_ddl := 'CREATE TABLE ' || in_schema || '."' || in_table || '" PARTITION OF ' || in_schema || '.' || v_parent || ' ' || v_partbound || v_relopts || ' ' || v_tablespace || '; ' || E'\n';
            v_table_ddl := 'CREATE TABLE ' || v_schema || '."' || in_table || '" PARTITION OF ' || v_schema || '.' || v_parent || ' ' || v_partbound || v_relopts || ' ' || v_tablespace || '; ' || E'\n';
				  ELSE
				    -- Issue#31 fix
				    -- v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || ' PARTITION OF ' || in_schema || '.' || v_parent || ' ' || v_partbound || v_relopts || ' ' || v_tablespace || '; ' || E'\n';
				    v_table_ddl := 'CREATE TABLE ' || v_schema || '.' || in_table || ' PARTITION OF ' || v_schema || '.' || v_parent || ' ' || v_partbound || v_relopts || ' ' || v_tablespace || '; ' || E'\n';
				  END IF;
        ELSE
          IF v_cnt1 > 0 OR v_cnt2 > 0 THEN
            -- Issue#31 fix
            -- v_table_ddl := 'CREATE TABLE ' || in_schema || '."' || in_table || '" PARTITION OF ' || in_schema || '.' || v_parent || ' ' || v_partbound || ' ' || v_tablespace || '; ' || E'\n';
            v_table_ddl := 'CREATE TABLE ' || v_schema || '."' || in_table || '" PARTITION OF ' || v_schema || '.' || v_parent || ' ' || v_partbound || ' ' || v_tablespace || '; ' || E'\n';
				  ELSE
				    -- Issue#31 fix
				    -- v_table_ddl := 'CREATE TABLE ' || in_schema || '.' || in_table || ' PARTITION OF ' || in_schema || '.' || v_parent || ' ' || v_partbound || ' ' || v_tablespace || '; ' || E'\n';
				    v_table_ddl := 'CREATE TABLE ' || v_schema || '.' || in_table || ' PARTITION OF ' || v_schema || '.' || v_parent || ' ' || v_partbound || ' ' || v_tablespace || '; ' || E'\n';
				  END IF;
        END IF;
        -- Jump to constraints and index section to add the check constraints and indexes and perhaps FKeys
      END IF;
    END IF;
	  IF bVerbose THEN RAISE NOTICE '(1)tabledef so far: %', v_table_ddl; END IF;

    IF NOT bPartition THEN
      -- see if this is unlogged or temporary table
      select c.relpersistence into v_persist from pg_class c, pg_namespace n where n.nspname = in_schema and n.oid = c.relnamespace and c.relname = in_table and c.relkind = 'r';
      IF v_persist = 'u' THEN
        v_temp := 'UNLOGGED';
      ELSIF v_persist = 't' THEN
        v_temp := 'TEMPORARY';
      ELSE
        v_temp := '';
      END IF;
    END IF;
    
    -- start the create definition for regular tables unless we are in progress creating an inheritance-based child table
    IF NOT bPartition THEN
      --Issue#17 fix for case-sensitive tables
      -- SELECT count(*) INTO v_cnt1 FROM information_schema.tables t WHERE EXISTS (SELECT REGEXP_MATCHES(s.table_name, '([A-Z]+)','g') FROM information_schema.tables s 
      -- WHERE t.table_schema=s.table_schema AND t.table_name=s.table_name AND t.table_schema = quote_ident(in_schema) AND t.table_name = quote_ident(in_table) AND t.table_type = 'BASE TABLE');   
      SELECT count(*) INTO v_cnt1 FROM information_schema.tables t WHERE EXISTS (SELECT REGEXP_MATCHES(s.table_name, '([A-Z]+)','g') FROM information_schema.tables s 
      WHERE t.table_schema=s.table_schema AND t.table_name=s.table_name AND t.table_schema = in_schema AND t.table_name = in_table AND t.table_type = 'BASE TABLE');         
      IF v_cnt1 > 0 THEN
        -- Issue#31 fix
        -- v_table_ddl := 'CREATE ' || v_temp || ' TABLE ' || in_schema || '."' || in_table || '" (' || E'\n';
        v_table_ddl := 'CREATE ' || v_temp || ' TABLE ' || v_schema || '."' || in_table || '" (' || E'\n';
      ELSE
        -- Issue#31 fix
        -- v_table_ddl := 'CREATE ' || v_temp || ' TABLE ' || in_schema || '.' || in_table || ' (' || E'\n';
        v_table_ddl := 'CREATE ' || v_temp || ' TABLE ' || v_schema || '.' || in_table || ' (' || E'\n';
      END IF;
    END IF;
    -- RAISE NOTICE 'DEBUG2: tabledef so far: %', v_table_ddl;    
    -- define all of the columns in the table unless we are in progress creating an inheritance-based child table
    IF NOT bPartition THEN
      FOR v_colrec IN
        SELECT c.column_name, c.data_type, c.udt_name, c.udt_schema, c.character_maximum_length, c.is_nullable, c.column_default, c.numeric_precision, c.numeric_scale, c.is_identity, c.identity_generation, c.is_generated, c.generation_expression        
        FROM information_schema.columns c WHERE (table_schema, table_name) = (in_schema, in_table) ORDER BY ordinal_position
      LOOP
         -- v17 fix: handle case-sensitive for pg_get_serial_sequence that requires SQL Identifier handling
         -- SELECT pg_get_serial_sequence(v_qualified, v_colrec.column_name) into v_temp;
         -- v17 fix: handle case-sensitive for pg_get_serial_sequence that requires SQL Identifier handling
         -- SELECT CASE WHEN pg_get_serial_sequence(v_qualified, v_colrec.column_name) IS NOT NULL THEN True ELSE False END into bSerial;
         SELECT pg_get_serial_sequence(quote_ident(in_schema) || '.' || quote_ident(in_table), v_colrec.column_name) into v_seqname;         
         IF v_seqname IS NULL THEN v_seqname = ''; END IF;
         SELECT CASE WHEN pg_get_serial_sequence(quote_ident(in_schema) || '.' || quote_ident(in_table), v_colrec.column_name) IS NOT NULL THEN True ELSE False END into bSerial;          
         
         -- Issue#36: call pg_get_coldef() differently
         IF v_pgversion < 100000 THEN
             SELECT public.pg_get_coldef(in_schema, in_table,v_colrec.column_name,true) INTO v_coldef;                  
         ELSE
             SELECT public.pg_get_coldef(in_schema, in_table,v_colrec.column_name) INTO v_coldef;         
         END IF;

         IF bVerbose THEN 
             -- RAISE NOTICE '(col loop) coldef=%  name=%  type=%  udt_name=%  default=%  is_generated=%  gen_expr=%  Serial=%  SeqName=%', 
             --                       v_coldef, v_colrec.column_name, v_colrec.data_type, v_colrec.udt_name, v_colrec.column_default, v_colrec.is_generated, v_colrec.generation_expression, bSerial, v_seqname;
             RAISE NOTICE '(col loop) coldef=%  name=%  type=%  udt_name=%  default=%  is_generated=%  gen_expr=%  Serial=%  SeqName=%', 
                                      v_coldef, v_colrec.column_name, v_colrec.data_type, quote_ident(v_colrec.udt_name), v_colrec.column_default, v_colrec.is_generated, v_colrec.generation_expression, bSerial, v_seqname;                                      
         END IF;
         
         --Issue#17 put double-quotes around case-sensitive column names
         SELECT COUNT(*) INTO v_cnt1 FROM information_schema.columns t WHERE EXISTS (SELECT REGEXP_MATCHES(s.column_name, '([A-Z]+)','g') FROM information_schema.columns s 
         WHERE t.table_schema=s.table_schema and t.table_name=s.table_name and t.column_name=s.column_name AND t.table_schema = quote_ident(in_schema) AND column_name = v_colrec.column_name);         

         --Issue#19 put double-quotes around SQL keyword column names         
         SELECT COUNT(*) INTO v_cnt2 FROM pg_get_keywords() WHERE word = v_colrec.column_name AND catcode = 'R';
         
         IF v_cnt1 > 0 OR v_cnt2 > 0 THEN
           v_table_ddl := v_table_ddl || '  "' || v_colrec.column_name || '" ';
         ELSE
           v_table_ddl := v_table_ddl || '  ' || v_colrec.column_name || ' ';
         END IF;
         
         IF v_colrec.column_default ILIKE 'nextval%' THEN
             -- Issue#32: handle explicit sequences for serial types as well simulating pg_dump manner.
             v_temp = v_colrec.data_type || ' NOT NULL DEFAULT ' || v_colrec.column_default;
         
         ELSEIF v_colrec.is_generated = 'ALWAYS' and v_colrec.generation_expression IS NOT NULL THEN
             -- Issue#23: Handle autogenerated columns and rewrite as a simpler IF THEN ELSE branch instead of a much more complex embedded CASE STATEMENT
             -- searchable tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, COALESCE(translate(email, '@.-'::citext, ' '::text), ''::text)) ) STORED
             v_temp = v_colrec.data_type || ' GENERATED ALWAYS AS (' || v_colrec.generation_expression || ') STORED ';
             
         ELSEIF v_colrec.udt_name in ('geometry') THEN
             --Issue#30 fix handle geometries separately and use coldef func on it
             -- Issue#36: call pg_get_coldef() differently
						 IF v_pgversion < 100000 THEN
						     v_temp = public.pg_get_coldef(in_schema, in_table,v_colrec.column_name, true);
						 ELSE
						     v_temp = public.pg_get_coldef(in_schema, in_table,v_colrec.column_name);
						 END IF;

         ELSEIF v_colrec.udt_name in ('box2d', 'box2df', 'box3d', 'geography', 'geometry_dump', 'gidx', 'spheroid', 'valid_detail') THEN         
		         v_temp = v_colrec.udt_name;

		     ELSEIF v_colrec.data_type = 'USER-DEFINED' THEN
		         -- Issue#31 fix
		         -- v_temp = v_colrec.udt_schema || '.' || v_colrec.udt_name;
		         -- Issue#37 handle case-sensitive user-defined types
		         -- v_temp = quote_ident(v_colrec.udt_schema) || '.' || v_colrec.udt_name;
		         v_temp = quote_ident(v_colrec.udt_schema) || '.' || quote_ident(v_colrec.udt_name);

		     ELSEIF v_colrec.data_type = 'ARRAY' THEN
   		       -- Issue#6 fix: handle arrays
             
             -- Issue#36: call pg_get_coldef() differently
						 IF v_pgversion < 100000 THEN
						     v_temp = public.pg_get_coldef(in_schema, in_table,v_colrec.column_name, true);
						 ELSE
						     v_temp = public.pg_get_coldef(in_schema, in_table,v_colrec.column_name);
						 END IF;
   		       
             -- v17 fix: handle case-sensitive for pg_get_serial_sequence that requires SQL Identifier handling
  		       -- WHEN pg_get_serial_sequence(v_qualified, v_colrec.column_name) IS NOT NULL 

		     ELSEIF pg_get_serial_sequence(quote_ident(in_schema) || '.' || quote_ident(in_table), v_colrec.column_name) IS NOT NULL THEN
		         -- Issue#8 fix: handle serial. Note: NOT NULL is implied so no need to declare it explicitly

             -- Issue#36: call pg_get_coldef() differently
						 IF v_pgversion < 100000 THEN
						     v_temp = public.pg_get_coldef(in_schema, in_table,v_colrec.column_name, true);
						 ELSE
						     v_temp = public.pg_get_coldef(in_schema, in_table,v_colrec.column_name);
						 END IF;
		         
         --ELSEIF (v_colrec.data_type = 'character varying' or v_colrec.udt_name = 'varchar') AND v_colrec.character_maximum_length IS NOT NULL THEN
		     ELSE
		         -- Issue#31 fix
		         -- v_temp = v_colrec.data_type;
		         v_temp = v_coldef;
         END IF;

         -- handle IDENTITY columns
		     IF v_colrec.is_identity = 'YES' THEN
		         IF v_colrec.identity_generation = 'ALWAYS' THEN 
		             v_temp = v_temp || ' GENERATED ALWAYS AS IDENTITY NOT NULL';
		         ELSE
		             v_temp = v_temp || ' GENERATED BY DEFAULT AS IDENTITY NOT NULL';
		         END IF;
         -- Issue#31: no need to add stuff since we get the coldef definition now above		         
         -- ELSEIF v_colrec.character_maximum_length IS NOT NULL THEN 
         --     v_temp = v_temp || ('(' || v_colrec.character_maximum_length || ')');
         -- ELSEIF v_colrec.numeric_precision > 0 AND v_colrec.numeric_scale > 0 THEN 
         --     v_temp = v_temp || '(' || v_colrec.numeric_precision || ',' || v_colrec.numeric_scale || ')';
         END IF;
         
         -- Handle NULL/NOT NULL
         IF POSITION('NOT NULL ' IN v_temp) > 0 THEN
             -- Issue#32: for explicit sequences with nextval, we already handled NOT NULL, so ignore    
             NULL;
         
         ELSEIF bSerial AND v_colrec.is_identity = 'NO' THEN 
             -- Issue#28 - added identity check 
             v_temp = v_temp || ' NOT NULL';
         
         ELSEIF v_colrec.is_nullable = 'NO' AND v_colrec.is_identity = 'NO' THEN 
             -- Issue#28 - added identity check              
             v_temp = v_temp || ' NOT NULL';

         ELSEIF v_colrec.is_nullable = 'YES' THEN
             v_temp = v_temp || ' NULL';
         END IF;

         -- Handle defaults
         -- Issue#32 fix
          -- IF v_colrec.column_default IS NOT null AND NOT bSerial THEN 
         IF v_colrec.column_default IS NOT null AND NOT bSerial AND v_colrec.column_default NOT ILIKE 'nextval%' THEN          
             -- RAISE NOTICE 'Setting default for column, %', v_colrec.column_name;
             v_temp = v_temp || (' DEFAULT ' || v_colrec.column_default);
         END IF;
         
         v_temp = v_temp || ',' || E'\n';
         -- RAISE NOTICE 'column def2=%', v_temp;
         v_table_ddl := v_table_ddl || v_temp;
         -- RAISE NOTICE 'tabledef=%', v_table_ddl;
         
         IF bVerbose THEN RAISE NOTICE 'tabledef: %', v_table_ddl; END IF;
      END LOOP;
    END IF;
    IF bVerbose THEN RAISE NOTICE '(2)tabledef so far: %', v_table_ddl; END IF;
        
    -- define all the constraints: conparentid does not exist pre PGv11
    IF v_pgversion < 110000 THEN
      FOR v_constraintrec IN
        SELECT con.conname as constraint_name, con.contype as constraint_type,
          CASE
            WHEN con.contype = 'p' THEN 1 -- primary key constraint
            WHEN con.contype = 'u' THEN 2 -- unique constraint
            WHEN con.contype = 'f' THEN 3 -- foreign key constraint
            WHEN con.contype = 'c' THEN 4
            ELSE 5
          END as type_rank,
          pg_get_constraintdef(con.oid) as constraint_definition
        FROM pg_catalog.pg_constraint con JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid JOIN pg_catalog.pg_namespace nsp ON nsp.oid = connamespace
        WHERE nsp.nspname = in_schema AND rel.relname = in_table ORDER BY type_rank
      LOOP
        v_constraint_name := v_constraintrec.constraint_name;
        v_constraint_def  := v_constraintrec.constraint_definition;
        IF v_constraintrec.type_rank = 1 THEN
            IF pkcnt = 0 OR pktype = 'PKEY_INTERNAL' THEN
                -- internal def
                v_constraint_name := v_constraintrec.constraint_name;
                v_constraint_def  := v_constraintrec.constraint_definition;
                v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
                  || 'CONSTRAINT' || ' '
                  || v_constraint_name || ' '
                  || v_constraint_def
                  || ',' || E'\n';
            ELSE
              -- Issue#16 handle external PG def
              SELECT 'ALTER TABLE ONLY ' || in_schema || '.' || c.relname || ' ADD CONSTRAINT ' || r.conname || ' ' || pg_catalog.pg_get_constraintdef(r.oid, true) || ';' INTO v_pkey_def 
              FROM pg_catalog.pg_constraint r, pg_class c, pg_namespace n where r.conrelid = c.oid and  r.contype = 'p' and n.oid = r.connamespace and n.nspname = in_schema AND c.relname = in_table and r.conname = v_constraint_name;             
            END IF;
            IF bPartition THEN
              continue;
            END IF;
        ELSIF v_constraintrec.type_rank = 3 THEN
            -- handle foreign key constraints
            --Issue#22 fix: added FKEY_NONE check
            IF fktype = 'FKEYS_NONE' THEN
                -- skip
                continue;
            ELSIF fkcnt = 0 OR fktype = 'FKEYS_INTERNAL' THEN
                -- internal def
                v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
                  || 'CONSTRAINT' || ' '
                  || v_constraint_name || ' '
                  || v_constraint_def
                  || ',' || E'\n';                
            ELSE
                -- external def
                SELECT 'ALTER TABLE ONLY ' || n.nspname || '.' || c2.relname || ' ADD CONSTRAINT ' || r.conname || ' ' || pg_catalog.pg_get_constraintdef(r.oid, true) || ';' INTO v_fkey_def 
  			        FROM pg_constraint r, pg_class c1, pg_namespace n, pg_class c2 where r.conrelid = c1.oid and  r.contype = 'f' and n.nspname = in_schema and n.oid = r.connamespace and r.conrelid = c2.oid and c2.relname = in_table;
                v_fkey_defs = v_fkey_defs || v_fkey_def || E'\n';
            END IF;
        ELSE
            -- handle all other constraints besides PKEY and FKEYS as internal defs by default
            v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
              || 'CONSTRAINT' || ' '
              || v_constraint_name || ' '
              || v_constraint_def
              || ',' || E'\n';            
        END IF;
        if bVerbose THEN RAISE NOTICE 'constraint name=% constraint_def=%', v_constraint_name,v_constraint_def; END IF;
        constraintarr := constraintarr || v_constraintrec.constraint_name:: text;
  
      END LOOP;
    ELSE
      -- handle PG versions 11 and up
      -- Issue#20: Fix logic for external PKEY and FKEYS
      FOR v_constraintrec IN
        SELECT con.conname as constraint_name, con.contype as constraint_type,
          CASE
            WHEN con.contype = 'p' THEN 1 -- primary key constraint
            WHEN con.contype = 'u' THEN 2 -- unique constraint
            WHEN con.contype = 'f' THEN 3 -- foreign key constraint
            WHEN con.contype = 'c' THEN 4
            ELSE 5
          END as type_rank,
          pg_get_constraintdef(con.oid) as constraint_definition
        FROM pg_catalog.pg_constraint con JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid JOIN pg_catalog.pg_namespace nsp ON nsp.oid = connamespace
        WHERE nsp.nspname = in_schema AND rel.relname = in_table 
              --Issue#13 added this condition:
              AND con.conparentid = 0 
              ORDER BY type_rank
      LOOP
        v_constraint_name := v_constraintrec.constraint_name;
        v_constraint_def  := v_constraintrec.constraint_definition;
        IF v_constraintrec.type_rank = 1 THEN
            IF pkcnt = 0 OR pktype = 'PKEY_INTERNAL' THEN
                -- internal def
                v_constraint_name := v_constraintrec.constraint_name;
                v_constraint_def  := v_constraintrec.constraint_definition;
                v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
                  || 'CONSTRAINT' || ' '
                  || v_constraint_name || ' '
                  || v_constraint_def
                  || ',' || E'\n';
            ELSE
              -- Issue#16 handle external PG def
              SELECT 'ALTER TABLE ONLY ' || in_schema || '.' || c.relname || ' ADD CONSTRAINT ' || r.conname || ' ' || pg_catalog.pg_get_constraintdef(r.oid, true) || ';' INTO v_pkey_def 
              FROM pg_catalog.pg_constraint r, pg_class c, pg_namespace n where r.conrelid = c.oid and  r.contype = 'p' and n.oid = r.connamespace and n.nspname = in_schema AND c.relname = in_table;              
            END IF;
            IF bPartition THEN
              continue;
            END IF;
        ELSIF v_constraintrec.type_rank = 3 THEN
            -- handle foreign key constraints
            --Issue#22 fix: added FKEY_NONE check
            IF fktype = 'FKEYS_NONE' THEN
                -- skip
                continue;            
            ELSIF fkcnt = 0 OR fktype = 'FKEYS_INTERNAL' THEN
                -- internal def
                v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
                  || 'CONSTRAINT' || ' '
                  || v_constraint_name || ' '
                  || v_constraint_def
                  || ',' || E'\n';                
            ELSE
                -- external def
                SELECT 'ALTER TABLE ONLY ' || n.nspname || '.' || c2.relname || ' ADD CONSTRAINT ' || r.conname || ' ' || pg_catalog.pg_get_constraintdef(r.oid, true) || ';' INTO v_fkey_def 
  			        FROM pg_constraint r, pg_class c1, pg_namespace n, pg_class c2 where r.conrelid = c1.oid and  r.contype = 'f' and n.nspname = in_schema and n.oid = r.connamespace and r.conrelid = c2.oid and c2.relname = in_table and 
  			        r.conname = v_constraint_name and r.conparentid = 0;
                v_fkey_defs = v_fkey_defs || v_fkey_def || E'\n';
            END IF;
        ELSE
            -- handle all other constraints besides PKEY and FKEYS as internal defs by default
            v_table_ddl := v_table_ddl || '  ' -- note: two char spacer to start, to indent the column
              || 'CONSTRAINT' || ' '
              || v_constraint_name || ' '
              || v_constraint_def
              || ',' || E'\n';            
        END IF;
        if bVerbose THEN RAISE NOTICE 'constraint name=% constraint_def=%', v_constraint_name,v_constraint_def; END IF;
        constraintarr := constraintarr || v_constraintrec.constraint_name:: text;
  
       END LOOP;
    END IF;      
	
    -- drop the last comma before ending the create statement, which should be right before the carriage return character
    -- Issue#24: make sure the comma is there before removing it
    select substring(v_table_ddl, length(v_table_ddl) - 1, 1) INTO v_temp;
    IF v_temp = ',' THEN
        v_table_ddl = substr(v_table_ddl, 0, length(v_table_ddl) - 1) || E'\n';
    END IF;
    IF bVerbose THEN RAISE NOTICE '(3)tabledef so far: %', trim(v_table_ddl); END IF;

    -- ---------------------------------------------------------------------------
    -- at this point we have everything up to the last table-enclosing parenthesis
    -- ---------------------------------------------------------------------------
    IF bVerbose THEN RAISE NOTICE '(4)tabledef so far: %', v_table_ddl; END IF;

    -- See if this is an inheritance-based child table and finish up the table create.
    IF bPartition and bInheritance THEN
      -- Issue#11: handle parent schema
      -- v_table_ddl := v_table_ddl || ') INHERITS (' || in_schema || '.' || v_parent || ') ' || E'\n' || v_relopts || ' ' || v_tablespace || ';' || E'\n';
      IF v_parent_schema = '' OR v_parent_schema IS NULL THEN v_parent_schema = in_schema; END IF;
      v_table_ddl := v_table_ddl || ') INHERITS (' || v_parent_schema || '.' || v_parent || ') ' || E'\n' || v_relopts || ' ' || v_tablespace || ';' || E'\n';
    END IF;

    IF v_pgversion >= 100000 AND NOT bPartition and NOT bInheritance THEN
      -- See if this is a partitioned table (pg_class.relkind = 'p') and add the partitioned key 
      SELECT pg_get_partkeydef(c1.oid) as partition_key INTO v_partition_key FROM pg_class c1 JOIN pg_namespace n ON (n.oid = c1.relnamespace) LEFT JOIN pg_partitioned_table p ON (c1.oid = p.partrelid) 
      WHERE n.nspname = in_schema and n.oid = c1.relnamespace and c1.relname = in_table and c1.relkind = 'p';

      IF v_partition_key IS NOT NULL AND v_partition_key <> '' THEN
        -- add partition clause
        -- NOTE:  cannot specify default tablespace for partitioned relations
        -- v_table_ddl := v_table_ddl || ') PARTITION BY ' || v_partition_key || ' ' || v_tablespace || ';' || E'\n';  
        v_table_ddl := v_table_ddl || ') PARTITION BY ' || v_partition_key || ';' || E'\n';  
      ELSEIF v_relopts <> '' THEN
        v_table_ddl := v_table_ddl || ') ' || v_relopts || ' ' || v_tablespace || ';' || E'\n';  
      ELSE
        -- end the create definition
        v_table_ddl := v_table_ddl || ') ' || v_tablespace || ';' || E'\n';    
      END IF;  

    -- Issue#39: don't forget the tablespace!      
    ELSEIF v_pgversion < 100000 THEN
        -- end the create definition
        v_table_ddl := v_table_ddl || ') ' || v_tablespace || ';' || E'\n';            
    END IF;

    IF bVerbose THEN RAISE NOTICE '(5)tabledef so far: %', v_table_ddl; END IF;
    
    -- Add closing paren for regular tables
    -- IF NOT bPartition THEN
    -- v_table_ddl := v_table_ddl || ') ' || v_relopts || ' ' || v_tablespace || E';\n';  
    -- END IF;
    -- RAISE NOTICE 'ddlsofar3: %', v_table_ddl;

    -- Issue#27: add OWNER ACL OR ALL_ACLS info here if directed
    IF v_acl <> '' THEN
        v_table_ddl := v_table_ddl || v_acl || E'\n';    
    END IF;

    -- Issue#16 create the external PKEY def if indicated
    IF v_pkey_def <> '' THEN
        v_table_ddl := v_table_ddl || v_pkey_def || E'\n';    
    END IF;
   
    -- Issue#20
    IF v_fkey_defs <> '' THEN
	         v_table_ddl := v_table_ddl || v_fkey_defs || E'\n';    
    END IF;
   
    IF bVerbose THEN RAISE NOTICE '(6)tabledef so far: %', v_table_ddl; END IF;
   
    -- create indexes
    FOR v_indexrec IN
      SELECT indexdef, COALESCE(tablespace, 'pg_default') as tablespace, indexname FROM pg_indexes WHERE (schemaname, tablename) = (in_schema, in_table)
    LOOP
      -- RAISE NOTICE 'DEBUG6: indexname=%  indexdef=%', v_indexrec.indexname, v_indexrec.indexdef;             
      -- loop through constraints and skip ones already defined
      bSkip = False;
      FOREACH constraintelement IN ARRAY constraintarr
      LOOP 
         IF constraintelement = v_indexrec.indexname THEN
             -- RAISE NOTICE 'DEBUG7: skipping index, %', v_indexrec.indexname;
             bSkip = True;
             EXIT;
         END IF;
      END LOOP;   
      if bSkip THEN CONTINUE; END IF;
      
      -- Add IF NOT EXISTS clause so partition index additions will not be created if declarative partition in effect and index already created on parent
      v_indexrec.indexdef := REPLACE(v_indexrec.indexdef, 'CREATE INDEX', 'CREATE INDEX IF NOT EXISTS');
      -- Fix Issue#26: do it for unique/primary key indexes as well
      v_indexrec.indexdef := REPLACE(v_indexrec.indexdef, 'CREATE UNIQUE INDEX', 'CREATE UNIQUE INDEX IF NOT EXISTS');
            
      -- NOTE:  cannot specify default tablespace for partitioned relations
      IF v_partition_key IS NOT NULL AND v_partition_key <> '' THEN
          v_table_ddl := v_table_ddl || v_indexrec.indexdef || ';' || E'\n';
      ELSE
          -- Issue#25: see if partial index or not
          -- Issue#39: handle case-sensitive schemas
					-- select CASE WHEN i.indpred IS NOT NULL THEN True ELSE False END INTO v_partial 
					-- FROM pg_index i JOIN pg_class c1 ON (i.indexrelid = c1.oid) JOIN pg_class c2 ON (i.indrelid = c2.oid) 
					-- WHERE c1.relnamespace::regnamespace::text = in_schema AND c2.relnamespace::regnamespace::text = in_schema AND c2.relname = in_table AND c1.relname = v_indexrec.indexname; 
					select CASE WHEN i.indpred IS NOT NULL THEN True ELSE False END INTO v_partial 
					FROM pg_index i JOIN pg_class c1 ON (i.indexrelid = c1.oid) JOIN pg_class c2 ON (i.indrelid = c2.oid) 
					WHERE c1.relnamespace::regnamespace::text = quote_ident(in_schema) AND c2.relnamespace::regnamespace::text = c1.relnamespace::regnamespace::text AND c2.relname = in_table AND c1.relname = v_indexrec.indexname; 
					
          IF v_partial THEN
              -- Put tablespace def before WHERE CLAUSE
              v_temp = v_indexrec.indexdef;
              v_pos = POSITION(' WHERE ' IN v_temp);
              v_temp2 = SUBSTRING(v_temp, v_pos);
              v_temp  = SUBSTRING(v_temp, 1, v_pos);
              v_table_ddl := v_table_ddl || v_temp || ' TABLESPACE ' || v_indexrec.tablespace || v_temp2 || ';' || E'\n';              
          ELSE
              v_table_ddl := v_table_ddl || v_indexrec.indexdef || ' TABLESPACE ' || v_indexrec.tablespace || ';' || E'\n';
          END IF;
      END IF;
      
    END LOOP;
    IF bVerbose THEN RAISE NOTICE '(7)tabledef so far: %', v_table_ddl; END IF;

    -- Issue#20: added logic for table and column comments
    IF  cmtcnt > 0 THEN 
        FOR v_rec IN
          SELECT c.relname, 'COMMENT ON ' || CASE WHEN c.relkind in ('r','p') AND a.attname IS NULL THEN 'TABLE ' WHEN c.relkind in ('r','p') AND a.attname IS NOT NULL THEN 'COLUMN ' WHEN c.relkind = 'f' THEN 'FOREIGN TABLE ' 
                 -- Issue#140
                 -- WHEN c.relkind = 'm' THEN 'MATERIALIZED VIEW ' WHEN c.relkind = 'v' THEN 'VIEW ' WHEN c.relkind = 'i' THEN 'INDEX ' WHEN c.relkind = 'S' THEN 'SEQUENCE ' ELSE 'XX' END || n.nspname || '.' || 
                 WHEN c.relkind = 'm' THEN 'MATERIALIZED VIEW ' WHEN c.relkind = 'v' THEN 'VIEW ' WHEN c.relkind = 'i' THEN 'INDEX ' WHEN c.relkind = 'S' THEN 'SEQUENCE ' ELSE 'XX' END || quote_ident(n.nspname) || '.' ||                  
                 CASE WHEN c.relkind in ('r','p') AND a.attname IS NOT NULL THEN quote_ident(c.relname) || '.' || a.attname ELSE quote_ident(c.relname) END || ' IS '   || quote_literal(d.description) || ';' as ddl
	   	    FROM pg_class c JOIN pg_namespace n ON (n.oid = c.relnamespace) LEFT JOIN pg_description d ON (c.oid = d.objoid) LEFT JOIN pg_attribute a ON (c.oid = a.attrelid AND a.attnum > 0 and a.attnum = d.objsubid)
	   	    WHERE d.description IS NOT NULL AND n.nspname = in_schema AND c.relname = in_table ORDER BY 2 desc, ddl
        LOOP
            --RAISE NOTICE 'comments:%', v_rec.ddl;
            v_table_ddl = v_table_ddl || v_rec.ddl || E'\n';
        END LOOP;   
    END IF;
    IF bVerbose THEN RAISE NOTICE '(8)tabledef so far: %', v_table_ddl; END IF;
	
    IF trigtype = 'INCLUDE_TRIGGERS' THEN
	    -- Issue#14: handle multiple triggers for a table
      FOR v_trigrec IN
          select pg_get_triggerdef(t.oid, True) || ';' as triggerdef FROM pg_trigger t, pg_class c, pg_namespace n 
          WHERE n.nspname = in_schema and n.oid = c.relnamespace and c.relname = in_table and c.relkind = 'r' and t.tgrelid = c.oid and NOT t.tgisinternal
      LOOP
          v_table_ddl := v_table_ddl || v_trigrec.triggerdef;
          v_table_ddl := v_table_ddl || E'\n';          
          IF bVerbose THEN RAISE NOTICE 'triggerdef = %', v_trigrec.triggerdef; END IF;
      END LOOP;       	    
    END IF;
  
    IF bVerbose THEN RAISE NOTICE '(9)tabledef so far: %', v_table_ddl; END IF;
    -- add empty line
    v_table_ddl := v_table_ddl || E'\n';
    IF bVerbose THEN RAISE NOTICE '(10)tabledef so far: %', v_table_ddl; END IF;

    -- Issue#33 implementation follows
    IF showpartscnt = 1 THEN
        SELECT c.oid, pg_get_partkeydef(c.oid::pg_catalog.oid) INTO v_oid, v_partkeydef FROM pg_class c, pg_namespace n WHERE n.oid = c.relnamespace AND n.nspname = in_schema and c.relname = in_table;
        IF v_partkeydef IS NOT NULL THEN
            -- v_partinfo := 'Partition key: ' || v_partkeydef || E'\n' || 'Partitions:' || E'\n' ;
            v_partinfo := 'Partitions:' || E'\n' ;

            FOR v_rec IN
                SELECT c.oid::pg_catalog.regclass, c.relkind, inhdetachpending, pg_catalog.pg_get_expr(c.relpartbound, c.oid)
                FROM pg_catalog.pg_class c, pg_catalog.pg_inherits i WHERE c.oid = i.inhrelid AND i.inhparent = v_oid
                ORDER BY pg_catalog.pg_get_expr(c.relpartbound, c.oid) = 'DEFAULT', c.oid::pg_catalog.regclass::pg_catalog.text
            LOOP
                v_partinfo := v_partinfo || v_rec.oid || ' ' || v_rec.pg_get_expr || E'\n' ;
            END LOOP;
        END IF;
    END IF;
    IF v_partinfo <> '' THEN
        v_table_ddl = v_table_ddl || v_partinfo;
    END IF;

    -- reset search_path back to what it was
    -- Issue#29: add verbose info for searchpath stuff
    v_context = 'SEARCHPATH';
    IF search_path_old = '' THEN
      SELECT set_config('search_path', '', false) into v_temp;
      IF bVerbose THEN RAISE NOTICE 'SearchPath Cleanup: current searchpath=%', v_temp; END IF;
    ELSE
      IF bVerbose THEN RAISE NOTICE 'SearchPath Cleanup: resetting searchpath=%', search_path_old; END IF;
      EXECUTE 'SET search_path = ' || search_path_old;
    END IF;

    RETURN v_table_ddl;
	
    EXCEPTION
    WHEN others THEN
    BEGIN
      GET STACKED DIAGNOSTICS v_diag1 = MESSAGE_TEXT, v_diag2 = PG_EXCEPTION_DETAIL, v_diag3 = PG_EXCEPTION_HINT, v_diag4 = RETURNED_SQLSTATE, v_diag5 = PG_CONTEXT, v_diag6 = PG_EXCEPTION_CONTEXT;
      -- v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1 || ' .' || v_diag2 || ' .' || v_diag3;

      -- put additional coding here if necessary
      IF v_context <> '' THEN
          v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1 || '  context=' || v_context;      
          RAISE WARNING 'Search_path not reset correctly.  You may need to adjust it manually. %', v_ret;          
      ELSE
          v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1;
          RAISE EXCEPTION '%', v_ret;          
      END IF;
       RETURN '';
    END;

  END;
$$;


/****************************************************/
/*  Drop In function pg_get_tabledef ends here...   */
/****************************************************/


-- Function: clone_schema(text, text, boolean, boolean, boolean)
-- DROP FUNCTION clone_schema(text, text, boolean, boolean, boolean);
-- DROP FUNCTION IF EXISTS public.clone_schema(text, text, boolean, boolean);

DROP FUNCTION IF EXISTS public.clone_schema(text, text, cloneparms[]);
CREATE OR REPLACE FUNCTION public.clone_schema(
    source_schema text,
    dest_schema text,
    VARIADIC arr public.cloneparms[] DEFAULT '{}':: public.cloneparms[])
  -- Issue#139 : change return type from VOID to INTEGER
  -- RETURNS void AS
  RETURNS INTEGER AS
$BODY$

--  This function will clone all sequences, tables, data, views & functions from any existing schema to a new one
-- SAMPLE CALL:
-- SELECT clone_schema('sample', 'sample_clone2');

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
  udt_name         text;
  udt_schema       text;
  bRelispart       bool;
  bChild           bool;
  relknd           text;
  data_type        text;
  ocomment         text;
  adef             text;
  dest_qry         text;
  v_def            text;
  part_range       text;
  v_src_path_old   text;
  v_src_path_new   text;
  aclstr           text;
  -- issue#80 initialize arrays properly
  tblarray         text[] := '{}';
  tblarray2        text[] := '{}';
  tblarray3        text[] := '{}';
  tblarray4        text[] := '{}';
  DDLAltTblDefer   text[] := '{}';
  DDLCreateIXDefer text[] := '{}';
  DDLAttachDefer   text[] := '{}';
  DDLAttachSkip    text[] := '{}';   
  DDLAltCol        text[] := '{}';   
  tblelement       text;
  tblelement2      text;
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
  cntables         integer;
  cnt              integer;
  cnt1             integer;
  cnt2             integer;
  cnt3             integer;
  cnt4             integer;
  deferredviewcnt  integer;
  pos              integer;
  
  -- sequences variables
  relid            integer;
  aschema          text;
  colname          text;
  seqname          text;
  deptype          text;
  attidentity      char;
  seqtype          text;
  coldef           text;
  formattype       text;
  seqowner         text;
  lastvalue        bigint;
  seqcnt           integer;
  setcnt           integer;
    
  tblscopied       integer := 0;
  l_child          integer;
  action           text := 'N/A';
  RC_OK            integer := 0;
  RC_ERR           integer := 1;
  rc               integer := 0;
  tblname          text;
  v_ret            text;
  v_diag1          text;
  v_diag2          text;
  v_diag3          text;
  v_diag4          text;
  v_diag5          text;
  v_diag6          text;
  v_dummy          text;
  v_dummy2         text;
  v_dummy3         text;
  v_coldef         text;
  v_seqowner       text;
  spath            text;
  spath_tmp        text;
  -- issue#86 fix
  isGenerated      text;
  
  -- issue#91 fix
  tblowner         text;
  func_owner       text;
  func_name        text;
  func_args        text;
  func_argno       integer;
  view_owner       text; 

  -- issue#92    
  calleruser       text;
  
  -- issue#94
  bData            boolean := False;
  bDDLOnly         boolean := False;
  bVerbose         boolean := False;
  bDebugExec       boolean := False;
  bDebug           boolean := False;
  bNoACL           boolean := False;
  bNoOwner         boolean := False;
  arglen           integer;
  vargs            text;
  avarg            public.cloneparms;

  -- issue#98
  mvarray          text[] := '{}';  
  deferredviews    text[] := '{}';  
  viewdef          text;
  mvscopied        integer := 0;
  
  -- issue#99 tablespaces
  tblspace         text;
  
  -- issue#101
  bFileCopy        boolean := False;
  
  t                timestamptz := clock_timestamp();
  r                timestamptz;
  s                timestamptz;
  lastsql          text := '';
  lasttbl          text := '';
  bFound           boolean;
  role_invoker     text;
  v_version        text := '2.18 December 19, 2024';

BEGIN
  -- uncomment the following to get line context info when debugging exceptions. 
  -- Currently the next line is actually line 141 based on start line (without spaces) = $ BODY $
  -- RAISE EXCEPTION 'line1'; 

  -- Make sure NOTICE are shown
    SET client_min_messages = 'notice';
  RAISE NOTICE 'clone_schema version %', v_version;

  IF 'DEBUG'   = ANY ($3) THEN bDebug = True; END IF;
  IF 'VERBOSE' = ANY ($3) THEN bVerbose = True; END IF;
  IF 'DEBUGEXEC' = ANY ($3) THEN bDebugExec = True; END IF;
    
  IF bDEBUG THEN RAISE NOTICE 'DEBUG: Cloning % into %.    START: %',source_schema, dest_schema, clock_timestamp() - t; END IF;
  
  arglen := array_length($3, 1);
  IF arglen IS NULL THEN
    -- nothing to do, so defaults are assumed
    NULL;
  ELSE
    -- loop thru args
    -- IF 'NO_TRIGGERS' = ANY ($3)
    -- select array_to_string($3, ',', '***') INTO vargs;
    IF bDebug THEN RAISE NOTICE 'DEBUG: arguments=%', $3; END IF;
    FOREACH avarg IN ARRAY $3 LOOP
      IF bDebug THEN RAISE NOTICE 'DEBUG: arg=%', avarg; END IF;
      IF avarg = 'DATA' THEN
        bData = True;
      ELSEIF avarg = 'NODATA' THEN
        -- already set to that by default
        bData = False;
      ELSEIF avarg = 'DDLONLY' THEN
        bDDLOnly = True;
      ELSEIF avarg = 'NOACL' THEN
        bNoACL = True;
      ELSEIF avarg = 'NOOWNER' THEN
        bNoOwner = True;        
      -- issue#101 fix
      ELSEIF avarg = 'FILECOPY' THEN
        bFileCopy = True;
      END IF;
    END LOOP;
    IF bData and bDDLOnly THEN 
      RAISE WARNING 'You can only specify DDLONLY or DATA, but not both.';
      RETURN RC_ERR;
    END IF;
  END IF;  
  
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
    IF sq_server_version_num > 90600 THEN
        RAISE WARNING 'Server Version:%  Number:%  PG Versions older than v10 are not supported.  Will try however for PG 9.6...', sq_server_version, sq_server_version_num;
    ELSE
        RAISE WARNING 'Server Version:%  Number:%  PG Versions older than v10 are not supported.  You need to be at minimum version 9.6 to at least try', sq_server_version, sq_server_version_num;
        RETURN RC_ERR;
    END IF;
  END IF;

  -- Check that source_schema exists
  SELECT oid INTO src_oid
  FROM pg_namespace
  -- Issue#140
  -- WHERE nspname = quote_ident(source_schema);
  WHERE quote_ident(nspname) = quote_ident(source_schema);
  
  IF NOT FOUND
    THEN
    RAISE NOTICE ' source schema % does not exist!', source_schema;
    RETURN RC_ERR;
  END IF;

  -- Check that dest_schema does not yet exist
  PERFORM nspname
  FROM pg_namespace
  -- Issue#140
  -- WHERE nspname = quote_ident(dest_schema);
  WHERE quote_ident(nspname) = quote_ident(dest_schema);

  IF FOUND
    THEN
    RAISE NOTICE ' dest schema % already exists!', dest_schema;
    RETURN RC_ERR;
  END IF;
  IF bDDLOnly and bData THEN
    RAISE WARNING 'You cannot specify to clone data and generate ddl at the same time.';
    RETURN RC_ERR;
  END IF;

  -- Issue#92
  SELECT current_user into calleruser;
  
  -- Set the search_path to source schema. Before exiting set it back to what it was before.
  -- In order to avoid issues with the special schema name "$user" that may be
  -- returned unquoted by some applications, we ensure it remains double quoted.
  -- MJV FIX: #47
  SELECT setting INTO v_dummy FROM pg_settings WHERE name='search_path';
  -- RAISE WARNING 'DEBUGGGG: search_path=%', v_dummy;
  
  SELECT REPLACE(REPLACE(setting, '"$user"', '$user'), '$user', '"$user"') INTO v_src_path_old
  FROM pg_settings WHERE name = 'search_path';

  -- RAISE WARNING 'DEBUGGGG: v_src_path_old=%', v_src_path_old;

  lastsql = 'SET search_path = ' || quote_ident(source_schema) ;
  EXECUTE lastsql;
  lastsql = '';
  SELECT setting INTO v_src_path_new FROM pg_settings WHERE name='search_path';
  -- RAISE WARNING 'DEBUGGGG: new search_path=%', v_src_path_new; 
  
  -- Validate required types exist.  If not, create them.
  -- Issue#141, remove complex query to determine and simply drop them if they exist and recreate them.  Also put them in the public schema so they don't get propagated during cloning.
  -- DROP TYPE IF EXISTS public.objj_type;
  -- DROP TYPE IF EXISTS public.permm_type;
  SELECT count(*) INTO cnt FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
	WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
	AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
	AND n.nspname OPERATOR(pg_catalog.~) '^(public)$' COLLATE pg_catalog.default AND pg_catalog.format_type(t.oid, NULL) = 'objj_type';
	IF cnt = 1 THEN
	    DROP TYPE public.objj_type;
	END IF;
	SELECT count(*) INTO cnt FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
	WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
	AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
	AND n.nspname OPERATOR(pg_catalog.~) '^(public)$' COLLATE pg_catalog.default AND pg_catalog.format_type(t.oid, NULL) = 'permm_type';
	IF cnt = 1 THEN
	    DROP TYPE public.permm_type;
	END IF;
  
  CREATE TYPE public.objj_type AS ENUM ('TABLE','VIEW','COLUMN','SEQUENCE','FUNCTION','SCHEMA','DATABASE');
  CREATE TYPE public.permm_type AS ENUM ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','USAGE','CREATE','EXECUTE','CONNECT','TEMPORARY');

  -- Issue#95
  -- Issue#140
  -- SELECT pg_catalog.pg_get_userbyid(nspowner) INTO buffer FROM pg_namespace WHERE nspname = quote_ident(source_schema);
  SELECT pg_catalog.pg_get_userbyid(nspowner) INTO buffer FROM pg_namespace WHERE quote_ident(nspname) = quote_ident(source_schema);

  IF bDDLOnly THEN
    RAISE NOTICE ' Only generating DDL, not actually creating anything...';
    
    -- Issue#150: get clone_schema invoker since we need to reset it again after setting DEFAULT PRIVILEGES
    SELECT current_role INTO role_invoker;
    
    -- issue#95
    IF bNoOwner THEN
        RAISE INFO 'CREATE SCHEMA %;', quote_ident(dest_schema);    
    ELSE
        -- Issue#131: double quote schema names
        -- RAISE INFO 'CREATE SCHEMA % AUTHORIZATION %;', quote_ident(dest_schema), buffer;    
        RAISE INFO 'CREATE SCHEMA % AUTHORIZATION %;', quote_ident(dest_schema), quote_ident(buffer);  
    END IF;
    
    -- Issue#150: set search path for target schema
    -- RAISE NOTICE 'SET search_path=%;', quote_ident(dest_schema);
		RAISE INFO 'set search_path = public, %;', quote_ident(dest_schema);
    
  ELSE
    -- issue#95
    IF bNoOwner THEN
        lastsql = 'CREATE SCHEMA ' || quote_ident(dest_schema) ; 
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %',lastsql; END IF;
        EXECUTE lastsql;
        lastsql = '';
    ELSE
        -- Issue#131: double quote schema names
        -- EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) || ' AUTHORIZATION ' || buffer;
        -- EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) || ' AUTHORIZATION ' || quote_ident(buffer);
        lastsql = 'CREATE SCHEMA ' || quote_ident(dest_schema) || ' AUTHORIZATION ' || buffer;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %',lastsql; END IF;
        EXECUTE lastsql;    
        lastsql = '';
    END IF;
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
  rc = 21;
  IF bDebug THEN RAISE NOTICE 'DEBUG:  Section=%',action; END IF;
  cnt := 0;
  -- Issue#96 Handle differently based on PG Versions (PG15 rely on colliculocale, not collcollate; PG17 uses colllocale)
  -- perhaps use this logic instead: COALESCE(c.collcollate, c.colliculocale) AS lc_collate, COALESCE(c.collctype, c.colliculocale) AS lc_type  
  IF sq_server_version_num >= 170000 THEN
    FOR arec IN
      SELECT n.nspname AS schemaname, a.rolname AS ownername, c.collname, c.collprovider, c.collcollate AS locale, 
             'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || 
             CASE WHEN c.collprovider = 'i' THEN 'icu' WHEN c.collprovider = 'c' THEN 'libc' ELSE '' END || 
             ', locale = ''' || c.colllocale || ''');' AS COLL_DDL
      FROM pg_collation c
          JOIN pg_namespace n ON (c.collnamespace = n.oid)
          JOIN pg_roles a ON (c.collowner = a.oid)
      -- Issue#140    
      -- WHERE n.nspname = quote_ident(source_schema)
      WHERE n.nspname = source_schema
      ORDER BY c.collname
    LOOP
      BEGIN
        cnt := cnt + 1;
        IF bDDLOnly THEN
          RAISE INFO '%', arec.coll_ddl;
        ELSE
          lastsql = arec.coll_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END;
    END LOOP;
  ELSIF sq_server_version_num >= 150000 THEN
    FOR arec IN
      SELECT n.nspname AS schemaname, a.rolname AS ownername, c.collname, c.collprovider, c.collcollate AS locale, 
             'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || 
             CASE WHEN c.collprovider = 'i' THEN 'icu' WHEN c.collprovider = 'c' THEN 'libc' ELSE '' END || 
             ', locale = ''' || c.colliculocale || ''');' AS COLL_DDL
      FROM pg_collation c
          JOIN pg_namespace n ON (c.collnamespace = n.oid)
          JOIN pg_roles a ON (c.collowner = a.oid)
      -- Issue#140              
      -- WHERE n.nspname = quote_ident(source_schema)
      WHERE n.nspname = source_schema
      ORDER BY c.collname
    LOOP
      BEGIN
        cnt := cnt + 1;
        IF bDDLOnly THEN
          RAISE INFO '%', arec.coll_ddl;
        ELSE
          lastsql = arec.coll_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END;
    END LOOP;
  ELSIF sq_server_version_num >= 100000 THEN
    FOR arec IN
      SELECT n.nspname AS schemaname, a.rolname AS ownername, c.collname, c.collprovider, c.collcollate AS locale, 
             'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || 
             CASE WHEN c.collprovider = 'i' THEN 'icu' WHEN c.collprovider = 'c' THEN 'libc' ELSE '' END || 
             ', locale = ''' || c.collcollate || ''');' AS COLL_DDL
      FROM pg_collation c
          JOIN pg_namespace n ON (c.collnamespace = n.oid)
          JOIN pg_roles a ON (c.collowner = a.oid)
      -- Issue#140              
      -- WHERE n.nspname = quote_ident(source_schema)
      WHERE n.nspname = source_schema
      ORDER BY c.collname
    LOOP
      BEGIN
        cnt := cnt + 1;
        IF bDDLOnly THEN
          RAISE INFO '%', arec.coll_ddl;
        ELSE
          lastsql = arec.coll_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END;
    END LOOP;
  ELSE
    -- handle 9.6 that is missing some columns in pg_collation
    FOR arec IN
      SELECT n.nspname AS schemaname, a.rolname AS ownername, c.collname, c.collcollate AS locale, 
             'CREATE COLLATION ' || quote_ident(dest_schema) || '."' || c.collname || '" (provider = ' || 
             ', locale = ''' || c.collcollate || ''');' AS COLL_DDL
      FROM pg_collation c
          JOIN pg_namespace n ON (c.collnamespace = n.oid)
          JOIN pg_roles a ON (c.collowner = a.oid)
      -- Issue#140
      -- WHERE n.nspname = quote_ident(source_schema)
      WHERE n.nspname = source_schema
      ORDER BY c.collname
    LOOP
      BEGIN
        cnt := cnt + 1;
        IF bDDLOnly THEN
          RAISE INFO '%', arec.coll_ddl;
        ELSE
          lastsql = arec.coll_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END;
    END LOOP;
  END IF;
  RAISE NOTICE '  COLLATIONS cloned: %', LPAD(cnt::text, 5, ' ');

  -- MV: Create Domains
  action := 'Domains';
  rc = 22;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  
  -- Issue%138: Need to change query to be compatible with PG17 and still work with previous versions
  FOR arec IN
    SELECT n.nspname as "Schema", t.typname, pg_catalog.format_type(t.typbasetype, t.typtypmod) as atype,
    (SELECT c.collname FROM pg_catalog.pg_collation c, pg_catalog.pg_type bt WHERE c.oid = t.typcollation AND bt.oid = t.typbasetype AND t.typcollation <> bt.typcollation) as "Collation",
    t.typnotnull, 
    t.typdefault,
    COALESCE(pg_catalog.array_to_string(ARRAY(SELECT pg_catalog.pg_get_constraintdef(r.oid, true) FROM pg_catalog.pg_constraint r WHERE t.oid = r.contypid AND r.contype = 'c' ORDER BY r.conname), ''), '') as acheck
    -- Issue#140
    -- FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace WHERE t.typtype = 'd' AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default ORDER BY 1, 2
    FROM pg_catalog.pg_type t LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace WHERE t.typtype = 'd' AND n.nspname = source_schema COLLATE pg_catalog.default ORDER BY 1, 2
  LOOP
    BEGIN
      cnt := cnt + 1;
      -- format: CREATE DOMAIN clone1.addr3 AS character varying(90) NOT NULL DEFAULT 'N/A'::character varying CHECK (VALUE::text > ''::text);                
      lastsql = 'CREATE DOMAIN ' || quote_ident(dest_schema) || '.' || quote_ident(arec.typname) || ' AS ' || arec.atype || CASE WHEN arec.typnotnull IS NOT NULL THEN ' NOT NULL' ELSE '' END ||
                CASE WHEN arec.typdefault IS NOT NULL THEN ' DEFAULT ' || arec.typdefault ELSE '' END || CASE WHEN arec.acheck <> '' THEN ' ' || arec.acheck ELSE '' END || ';' ;
      IF bDDLOnly THEN
        RAISE INFO '%', lastsql;
      ELSE
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '     DOMAINS cloned: %', LPAD(cnt::text, 5, ' ');
  
  
  -- MV: Create types
  action := 'Types';
  rc = 23;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  lastsql = '';
  FOR arec IN
    -- Fixed Issue#108:enclose double-quote roles with special characters for setting "OWNER TO"
    -- SELECT c.relkind, n.nspname AS schemaname, t.typname AS typname, t.typcategory, pg_catalog.pg_get_userbyid(t.typowner) AS owner, CASE WHEN t.typcategory = 'C' THEN
    SELECT c.relkind, n.nspname AS schemaname, t.typname AS typname, t.typcategory, '"' || pg_catalog.pg_get_userbyid(t.typowner) || '"' AS owner, CASE WHEN t.typcategory = 'C' THEN
        -- Fixed Issue#148 for case-sensitive types
            -- 'CREATE TYPE ' || quote_ident(dest_schema) || '.' || t.typname || ' AS (' || array_to_string(array_agg(a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod)
            'CREATE TYPE ' || quote_ident(dest_schema) || '.' || quote_ident(t.typname) || ' AS (' || array_to_string(array_agg(a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod)            
             ORDER BY c.relname, a.attnum), ', ') || ');'
        WHEN t.typcategory = 'E' THEN
            -- 'CREATE TYPE ' || quote_ident(dest_schema) || '.' || t.typname || ' AS ENUM (' || REPLACE(quote_literal(array_to_string(array_agg(e.enumlabel ORDER BY e.enumsortorder), ',')), ',', ''',''') || ');'
            'CREATE TYPE ' || quote_ident(dest_schema) || '.' || quote_ident(t.typname) || ' AS ENUM (' || REPLACE(quote_literal(array_to_string(array_agg(e.enumlabel ORDER BY e.enumsortorder), ',')), ',', ''',''') || ');'
        ELSE
            ''
        END AS type_ddl
    FROM pg_type t
        JOIN pg_namespace n ON (n.oid = t.typnamespace)
        LEFT JOIN pg_enum e ON (t.oid = e.enumtypid)
        LEFT JOIN pg_class c ON (c.reltype = t.oid)
        LEFT JOIN pg_attribute a ON (a.attrelid = c.oid)
    -- Issue#131: no need to quote_ident
    -- WHERE n.nspname = quote_ident(source_schema)
    WHERE n.nspname = source_schema
        AND (c.relkind IS NULL
            OR c.relkind = 'c')
        AND t.typcategory IN ('C', 'E')
    GROUP BY 1, 2, 3, 4, 5
    ORDER BY n.nspname, t.typcategory, t.typname

  LOOP
    BEGIN
      cnt := cnt + 1;
      -- RAISE NOTICE 'DEBUGGG:%',arec.type_ddl;
      -- Keep composite and enum types in separate branches for fine tuning later if needed.
      IF arec.typcategory = 'E' THEN
        IF bDDLOnly THEN
          RAISE INFO '%', arec.type_ddl;
          
          --issue#95
          IF NOT bNoOwner THEN
            -- Fixed Issue#108: double-quote roles in case they have special characters
            -- Fixed Issue#148: double-quote types as well if they have special characterss
            RAISE INFO 'ALTER TYPE % OWNER TO  %;', quote_ident(dest_schema) || '.' || quote_ident(arec.typname), arec.owner;
          END IF;
        ELSE
          lastsql = arec.type_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';

          --issue#95
          IF NOT bNoOwner THEN
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Fixed Issue#148: double-quote types as well if they have special characterss
              lastsql = 'ALTER TYPE ' || quote_ident(dest_schema) || '.' || quote_ident(arec.typname) || ' OWNER TO ' || arec.owner; 
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
	            EXECUTE lastsql;
	            lastsql = '';
	        END IF;
        END IF;
      ELSIF arec.typcategory = 'C' THEN
        IF bDDLOnly THEN
          RAISE INFO '%', arec.type_ddl;
          --issue#95
          IF NOT bNoOwner THEN
            -- Fixed Issue#108: double-quote roles in case they have special characters
            -- Fixed Issue#148: double-quote types as well if they have special characterss
            RAISE INFO 'ALTER TYPE % OWNER TO  %;', quote_ident(dest_schema) || '.' || quote_ident(arec.typname), arec.owner;
          END IF;
        ELSE
          lastsql = arec.type_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE arec.type_ddl;
          lastsql = '';
          --issue#95
          IF NOT bNoOwner THEN
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Fixed Issue#148: double-quote types as well if they have special characterss
              lastsql = 'ALTER TYPE ' || quote_ident(dest_schema) || '.' || quote_ident(arec.typname) || ' OWNER TO ' || arec.owner; 
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
	            EXECUTE 'ALTER TYPE ' || quote_ident(dest_schema) || '.' || quote_ident(arec.typname) || ' OWNER TO ' || arec.owner;
	            lastsql = '';
	        END IF;
        END IF;
      ELSE
          RAISE NOTICE ' Unhandled type:%-%', arec.typcategory, arec.typname;
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '       TYPES cloned: %', LPAD(cnt::text, 5, ' ');

  -- Create sequences for explicity sequences and serial types, do Identity later...
  action := 'Sequences';
  rc = 24;
  cnt := 0;
  seqcnt := 0;
  setcnt := 0;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  
  -- Issue#142 Total rewrite of this section.  We bypass serial and identity in the loop, only processing explicit sequence definitions
	-- Updating the next sequence value to the last value of each sequence-type table (sequences, serial, identity) assumes that the those tables have been incremented the normal way, not overriding system values.
  -- Otherwise, they would have to be re-initialized manually after they are cloned, i.e., nextval returns inaccurate info.
  -- NOTE: pg_dump exports serial columns the same as sequence columns, so while a table can be created with a serial column, when it is exported, it appears just like a sequence with nextval definition
  
  FOR relid, aschema, tblname, colname, seqname, deptype, attidentity, seqtype, coldef, formattype, seqowner, lastvalue IN
    SELECT a.attrelid as relid, tns.nspname AS schema, t.relname AS table_name, a.attname AS column_name, s.relname AS sequence_name, COALESCE(d.deptype, ''), COALESCE(a.attidentity, '') as attidentity, 
    CASE WHEN a.attidentity IS NULL THEN '' WHEN a.attidentity in ('a','d') THEN 'IDENTITY' ELSE '' END as seqtype,
    (SELECT * FROM public.pg_get_coldef(tns.nspname,t.relname,a.attname)) as coldef, pg_catalog.format_type(a.atttypid, a.atttypmod) as format_type, pg_get_userbyid (s.relowner) as owner, 
    (SELECT COALESCE(lastvalue, -999) as lastvalue FROM pg_sequences WHERE schemaname = source_schema AND sequencename = s.relname and sequenceowner = pg_get_userbyid (s.relowner)) as lastvalue
    FROM pg_namespace tns JOIN pg_class t ON tns.oid = t.relnamespace AND t.relkind IN ('p', 'r') JOIN pg_attribute a ON t.oid = a.attrelid AND NOT a.attisdropped
    JOIN pg_depend d ON t.oid = d.refobjid AND d.refobjsubid = a.attnum JOIN pg_class s ON d.objid = s.oid and s.relkind = 'S' JOIN pg_namespace sns ON s.relnamespace = sns.oid AND tns.nspname = source_schema
    UNION 
    SELECT 0 as relid, ss.schemaname as schema, '' AS table_name, '' as column_name, ss.sequencename as sequence_name, '' as deptype, '' as attidentity, '' as seqtype, '' as coldef, ss.data_type::text as format_type, 
    ss.sequenceowner as owner, COALESCE(ss.last_value, -999) as lastvalue
    FROM pg_sequences ss where ss.schemaname = source_schema
    AND NOT EXISTS 
    (SELECT 1 FROM pg_namespace tns JOIN pg_class t ON tns.oid = t.relnamespace AND t.relkind IN ('p', 'r') JOIN pg_attribute a ON t.oid = a.attrelid AND NOT a.attisdropped
    JOIN pg_depend d ON t.oid = d.refobjid AND d.refobjsubid = a.attnum JOIN pg_class s ON d.objid = s.oid and s.relkind = 'S' JOIN pg_namespace sns ON s.relnamespace = sns.oid AND tns.nspname = source_schema and s.relname = ss.sequencename)
    ORDER BY 5
  LOOP
    cnt := cnt + 1;
    -- RAISE NOTICE 'DEBUGGGG: relid=%  aschema=%  tblname=%  colname=%  seqname=%  deptype=%  attidentity=%  seqtype=%  coldef=%  formattype=%  seqowner=%  lastvalue=%', 
    --                         relid, aschema, tblname, colname, seqname, deptype, attidentity, seqtype, coldef, formattype, seqowner, lastvalue;
    -- IF coldef = '' OR coldef = 'serial' OR coldef = 'bigserial' OR coldef = 'smallserial' THEN
    IF seqtype = 'IDENTITY' THEN
        IF bDebug THEN RAISE NOTICE 'DEBUG: bypassing sequence=%  seqtype=%', seqname, seqtype; END IF;    
        CONTINUE;
    ELSE
        IF bDebug THEN RAISE NOTICE 'DEBUG: handling sequence=%  seqtype=%', seqname, seqtype; END IF;
        seqcnt = seqcnt + 1;    
    END IF;

    IF bDDLOnly THEN
      -- issue#95
      RAISE INFO '%', 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(seqname) || ';';
      IF NOT bNoOwner THEN    
        -- Fixed Issue#108: double-quote roles in case they have special characters
        RAISE INFO '%', 'ALTER  SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(seqname) || ' OWNER TO ' || seqowner || ';';
      END IF;
    ELSE
      lastsql = 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(seqname) || ';'; 
      -- RAISE NOTICE 'DEBUGGGG: %', lastsql;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
      EXECUTE lastsql;
      lastsql = '';

      -- issue#95
      IF NOT bNoOwner THEN    
        lastsql = 'ALTER SEQUENCE '  || quote_ident(dest_schema) || '.' || quote_ident(seqname) || ' OWNER TO ' || seqowner;
        -- RAISE NOTICE 'DEBUGGGG: EXEC: %', lastsql; 
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        -- Fixed Issue#108: double-quote roles in case they have special characters
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    END IF;
    
    -- Specify OWNED BY but only if sequence is used, i.e., associated with a table/column
    -- ALTER SEQUENCE "CaseSensitive_ID_seq" OWNED BY "CaseSensitive"."ID";
    IF tblname <> '' AND colname <> '' THEN
        buffer = 'ALTER SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(seqname) || ' OWNED BY ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || '.' || quote_ident(colname) || ';';
        -- Need to defer until after tables are created
        tblarray4 := tblarray4 || buffer;
		    -- EXECUTE buffer;
		END IF;
    
    EXECUTE 'SELECT max_value, start_value, increment_by, min_value, cache_size, cycle, data_type, COALESCE(last_value, -999)
            FROM pg_catalog.pg_sequences WHERE schemaname='|| quote_literal(source_schema) || ' AND sequencename=' || quote_literal(seqname) || ';'
            INTO sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_is_cycled, sq_data_type, sq_last_value;
        
    IF sq_is_cycled
      THEN
        sq_cycled := 'CYCLE';
    ELSE
        sq_cycled := 'NO CYCLE';
    END IF;

    qry := 'ALTER SEQUENCE '   || quote_ident(dest_schema) || '.' || quote_ident(seqname)
           || ' AS ' || sq_data_type
           || ' INCREMENT BY ' || sq_increment_by
           || ' MINVALUE '     || sq_min_value
           || ' MAXVALUE '     || sq_max_value
           -- will update current sequence value after this
           || ' START WITH '   || sq_start_value
           || ' RESTART '      || sq_min_value
           || ' CACHE '        || sq_cache_value
           || ' '              || sq_cycled || ' ;' ;

    IF bDDLOnly THEN
      RAISE INFO '%', qry;
    ELSE
      lastsql = qry;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
      EXECUTE lastsql;
      lastsql = '';
    END IF;

    -- Bypass setting sequence start values if it was never initialized, i.e., last_value is NULL
    IF sq_last_value = -999 THEN
        IF bDebug THEN RAISE NOTICE 'bypassing setting sequence start value for sequence(%) since never initialized', seqname; END IF;
        continue;
    ELSE
        setcnt = setcnt + 1;
    END IF;
    
    buffer := quote_ident(dest_schema) || '.' || quote_ident(seqname);
    IF bData THEN
      qry = 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %',qry; END IF;
      EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
    ELSE
      if bDDLOnly THEN
        -- fix#63
        --  RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
        RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
      ELSE
        -- fix#63
        -- EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
        EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;

        qry = 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %',qry; END IF;
      END IF;

    END IF;
  END LOOP;
  RAISE NOTICE '   SEQUENCES cloned: %', LPAD(seqcnt::text, 5, ' ');
  RAISE NOTICE '   SEQUENCES    set: %', LPAD(setcnt::text, 5, ' ');

  -- Create tables including partitioned ones (parent/children) and unlogged ones.  Order by is critical since child partition range logic is dependent on it.
  action := 'Tables';
  rc = 25;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  SELECT setting INTO v_dummy FROM pg_settings WHERE name='search_path';
  -- RAISE WARNING 'DEBUGGGG: search_path=%', v_dummy; 
  
  cntables := 0;
  lasttbl = '';
  -- Issue#61 FIX: use set_config for empty string
  -- SET search_path = '';
  -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
  SELECT set_config('search_path', '', true) into v_dummy;
  -- RAISE WARNING 'DEBUGGGG: setting search_path to empty string:%', v_dummy;
  -- Fix#86 add isgenerated to column list
  -- Fix#91 add tblowner for setting the table ownership to that of the source
  -- Fix#99 added join to pg_tablespace
  
  -- Handle PG versions greater than last major/minor version of PG 9.6.24
  IF sq_server_version_num > 90624 THEN
  FOR tblname, relpersist, bRelispart, relknd, data_type, udt_name, udt_schema, ocomment, l_child, isGenerated, tblowner, tblspace  IN
    -- 2021-03-08 MJV #39 fix: change sql to get indicator of user-defined columns to issue warnings
    -- select c.relname, c.relpersistence, c.relispartition, c.relkind
    -- FROM pg_class c, pg_namespace n where n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and c.relkind in ('r','p') and
    -- order by c.relkind desc, c.relname
    --Fix#65 add another left join to distinguish child tables by inheritance
    -- Fix#86 add is_generated to column select
    -- Fix#91 add tblowner to the select
    -- Fix#105 need a different kinda distinct to avoid retrieving a table twice in the case of a table with multiple USER-DEFINED datatypes using DISTINCT ON instead of just DISTINCT
    --SELECT DISTINCT c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type, co.udt_name, co.udt_schema, obj_description(c.oid), i.inhrelid, 
    --                COALESCE(co.is_generated, ''), pg_catalog.pg_get_userbyid(c.relowner) as "Owner", CASE WHEN reltablespace = 0 THEN 'pg_default' ELSE ts.spcname END as tablespace
    -- fixed #108 by enclosing owner in double quotes to avoid errors for bad characters like #.@...
    -- SELECT DISTINCT ON (c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type) c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type, co.udt_name, co.udt_schema, obj_description(c.oid), i.inhrelid, 
    SELECT DISTINCT ON (c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type) c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type, co.udt_name, co.udt_schema, obj_description(c.oid), i.inhrelid, 
                    COALESCE(co.is_generated, ''), '"' || pg_catalog.pg_get_userbyid(c.relowner) || '"' as "Owner", CASE WHEN reltablespace = 0 THEN 'pg_default' ELSE ts.spcname END as tablespace                    
    FROM pg_class c
        JOIN pg_namespace n ON (n.oid = c.relnamespace
                -- Issue#140
                -- AND n.nspname = quote_ident(source_schema)
                AND n.nspname = source_schema
                AND c.relkind IN ('r', 'p'))
        LEFT JOIN information_schema.columns co ON (co.table_schema = n.nspname
                AND co.table_name = c.relname
                AND (co.data_type = 'USER-DEFINED' OR co.is_generated = 'ALWAYS'))
        LEFT JOIN pg_inherits i ON (c.oid = i.inhrelid) 
        -- issue#99 added join
        LEFT JOIN pg_tablespace ts ON (c.reltablespace = ts.oid) 
    ORDER BY c.relkind DESC, c.relname
  LOOP
    cntables := cntables + 1;
    lastsql = '';
    
    -- Issue#121 we may have dup tables due to multiple user-defined different datatypes, so skip 2-n occurences of them
    IF lasttbl = tblname THEN
        IF bDebug THEN RAISE INFO 'DEBUG: skipping dup table, %', tblname; END IF;
        continue;
    END IF;
    
    lasttbl = tblname;
    IF l_child IS NULL THEN
      bChild := False;
    ELSE
      bChild := True;
    END IF;
    IF bDebug THEN RAISE NOTICE 'DEBUG: TABLE START --> table=%  bRelispart=%  relkind=%  bChild=%',tblname, bRelispart, relknd, bChild; END IF;

    IF data_type = 'USER-DEFINED' THEN
      IF bDebug THEN RAISE NOTICE 'DEBUG: Table (%) has column(s) with user-defined types so using pg_get_tabledef() instead of CREATE TABLE LIKE construct.',tblname; END IF;
      cntables :=cntables;
    END IF;
    buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);
    buffer2 := '';
    IF relpersist = 'u' THEN
      buffer2 := 'UNLOGGED ';
    END IF;
    IF relknd = 'r' THEN
      IF bDDLOnly THEN
        IF data_type = 'USER-DEFINED' THEN
          -- FIXED #65, #67
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
          -- FIX: #121 Use pg_get_tabledef instead
          -- Issue#140 remove quote_ident!
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');          
          SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');          
          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- Issue#150 : Add INFO lines if we are in DDLONLY mode
          IF bDDLOnly THEN
              buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
              buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
          END IF;
          RAISE INFO '%', buffer3;

          -- issue#91 fix
          -- issue#95
          IF NOT bNoOwner THEN    
            -- Fixed Issue#108: double-quote roles in case they have special characters
            -- Issue#150: do same for tables and defer if children
            -- RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || tblname, tblowner;
            IF bChild THEN
                v_dummy = 'INFO:  ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner || ';';
                DDLAltTblDefer := DDLAltTblDefer || v_dummy;
            ELSE
                RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
            END IF;
          END IF;
        ELSE
          IF NOT bChild THEN
            RAISE INFO '%', 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL);';
            -- issue#91 fix
             -- issue#95
            IF NOT bNoOwner THEN    
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Issue#150: do same for tables
              -- RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || tblname, tblowner;
              RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
            END IF;
            
            -- issue#99 
            IF tblspace <> 'pg_default' THEN
              -- replace with user-defined tablespace
              -- ALTER TABLE myschema.mytable SET TABLESPACE usrtblspc;
              -- Issue#150: Handle case-sensitive tables too
              -- RAISE INFO 'ALTER TABLE IF EXISTS % SET TABLESPACE %;', quote_ident(dest_schema) || '.' || tblname, tblspace;
              RAISE INFO 'ALTER TABLE IF EXISTS % SET TABLESPACE %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblspace;
            END IF;
          ELSE
            -- FIXED #65, #67
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
            -- FIX: #121 Use pg_get_tabledef instead
            -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
            -- Issue#140 remove quote_ident!
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
            SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
            buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
            -- Issue#150 : Add INFO lines if we are in DDLONLY mode
				    buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
				    buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
				    -- Issue#150: defer child index creations until after parent is created later
				    IF bChild THEN
				        DDLCreateIXDefer := DDLCreateIXDefer || buffer3;
				        -- note child table so we don't attempt to attach it explicitly later
				        v_dummy = quote_ident(dest_schema) || '.' || tblname;
				        DDLAttachSkip = DDLAttachSkip || v_dummy;
				    ELSE
				        RAISE INFO '%', buffer3;
				    END IF;
         
            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN    
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Issue#150: do same for tables and defer if child and we are in DDLONLY mode
              -- RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || tblname, tblowner;
              IF bChild THEN
                  v_dummy = 'INFO:  ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner || ';';
                  DDLAltTblDefer = DDLAltTblDefer || v_dummy;
              ELSE
                  RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
              END IF;              
            END IF;
          END IF;
        END IF;
      ELSE
        IF data_type = 'USER-DEFINED' THEN
          -- FIXED #65, #67
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
          -- FIX: #121 Use pg_get_tabledef instead
          -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
          -- SELECT * INTO buffer3 FROM public.get_table_ddl_complex(source_schema, dest_schema, tblname, sq_server_version_num);     
          -- Issue#140 remove quote_ident!
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
          SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- Issue#150 : Add INFO lines if we are in DDLONLY mode
					IF bDDLOnly THEN
					    buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
					    buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
					END IF;
          IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef01a:%', buffer3; END IF;

          -- #82: Table def should be fully qualified with target schema, 
          --      so just make search path = public to handle extension types that should reside in public schema
          v_dummy = 'public';
          -- RAISE WARNING 'DEBUGGGG: setting search_path to public:%', v_dummy;
          -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
          SELECT set_config('search_path', v_dummy, true) into v_dummy;
          -- RAISE WARNING 'DEBUGGGG: search_path=%',v_dummy;
          lastsql = buffer3;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
          -- issue#91 fix
          -- issue#95
          IF NOT bNoOwner THEN    
            -- Fixed Issue#108: double-quote roles in case they have special characters
            -- Issue#150: do same for tables
            -- lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || tblname || ' OWNER TO ' || tblowner;
            lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
          END IF;
        ELSE
          IF (NOT bChild OR bRelispart) THEN
            buffer3 := 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL)';
            IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef02:%', buffer3; END IF;
            lastsql = buffer3;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN    
              -- Fixed Issue#108: double-quote roles in case they have special characters
              lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.'  || quote_ident(tblname) || ' OWNER TO ' || tblowner;
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
            END IF;
            
            -- issue#99
            IF tblspace <> 'pg_default' THEN
              -- replace with user-defined tablespace
              -- ALTER TABLE myschema.mytable SET TABLESPACE usrtblspc;
              -- Issue#150: Handle case-sensitive tables
              -- lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || tblname || ' SET TABLESPACE ' || tblspace;
              lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' SET TABLESPACE ' || tblspace;
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
            END IF;

          ELSE
            -- FIXED #65, #67
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
            -- FIX: #121 Use pg_get_tabledef instead
            -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
            -- Issue#140 remove quote_ident!
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
            SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
            buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
            -- Issue#150 : Add INFO lines if we are in DDLONLY mode
						IF bDDLOnly THEN
						    buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
						    buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
					  END IF;
            
            -- set client_min_messages higher to avoid messages like this:
            -- NOTICE:  merging column "city_id" with inherited definition
            set client_min_messages = 'WARNING';
            IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef03:%', buffer3; END IF;
            lastsql = buffer3;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Issue#150: Handle case-sensitive tables
              -- lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || tblname || ' OWNER TO ' || tblowner;
              lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
            END IF;

            -- reset it back, only get these for inheritance-based tables
            set client_min_messages = 'notice';
          END IF;
        END IF;
        -- Add table comment.
        IF ocomment IS NOT NULL THEN
          lastsql = 'COMMENT ON TABLE ' || buffer || ' IS ' || quote_literal(ocomment); 
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END IF;
    ELSIF relknd = 'p' THEN
      -- define parent table and assume child tables have already been created based on top level sort order.
      -- Issue #103 Put the complex query into its own function, get_table_ddl_complex()
      -- FIX: #121 Use pg_get_tabledef instead
      -- SELECT * INTO qry FROM public.get_table_ddl_complex(source_schema, dest_schema, tblname, sq_server_version_num);
      -- Issue#140 remove quote_ident!
      -- SELECT * INTO qry FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
      SELECT * INTO qry FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
      qry := REPLACE(qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
      -- Issue#150 : Add INFO lines if we are in DDLONLY mode
			IF bDDLOnly THEN
    	    qry := REPLACE(qry, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
					qry := REPLACE(qry, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
			END IF;
      IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef04 - %', qry; END IF;

      IF bDDLOnly THEN
        RAISE INFO '%', qry;
        -- issue#95
        IF NOT bNoOwner THEN
            -- Fixed Issue#108: double-quote roles in case they have special characters
            RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
        END IF;
      ELSE
        -- Issue#103: we need to always set search_path priority to target schema when we execute DDL
        SELECT setting INTO spath_tmp FROM pg_settings WHERE name = 'search_path';   
        -- RAISE WARNING 'DEBUGGGG: tabledef04 context: current search_path=%', spath_tmp;
        IF spath_tmp <> dest_schema THEN
          -- change it to target schema and don't forget to change it back after we execute the DDL
          spath = 'SET search_path = "' || dest_schema || '"';
          EXECUTE spath;
          -- RAISE WARNING 'DEBUGGGG: changed search_path --> %', spath;
          SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';   
          -- RAISE WARNING 'DEBUGGGG: current search_path --> %', v_dummy;
        END IF;
        IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef04:%', qry; END IF;
        lastsql = qry;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        EXECUTE qry;
        lastsql = '';
        -- Issue#103
        -- Set search path back to what it was
        -- Issue#131: do not surround with single ticks
        -- spath = 'SET search_path = "' || spath_tmp || '"';
        IF spath_tmp IS NULL OR spath_tmp = '' THEN 
            -- no need to change search_path
            NULL;
        ELSE
            spath = 'SET search_path = ' || spath_tmp;
            -- RAISE WARNING 'DEBUGGGG: setting search_path back to:%  --> %', spath_tmp,spath;
            EXECUTE spath;
            SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';   
            -- RAISE WARNING 'DEBUGGGG: search_path changed back to %', v_dummy; 
        END IF;
        -- issue#91 fix
        -- issue#95
        IF NOT bNoOwner THEN
          -- Fixed Issue#108: double-quote roles in case they have special characters
          lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END IF;

      -- loop for child tables and alter them to attach to parent for specific partition method.
      -- Issue#103 fix: only loop for the table we are currently processing, tblname!
      FOR aname, part_range, object IN
        SELECT quote_ident(dest_schema) || '.' || c1.relname as tablename, pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) as partrange, quote_ident(dest_schema) || '.' || c2.relname as object
        FROM pg_catalog.pg_class c1, pg_namespace n, pg_catalog.pg_inherits i, pg_class c2
        -- Issue#140
        -- WHERE n.nspname = quote_ident(source_schema) AND c1.relnamespace = n.oid AND c1.relkind = 'r' 
        WHERE n.nspname = source_schema AND c1.relnamespace = n.oid AND c1.relkind = 'r' 
        -- Issue#103: added this condition to only work on current partitioned table.  The problem was regression testing previously only worked on one partition table clone case
        AND c2.relname = tblname AND 
        c1.relispartition AND c1.oid=i.inhrelid AND i.inhparent = c2.oid AND c2.relnamespace = n.oid ORDER BY pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) = 'DEFAULT',
        c1.oid::pg_catalog.regclass::pg_catalog.text
      LOOP
        qry := 'ALTER TABLE ONLY ' || object || ' ATTACH PARTITION ' || aname || ' ' || part_range || ';';
        IF bDebug THEN RAISE NOTICE 'DEBUG: %',qry; END IF;
        -- issue#91, not sure if we need to do this for child tables
        -- issue#95 we dont set ownership here
        
        -- Issue#150: defer attaching children to parents if in DDLONLY mode
        IF bDDLOnly THEN
          DDLAttachDefer = DDLAttachDefer || qry;
          IF NOT bNoOwner THEN
            NULL;
          END IF;          
        ELSE
          lastsql = qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
          IF NOT bNoOwner THEN
            NULL;
          END IF;
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
      -- Issue#133: We never get here when DDLONLY is specified since it depends on the cloned schema being created, so ALTER INDEX action does not happen on DDLONLY commands
      IF bDDLOnly THEN
        RAISE INFO '%', 'ALTER INDEX ' || quote_ident(dest_schema) || '.'  || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';';
      ELSE
        -- The SELECT query above may return duplicate names when a column is indexed twice the same manner with 2 different names. Therefore, to
        -- avoid a 'relation "xxx" already exists' we test if the index name is in use or free. Skipping existing index will fallback on unused
        -- ones and every duplicate will be mapped to distinct old names.
        -- Issue#133: index names may be different when the table is created with the LIKE... INCLUDING ALL construct, so change the name to what is was in the original for primary keys and non-unique indexes at the present time
        --  IF NOT EXISTS (
        --     SELECT TRUE
        --     FROM pg_indexes
        --     WHERE schemaname = dest_schema
        --       AND tablename = tblname
        --       AND indexname = quote_ident(ix_old_name))
        --   AND EXISTS (
        --     SELECT TRUE
        --     FROM pg_indexes
        --     WHERE schemaname = dest_schema
        --       AND tablename = tblname
        --       AND indexname = quote_ident(ix_new_name))
        --   THEN
        -- RAISE NOTICE 'AAAA: schema=%  table=%  oldixname=%  newixname=%',quote_ident(source_schema), tblname, ix_old_name, ix_new_name;
        -- Issue#133: bypass unique keys
        -- IF NOT EXISTS (SELECT TRUE FROM pg_class c, pg_constraint ct WHERE ct.conrelid = c.oid AND c.relnamespace::regnamespace::text = quote_ident(source_schema) AND c.relname = tblname AND ct.contype IN ('p', 'u') AND ct.conname = ix_old_name) 
        IF NOT EXISTS (SELECT TRUE FROM pg_class c, pg_constraint ct WHERE ct.conrelid = c.oid AND c.relnamespace::regnamespace::text = quote_ident(source_schema) AND c.relname = tblname AND ct.contype IN ('u') AND ct.conname = ix_old_name) 
				THEN
				  -- Issue#133: bypass columns we can't find in new schema probably due to CREATE TABLE LIKE constructs where fabricated index names are created automatically.
				  -- Issue#140
	        -- SELECT count(*) INTO cnt FROM pg_indexes WHERE schemaname = quote_ident(dest_schema) AND tablename = tblname AND indexname =  ix_new_name AND ix_old_name <> ix_new_name AND NOT EXISTS (SELECT TRUE FROM pg_indexes 
	        -- WHERE schemaname = quote_ident(dest_schema) AND tablename = tblname AND indexname =  ix_old_name);
	        SELECT count(*) INTO cnt FROM pg_indexes WHERE schemaname = dest_schema AND tablename = tblname AND indexname =  ix_new_name AND ix_old_name <> ix_new_name AND NOT EXISTS (SELECT TRUE FROM pg_indexes 
	        WHERE schemaname = dest_schema AND tablename = tblname AND indexname =  ix_old_name);
	        IF cnt > 0 THEN
              lastsql = 'ALTER INDEX ' || quote_ident(dest_schema) || '.' || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';'; 
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
          ELSE
              IF bDebugExec THEN RAISE NOTICE 'EXEC: bypassing(1a) altering index from % TO % for table, %', ix_new_name, ix_old_name, tblname; END IF;   
          END IF;
        ELSE
          IF bDebugExec THEN RAISE NOTICE 'EXEC: bypassing(1b) altering index from % TO % for table, %', ix_new_name, ix_old_name, tblname; END IF;   
        END IF;
      END IF;
    END LOOP;

    lastsql = '';
    IF bData THEN
      -- Insert records from source table

      -- 2021-03-03  MJV FIX
      -- Issue#140 fix
      -- buffer := dest_schema || '.' || quote_ident(tblname);
      buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);

      -- 2020/06/18 - Issue #31 fix: add "OVERRIDING SYSTEM VALUE" for IDENTITY columns marked as GENERATED ALWAYS.
      select count(*) into cnt2 from pg_class c, pg_attribute a, pg_namespace n
          -- Issue#140
          -- where a.attrelid = c.oid and c.relname = quote_ident(tblname) and n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and a.attidentity = 'a';
          where a.attrelid = c.oid and c.relname = quote_ident(tblname) and n.oid = c.relnamespace and n.nspname = source_schema and a.attidentity = 'a';
      buffer3 := '';
      IF cnt2 > 0 THEN
          buffer3 := ' OVERRIDING SYSTEM VALUE';
      END IF;
      -- BUG for inserting rows from tables with user-defined columns
      -- INSERT INTO sample_clone.address OVERRIDING SYSTEM VALUE SELECT * FROM sample.address;
      -- ERROR:  column "id2" is of type sample_clone.udt_myint but expression is of type udt_myint
      
      -- Issue#86 fix:
      -- IF data_type = 'USER-DEFINED' THEN
      IF bDebug THEN RAISE NOTICE 'DEBUG: includerecs branch  table=%  data_type=%  isgenerated=%  buffer3=%', tblname, data_type, isGenerated, buffer3; END IF;
      
      IF data_type = 'USER-DEFINED' OR isGenerated = 'ALWAYS' THEN
        -- RAISE WARNING 'Bypassing copying rows for table (%) with user-defined data types.  You must copy them manually.', tblname;
        -- wont work --> INSERT INTO clone1.address (id2, id3, addr) SELECT cast(id2 as clone1.udt_myint), cast(id3 as clone1.udt_myint), addr FROM sample.address;
        -- Issue#101 --> INSERT INTO clone1.address2 (id2, id3, addr) SELECT id2::text::clone1.udt_myint, id3::text::clone1.udt_myint, addr FROM sample.address; 

        -- Issue#79 implementation follows        
        -- COPY sample.statuses(id, s) TO '/tmp/statuses.txt' WITH DELIMITER AS ',';
        -- COPY sample_clone1.statuses FROM '/tmp/statuses.txt' (DELIMITER ',', NULL '');
        -- Issue#101 fix: use text cast to get around the problem.
        IF bFileCopy THEN
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
          IF bDebug THEN RAISE NOTICE 'DEBUG: Deferring file copy to end:%', buffer2; END IF;
        ELSE
          -- Issue#101: assume direct copy with text cast, add to separate array
          -- Issue#140
          -- SELECT * INTO buffer3 FROM public.get_insert_stmt_ddl(quote_ident(source_schema), quote_ident(dest_schema), quote_ident(tblname), True);
          SELECT * INTO buffer3 FROM public.get_insert_stmt_ddl(source_schema, dest_schema, quote_ident(tblname), True);
          
          -- Issue#140 check for invalid statement
          IF buffer3 = '' THEN
              RAISE EXCEPTION 'Programming Error: 1 get_insert_stmt_ddl() failed. See previous errors/warnings.';
          END IF;

          tblarray3 := tblarray3 || buffer3;
          IF bDebug THEN RAISE NOTICE 'DEBUG: Deferring complex insert to end:%', buffer3; END IF;
        END IF;
      ELSE
        -- bypass child tables since we populate them when we populate the parents
        IF bDebug THEN RAISE NOTICE 'DEBUG: tblname=%  bRelispart=%  relknd=%  l_child=%  bChild=%', tblname, bRelispart, relknd, l_child, bChild; END IF;
        IF NOT bRelispart AND NOT bChild THEN
          -- Issue#75: Must defer population of tables until child tables have been added to parents
          -- Issue#101 Offer alternative of copy to/from file. Although originally intended for tables with UDTs, it is now expanded to handle all cases for performance improvement perhaps for large tables.
          -- Issue#106 buffer3 shouldnt be in the mix
          -- revisited:  buffer3 should be in play for PG versions that handle IDENTITIES
          buffer2 := 'INSERT INTO ' || buffer || buffer3 || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ';';
          -- buffer2 := 'INSERT INTO ' || buffer || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ';';
          IF bDebug THEN RAISE NOTICE 'DEBUG: Deferring normal insert=%',buffer2; END IF;
          IF bFileCopy THEN
            tblarray2:= tblarray2 || buffer2;
          ELSE
            tblarray := tblarray || buffer2;
          END IF;
        END IF;
      END IF;
    END IF;

    -- Issue#61 FIX: use set_config for empty string
    -- SET search_path = '';
    -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
    SELECT set_config('search_path', '', true) into v_dummy;
    -- RAISE WARNING 'DEBUGGGG: setting search_path to empty string:%', v_dummy;

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
      IF bDDLOnly THEN
        -- May need to come back and revisit this since previous sql will not return anything since no schema as created!
        -- Issue#150 defer to later...
        -- RAISE INFO '%', buffer2;
        IF bDDLOnly THEN
            DDLAltCol = DDLAltCol || buffer2;
        ELSE
            RAISE INFO '%', buffer2;
        END IF;
      ELSE
        lastsql = buffer2;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    END LOOP;
    
    EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
    -- RAISE WARNING 'DEBUGGGG: search_path changed back to source schema:%', quote_ident(source_schema); 
  END LOOP;
  ELSE 
  -- Handle 9.6 versions 90600
  FOR tblname, relpersist, relknd, data_type, udt_name, udt_schema, ocomment, l_child, isGenerated, tblowner, tblspace  IN
    -- 2021-03-08 MJV #39 fix: change sql to get indicator of user-defined columns to issue warnings
    -- select c.relname, c.relpersistence, c.relispartition, c.relkind
    -- FROM pg_class c, pg_namespace n where n.oid = c.relnamespace and n.nspname = quote_ident(source_schema) and c.relkind in ('r','p') and
    -- order by c.relkind desc, c.relname
    --Fix#65 add another left join to distinguish child tables by inheritance
    -- Fix#86 add is_generated to column select
    -- Fix#91 add tblowner to the select
    -- Fix#105 need a different kinda distint to avoid retrieving a table twice in the case of a table with multiple USER-DEFINED datatypes using DISTINCT ON instead of just DISTINCT
    -- Fixed Issue#108: double quote roles to avoid problems with special characters in OWNER TO statements
    --SELECT DISTINCT c.relname, c.relpersistence, c.relispartition, c.relkind, co.data_type, co.udt_name, co.udt_schema, obj_description(c.oid), i.inhrelid, 
    --                COALESCE(co.is_generated, ''), pg_catalog.pg_get_userbyid(c.relowner) as "Owner", CASE WHEN reltablespace = 0 THEN 'pg_default' ELSE ts.spcname END as tablespace
    -- SELECT DISTINCT ON (c.relname, c.relpersistence, c.relkind, co.data_type) c.relname, c.relpersistence, c.relkind, co.data_type, co.udt_name, co.udt_schema, obj_description(c.oid), i.inhrelid, 
    --                 COALESCE(co.is_generated, ''), pg_catalog.pg_get_userbyid(c.relowner) as "Owner", CASE WHEN reltablespace = 0 THEN 'pg_default' ELSE ts.spcname END as tablespace                    
    SELECT DISTINCT ON (c.relname, c.relpersistence, c.relkind, co.data_type) c.relname, c.relpersistence, c.relkind, co.data_type, co.udt_name, co.udt_schema, obj_description(c.oid), i.inhrelid, 
                    COALESCE(co.is_generated, ''), '"' || pg_catalog.pg_get_userbyid(c.relowner) || '"' as "Owner", CASE WHEN reltablespace = 0 THEN 'pg_default' ELSE ts.spcname END as tablespace                    
    FROM pg_class c
        JOIN pg_namespace n ON (n.oid = c.relnamespace
                AND n.nspname = quote_ident(source_schema)
                AND c.relkind IN ('r', 'p'))
        LEFT JOIN information_schema.columns co ON (co.table_schema = n.nspname
                AND co.table_name = c.relname
                AND (co.data_type = 'USER-DEFINED' OR co.is_generated = 'ALWAYS'))
        LEFT JOIN pg_inherits i ON (c.oid = i.inhrelid) 
        -- issue#99 added join
        LEFT JOIN pg_tablespace ts ON (c.reltablespace = ts.oid) 
    ORDER BY c.relkind DESC, c.relname
  LOOP
    cntables := cntables + 1;
    IF l_child IS NULL THEN
      bChild := False;
    ELSE
      bChild := True;
    END IF;
    IF bDebug THEN RAISE NOTICE 'DEBUG: TABLE START(2) --> table=%  bRelispart=NA  relkind=%  bChild=%',tblname, relknd, bChild; END IF;

    IF data_type = 'USER-DEFINED' THEN
      -- RAISE NOTICE ' Table (%) has column(s) with user-defined types so using get_table_ddl() instead of CREATE TABLE LIKE construct.',tblname;
      cntables :=cntables;
    END IF;
    buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);
    buffer2 := '';
    IF relpersist = 'u' THEN
      buffer2 := 'UNLOGGED ';
    END IF;
    IF relknd = 'r' THEN
      IF bDDLOnly THEN
        IF data_type = 'USER-DEFINED' THEN
          -- FIXED #65, #67
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
          -- FIX: #121 Use pg_get_tabledef instead
          -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
          -- Issue#140 remove quote_ident!
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
          SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- Issue#150 : Add INFO lines if we are in DDLONLY mode
			    IF bDDLOnly THEN
    	        buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
			    		buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
			    END IF;
          RAISE INFO '%', buffer3;
          
          -- issue#91 fix
          -- issue#95
          IF NOT bNoOwner THEN    
            -- Fixed Issue#108: double-quote roles in case they have special characters
            -- Issue#150: Handle case-sensitive tables
            -- RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || tblname, tblowner;
            -- Issue#150: defer if child
            IF bChild THEN
                v_dummy = 'INFO:  ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner || ';';
                DDLAltTblDefer := DDLAltTblDefer || v_dummy;
            ELSE
                RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
            END IF;
          END IF;
        ELSE
          IF NOT bChild THEN
            RAISE INFO '%', 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL);';
            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN    
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Issue#150: Handle case-sensitive tables and defer if child and in DDLONLY mode
              -- RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || tblname, tblowner;
              IF bChild THEN
                  v_dummy = 'INFO:  ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner || ';';
                  DDLAltTblDefer := DDLAltTblDefer || v_dummy;
              ELSE
                  RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
              END IF;
            END IF;
            
            -- issue#99 
            IF tblspace <> 'pg_default' THEN
              -- replace with user-defined tablespace
              -- ALTER TABLE myschema.mytable SET TABLESPACE usrtblspc;
              -- Issue#150: Handle case-sensitive tables and defer if DDLONLY mode
              -- RAISE INFO 'ALTER TABLE IF EXISTS % SET TABLESPACE %;', quote_ident(dest_schema) || '.' || tblname, tblspace;
              RAISE INFO 'ALTER TABLE IF EXISTS % SET TABLESPACE %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblspace;
            END IF;
          ELSE
            -- FIXED #65, #67
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
            -- FIX: #121 Use pg_get_tabledef instead
            -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
            -- Issue#140 remove quote_ident!
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
            SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
            buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
            -- Issue#150 : Add INFO lines if we are in DDLONLY mode
			      buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
			  		buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
            RAISE INFO '%', buffer3;

            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN    
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Issue#150: Handle case-sensitive tables and defer if DDLONLY mode
              -- RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || tblname, tblowner;
	            IF bChild THEN
	                v_dummy = 'INFO:  ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;    
                  DDLAltTblDefer := DDLAltTblDefer || v_dummy;
              ELSE
	                RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
              END IF;
            END IF;
          END IF;
        END IF;
      ELSE
        IF data_type = 'USER-DEFINED' THEN
          -- FIXED #65, #67
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
          -- FIX: #121 Use pg_get_tabledef instead
          -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
          -- Issue#140 remove quote_ident!
          -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
          SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
          buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- Issue#150 : Add INFO lines if we are in DDLONLY mode
			    IF bDDLOnly THEN
    	        buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
			    		buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
			    END IF;
          IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef01b:%', buffer3; END IF;
          
          -- #82: Table def should be fully qualified with target schema, 
          --      so just make search path = public to handle extension types that should reside in public schema
          v_dummy = 'public';
          -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
          SELECT set_config('search_path', v_dummy, true) into v_dummy;
          -- RAISE WARNING 'DEBUGGGG: search_path changed to public:%', v_dummy; 
          lastsql = buffer3;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
          -- issue#91 fix
          -- issue#95
          IF NOT bNoOwner THEN    
            -- Fixed Issue#108: double-quote roles in case they have special characters
            -- Issue#150: Handle case-sensitive tables
            -- lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || tblname || ' OWNER TO ' || tblowner;
            lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
          END IF;
        ELSE
          IF (NOT bChild) THEN
            lastsql := 'CREATE ' || buffer2 || 'TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ' INCLUDING ALL)';
            IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef02:%', lastsql; END IF;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN    
              -- Fixed Issue#108: double-quote roles in case they have special characters
              lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.'  || quote_ident(tblname) || ' OWNER TO ' || tblowner;
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
            END IF;
            
            -- issue#99
            IF tblspace <> 'pg_default' THEN
              -- replace with user-defined tablespace
              -- ALTER TABLE myschema.mytable SET TABLESPACE usrtblspc;
              -- Issue#150: Handle case-sensitive tables
              -- lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || tblname || ' SET TABLESPACE ' || tblspace;
              lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' SET TABLESPACE ' || tblspace;
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
            END IF;

          ELSE
            -- FIXED #65, #67
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname);
           
            -- FIX: #121 Use pg_get_tabledef instead
            -- SELECT * INTO buffer3 FROM public.get_table_ddl(quote_ident(source_schema), tblname, False);
            -- Issue#140 remove quote_ident!
            -- SELECT * INTO buffer3 FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
            SELECT * INTO buffer3 FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
            buffer3 := REPLACE(buffer3, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
            -- Issue#150 : Add INFO lines if we are in DDLONLY mode
			      IF bDDLOnly THEN
    	          buffer3 := REPLACE(buffer3, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
			      		buffer3 := REPLACE(buffer3, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
			      END IF;

            -- set client_min_messages higher to avoid messages like this:
            -- NOTICE:  merging column "city_id" with inherited definition
            set client_min_messages = 'WARNING';
            IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef03:%', buffer3; END IF;
            lastsql = buffer3;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
            -- issue#91 fix
            -- issue#95
            IF NOT bNoOwner THEN
              -- Fixed Issue#108: double-quote roles in case they have special characters
              -- Issue#150: Handle case-sensitive tables
              -- lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || tblname || ' OWNER TO ' || tblowner;
              lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
            END IF;

            -- reset it back, only get these for inheritance-based tables
            set client_min_messages = 'notice';
          END IF;
        END IF;
        -- Add table comment.
        IF ocomment IS NOT NULL THEN
          lastsql = 'COMMENT ON TABLE ' || buffer || ' IS ' || quote_literal(ocomment); 
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
        END IF;
      END IF;
    ELSIF relknd = 'p' THEN
      -- define parent table and assume child tables have already been created based on top level sort order.
      -- Issue #103 Put the complex query into its own function, get_table_ddl_complex()
      
      -- FIX: #121 Use pg_get_tabledef instead
      -- SELECT * INTO qry FROM public.get_table_ddl_complex(source_schema, dest_schema, tblname, sq_server_version_num);
      -- Issue#140 remove quote_ident!
      -- SELECT * INTO qry FROM public.pg_get_tabledef(quote_ident(source_schema), tblname, bDebug, 'FKEYS_NONE');                      
      SELECT * INTO qry FROM public.pg_get_tabledef(source_schema, tblname, false, 'FKEYS_NONE');                      
      qry := REPLACE(qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
          -- Issue#150 : Add INFO lines if we are in DDLONLY mode
			    IF bDDLOnly THEN
    	        qry := REPLACE(qry, 'CREATE UNIQUE INDEX IF NOT EXISTS', 'INFO:  CREATE UNIQUE INDEX IF NOT EXISTS');
			    		qry := REPLACE(qry, 'CREATE INDEX IF NOT EXISTS', 'INFO:  CREATE INDEX IF NOT EXISTS');
			    END IF;
      IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef04 - %', buffer; END IF;
      
      IF bDDLOnly THEN
        RAISE INFO '%', qry;
        -- issue#95
        IF NOT bNoOwner THEN
            -- Fixed Issue#108: double-quote roles in case they have special characters
            RAISE INFO 'ALTER TABLE IF EXISTS % OWNER TO %;', quote_ident(dest_schema) || '.' || quote_ident(tblname), tblowner;
        END IF;
      ELSE
        -- Issue#103: we need to always set search_path priority to target schema when we execute DDL
        IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef04 context: old search path=%  new search path=% current search path=%', v_src_path_old, v_src_path_new, v_dummy; END IF;
        SELECT setting INTO spath_tmp FROM pg_settings WHERE name = 'search_path';   
        IF spath_tmp <> dest_schema THEN
          -- change it to target schema and don't forget to change it back after we execute the DDL
          spath = 'SET search_path = "' || dest_schema || '"';
          -- RAISE WARNING 'DEBUGGGG: changing search_path --> %', spath;
          EXECUTE spath;
          SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';   
          -- RAISE WARNING 'DEBUGGGG: search_path changed to %', v_dummy; 
        END IF;
        IF bDebug or bDebugExec THEN RAISE NOTICE 'DEBUG: tabledef04:%', qry; END IF;
        lastsql = qry;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        EXECUTE lastsql;
        lastsql = '';
        
        -- Issue#103
        -- Set search path back to what it was
        spath = 'SET search_path = "' || spath_tmp || '"';
        -- RAISE WARNING 'DEBUGGGG: search_path changed back to:%', spath_tmp; 
        EXECUTE spath;
        SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';   
        -- RAISE WARNING 'DEBUGGGG: search_path changed back to %', v_dummy; 
        
        -- issue#91 fix
        -- issue#95
        IF NOT bNoOwner THEN
          -- Fixed Issue#108: double-quote roles in case they have special characters
          lastsql = 'ALTER TABLE IF EXISTS ' || quote_ident(dest_schema) || '.' || quote_ident(tblname) || ' OWNER TO ' || tblowner;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
        END IF;
        
      END IF;
      -- loop for child tables and alter them to attach to parent for specific partition method.
      -- Issue#103 fix: only loop for the table we are currently processing, tblname!
      FOR aname, part_range, object IN
        SELECT quote_ident(dest_schema) || '.' || c1.relname as tablename, pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) as partrange, quote_ident(dest_schema) || '.' || c2.relname as object
        FROM pg_catalog.pg_class c1, pg_namespace n, pg_catalog.pg_inherits i, pg_class c2
        WHERE n.nspname = quote_ident(source_schema) AND c1.relnamespace = n.oid AND c1.relkind = 'r' 
        -- Issue#103: added this condition to only work on current partitioned table.  The problem was regression testing previously only worked on one partition table clone case
        AND c2.relname = tblname AND 
        c1.relispartition AND c1.oid=i.inhrelid AND i.inhparent = c2.oid AND c2.relnamespace = n.oid ORDER BY pg_catalog.pg_get_expr(c1.relpartbound, c1.oid) = 'DEFAULT',
        c1.oid::pg_catalog.regclass::pg_catalog.text
      LOOP
        qry := 'ALTER TABLE ONLY ' || object || ' ATTACH PARTITION ' || aname || ' ' || part_range || ';';
        IF bDebug THEN RAISE NOTICE 'DEBUG: %',qry; END IF;
        -- issue#91, not sure if we need to do this for child tables
        -- issue#95 we dont set ownership here
        -- Issue#150: defer attaching children to parents if in DDLONLY mode
        IF bDDLOnly THEN
          DDLAttachDefer = DDLAttachDefer || qry;
          IF NOT bNoOwner THEN
            NULL;
          END IF;
        ELSE
          lastsql = qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
          IF NOT bNoOwner THEN
            NULL;
          END IF;
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
      lastsql = '';
      -- Issue#133: We never get here when DDLONLY is specified since it depends on the cloned schema being created, so ALTER INDEX action does not happen on DDLONLY commands      
      IF bDDLOnly THEN
        RAISE INFO '%', 'ALTER INDEX ' || quote_ident(dest_schema) || '.'  || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';';
      ELSE
        -- The SELECT query above may return duplicate names when a column is indexed twice the same manner with 2 different names. Therefore, to
        -- avoid a 'relation "xxx" already exists' we test if the index name is in use or free. Skipping existing index will fallback on unused
        -- ones and every duplicate will be mapped to distinct old names.
        -- Issue#133: index names may be different when the table is created with the LIKE... INCLUDING ALL construct, so change the name to what is was in the original for non-unique indexes and primary keys at the present time
        --  IF NOT EXISTS (
        --     SELECT TRUE
        --     FROM pg_indexes
        --     WHERE schemaname = dest_schema
        --       AND tablename = tblname
        --       AND indexname = quote_ident(ix_old_name))
        --   AND EXISTS (
        --     SELECT TRUE
        --     FROM pg_indexes
        --     WHERE schemaname = dest_schema
        --       AND tablename = tblname
        --       AND indexname = quote_ident(ix_new_name))
        --   THEN
        -- RAISE NOTICE 'AAAA: schema=%  table=%  oldixname=%  newixname=%',quote_ident(source_schema), tblname, ix_old_name, ix_new_name;
        -- Issue#133: bypass unique keys
        -- IF NOT EXISTS (SELECT TRUE FROM pg_class c, pg_constraint ct WHERE ct.conrelid = c.oid AND c.relnamespace::regnamespace::text = quote_ident(source_schema) AND c.relname = tblname AND ct.contype IN ('p', 'u') AND ct.conname = ix_old_name) 
        IF NOT EXISTS (SELECT TRUE FROM pg_class c, pg_constraint ct WHERE ct.conrelid = c.oid AND c.relnamespace::regnamespace::text = quote_ident(source_schema) AND c.relname = tblname AND ct.contype IN ('u') AND ct.conname = ix_old_name)         
				THEN
				  -- Issue#133: bypass columns we can't find in new schema probably due to CREATE TABLE LIKE constructs where fabricated index names are created automatically.
	        SELECT count(*) INTO cnt FROM pg_indexes WHERE schemaname = quote_ident(dest_schema) AND tablename = tblname AND indexname =  ix_new_name AND ix_old_name <> ix_new_name AND NOT EXISTS (SELECT TRUE FROM pg_indexes 
	        WHERE schemaname = quote_ident(dest_schema) AND tablename = tblname AND indexname =  ix_old_name);
	        IF cnt > 0 THEN
              lastsql = 'ALTER INDEX ' || quote_ident(dest_schema) || '.' || quote_ident(ix_new_name) || ' RENAME TO ' || quote_ident(ix_old_name) || ';'; 
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
              EXECUTE lastsql;
              lastsql = '';
          ELSE
              IF bDebugExec THEN RAISE NOTICE 'EXEC: bypassing(2a) altering index from % TO % for table, %', ix_new_name, ix_old_name, tblname; END IF;   
          END IF;
        ELSE
          IF bDebugExec THEN RAISE NOTICE 'EXEC: bypassing(2b) altering index from % TO % for table, %', ix_new_name, ix_old_name, tblname; END IF;   
        END IF;
      END IF;
    END LOOP;

    IF bData THEN
      -- Insert records from source table

      -- 2021-03-03  MJV FIX
      -- Issue#140
      -- buffer := dest_schema || '.' || quote_ident(tblname);
      buffer := quote_ident(dest_schema) || '.' || quote_ident(tblname);
      
      -- Issue#86 fix:
      -- IF data_type = 'USER-DEFINED' THEN
      IF bDebug THEN RAISE NOTICE 'DEBUG: includerecs branch  table=%  data_type=%  isgenerated=%', tblname, data_type, isGenerated; END IF;
      
      IF data_type = 'USER-DEFINED' OR isGenerated = 'ALWAYS' THEN
        -- RAISE WARNING 'Bypassing copying rows for table (%) with user-defined data types.  You must copy them manually.', tblname;
        -- wont work --> INSERT INTO clone1.address (id2, id3, addr) SELECT cast(id2 as clone1.udt_myint), cast(id3 as clone1.udt_myint), addr FROM sample.address;
        -- Issue#101 --> INSERT INTO clone1.address2 (id2, id3, addr) SELECT id2::text::clone1.udt_myint, id3::text::clone1.udt_myint, addr FROM sample.address; 

        -- Issue#79 implementation follows        
        -- COPY sample.statuses(id, s) TO '/tmp/statuses.txt' WITH DELIMITER AS ',';
        -- COPY sample_clone1.statuses FROM '/tmp/statuses.txt' (DELIMITER ',', NULL '');
        -- Issue#101 fix: use text cast to get around the problem.
        IF bFileCopy THEN
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
          -- Issue#101: assume direct copy with text cast, add to separate array
          -- Issue#140
          -- SELECT * INTO buffer3 FROM public.get_insert_stmt_ddl(quote_ident(source_schema), quote_ident(dest_schema), quote_ident(tblname), True);
          SELECT * INTO buffer3 FROM public.get_insert_stmt_ddl(source_schema, dest_schema, quote_ident(tblname), True);

          -- Issue#140 check for invalid statement
          IF buffer3 = '' THEN
             RAISE EXCEPTION 'Programming Error: 2 get_insert_stmt_ddl() failed. See previous errors/warnings.';
          END IF;
          
          tblarray3 := tblarray3 || buffer3;
        END IF;
      ELSE
        -- bypass child tables since we populate them when we populate the parents
        IF bDebug THEN RAISE NOTICE 'DEBUG: tblname=%  bRelispart=NA relknd=%  l_child=%  bChild=%', tblname, relknd, l_child, bChild; END IF;

        IF NOT bChild THEN
          -- Issue#75: Must defer population of tables until child tables have been added to parents
          -- Issue#101 Offer alternative of copy to/from file. Although originally intended for tables with UDTs, it is now expanded to handle all cases for performance improvement perhaps for large tables.
          -- buffer2 := 'INSERT INTO ' || buffer || buffer3 || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ';';
          buffer2 := 'INSERT INTO ' || buffer || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(tblname) || ';';
          IF bDebug THEN RAISE NOTICE 'DEBUG: buffer2=%',buffer2; END IF;
          IF bFileCopy THEN
            tblarray2:= tblarray2 || buffer2;
          ELSE
            tblarray := tblarray || buffer2;
          END IF;
        END IF;
      END IF;
    END IF;
   
    -- Issue#61 FIX: use set_config for empty string
    -- SET search_path = '';
    -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
    SELECT set_config('search_path', '', true) into v_dummy;
    -- RAISE WARNING 'DEBUGGGG: search_path changed to empty string:%', v_dummy;

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
      -- Issue#150: defer to later
      IF bDDLOnly THEN
        -- RAISE INFO '%', buffer2;      
        DDLAltCol = DDLAltCol || buffer2;
      ELSE
        lastsql = buffer2;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    END LOOP;
    
    EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
    -- RAISE WARNING 'DEBUGGGG: search_path changed back to source schema:%', quote_ident(source_schema); 
  END LOOP;      
  END IF;
  -- end of 90600 branch

  IF bDDLOnly THEN
      -- Issue#150 process the deferred DDL statements when in DDLONLY mode
      IF bDebug OR bDebugExec THEN RAISE NOTICE 'Processing deferred DDLONLY statements for Create child/Index...'; END IF;
      FOREACH tblelement IN ARRAY DDLCreateIXDefer
      LOOP
          RAISE INFO '%',tblelement;    
      END LOOP;

      -- Issue#150 process the deferred DDL statements when in DDLONLY mode
      IF bDebug OR bDebugExec THEN RAISE NOTICE 'Processing deferred DDLONLY statements for ALTER COLUMN...DEFAULTS'; END IF;
      FOREACH tblelement IN ARRAY DDLAltCol
      LOOP
          RAISE INFO '%',tblelement;    
      END LOOP;

      -- Issue#150 process the deferred DDL statements when in DDLONLY mode
      IF bDebug OR bDebugExec THEN RAISE NOTICE 'Processing deferred DDLONLY statements for Alter Table...'; END IF;
      FOREACH tblelement IN ARRAY DDLAltTblDefer
      LOOP 
          RAISE INFO '%',tblelement;    
      END LOOP;

      -- Issue#150 process the deferred DDL statements when in DDLONLY mode
      IF bDebug OR bDebugExec THEN RAISE NOTICE 'Processing deferred DDLONLY statements for Attaching children to parents...'; END IF;
      FOREACH tblelement IN ARRAY DDLAttachDefer
      LOOP 
          bFound = False;
          FOREACH tblelement2 IN ARRAY DDLAttachSkip
          LOOP
              SELECT POSITION(tblelement2 IN tblelement) INTO cnt;
              IF cnt > 0 THEN
                  -- RAISE NOTICE 'Skipping %', tblelement;
                  bFound = True;
              END IF;
          END LOOP;
          IF NOT bFound THEN          
              RAISE INFO '%',tblelement;    
          END IF;
      END LOOP;
  END IF;
    
  RAISE NOTICE '      TABLES cloned: %', LPAD(cntables::text, 5, ' ');


  SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';
  -- RAISE WARNING 'DEBUGGGG: current search_path=%', v_dummy; 

  -- Issue#140 section removed since handled above
  -- Assigning sequences to table columns.
  -- action := 'Sequences assigning';
  -- rc = 26;
  -- former looping here
  -- RAISE NOTICE '    SEQUENCES set:   %', LPAD(seqcnt::text, 5, ' ');

  -- Setting identities
  -- Update IDENTITY sequences to the last value, bypass 9.6 versions
  -- NOTE: the IDENTITY SETS do not always add up to the number if IDENTITY columns.  It depends if the identity column table was ever incrememented.
  IF sq_server_version_num > 90624 THEN
      action := 'Identity updating';
      rc = 27;
      IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
      cnt := 0;
      setcnt := 0;
      -- NOTE: we can infer an identity type sequence if it is in the pg_sequences table, but not the information_schema.sequences table.
      FOR object, sq_last_value IN
        -- Isssue#140
        -- SELECT sequencename::text, COALESCE(last_value, -999) from pg_sequences where schemaname = quote_ident(source_schema)
        SELECT sequencename::text, COALESCE(last_value, -999) from pg_sequences where schemaname = source_schema
        AND NOT EXISTS
        -- Isssue#140
        -- (select 1 from information_schema.sequences where sequence_schema = quote_ident(source_schema) and sequence_name = sequencename)
        (select 1 from information_schema.sequences where sequence_schema = source_schema and sequence_name = sequencename)
      LOOP      
        cnt := cnt + 1;
        IF sq_last_value = -999 THEN
          -- identity not used yet.  Either table has never had data OR data inserted bypassing incrementing the identity (OVERRIDING syntax).
          continue;
        END IF;
        setcnt := setcnt + 1;
        buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
        IF bData THEN
          lastsql = 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ; 
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        ELSE
          if bDDLOnly THEN
            -- fix#63
            RAISE INFO '%', 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
          ELSE
            -- fix#63
            lastsql = 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ; 
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
          END IF;
        END IF;
      END LOOP;
      -- Fixed Issue#107: set lpad from 2 to 5
      RAISE NOTICE '   IDENTITIES set:   %', LPAD(setcnt::text, 5, ' ');
  ELSE
    -- Fixed Issue#107: set lpad from 2 to 5
    RAISE NOTICE '   IDENTITIES set:   %', LPAD('-1'::text, 5, ' ');    
  END IF;

  -- Issue#78 forces us to defer FKeys until the end since we previously did row copies before FKeys
  --  add FK constraint
  -- action := 'FK Constraints';
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  -- Issue#62: Add comments on indexes, and then removed them from here and reworked later below.

  -- Issue 90: moved functions to here, before views or MVs that might use them
  -- Create functions
    action := 'Functions';
    rc = 28;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    cnt := 0;
    -- MJV FIX per issue# 34
    -- SET search_path = '';
    -- Issue#126: concatenate public with the source schema to pick up public stuff...
    -- EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
    spath_tmp = 'SET search_path = ' || quote_ident(source_schema) || ', public';    
    EXECUTE spath_tmp;
    SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';
    -- RAISE WARNING 'DEBUGGGG: search_path changed to source schema + public:%', v_dummy; 

    -- Fixed Issue#65
    -- Fixed Issue#97
    -- FOR func_oid IN SELECT oid FROM pg_proc WHERE pronamespace = src_oid AND prokind != 'a'
    IF is_prokind THEN
      FOR func_oid, func_owner, func_name, func_args, func_argno, buffer3 IN 
          SELECT p.oid, pg_catalog.pg_get_userbyid(p.proowner), p.proname, oidvectortypes(p.proargtypes), p.pronargs,
          CASE WHEN prokind = 'p' THEN 'PROCEDURE' WHEN prokind = 'f' THEN 'FUNCTION' ELSE '' END 
          FROM pg_proc p WHERE p.pronamespace = src_oid AND p.prokind != 'a'          
      LOOP
        cnt := cnt + 1;
        SELECT pg_get_functiondef(func_oid)
        INTO qry;
  
        SELECT replace(qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO dest_qry;
        IF bDDLOnly THEN
          RAISE INFO '%;', dest_qry;
          -- Issue#91 Fix
          -- issue#95 
          IF NOT bNoOwner THEN
            IF func_argno = 0 THEN
                -- Fixed Issue#108: double-quote roles in case they have special characters
                RAISE INFO 'ALTER % %() OWNER TO %', buffer3, quote_ident(dest_schema) || '.' || quote_ident(func_name), '"' || func_owner || '";';
            ELSE
                -- Fixed Issue#108: double-quote roles in case they have special characters
                RAISE INFO 'ALTER % % OWNER TO %', buffer3, quote_ident(dest_schema) || '.' || quote_ident(func_name) || '(' || func_args || ')', '"' || func_owner || '";';
            END IF;
          END IF;
        ELSE
          IF bDebug THEN RAISE NOTICE 'DEBUG: %', dest_qry; END IF;
          lastsql = dest_qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';

          -- Issue#91 Fix
          -- issue#95 
          IF NOT bNoOwner THEN
            IF func_argno = 0 THEN
                -- Fixed Issue#108: double-quote roles in case they have special characters
                dest_qry = 'ALTER ' || buffer3 || ' ' || quote_ident(dest_schema) || '.' || quote_ident(func_name) || '() OWNER TO ' || '"' || func_owner || '";';
            ELSE
                -- Fixed Issue#108: double-quote roles in case they have special characters
                dest_qry = 'ALTER ' || buffer3 || ' ' || quote_ident(dest_schema) || '.' || quote_ident(func_name) || '(' || func_args || ') OWNER TO ' || '"' || func_owner || '";';
            END IF;
          END IF;
          lastsql = dest_qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
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
        IF bDDLOnly THEN
          RAISE INFO '%;', dest_qry;
        ELSE
          lastsql = dest_qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
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
          -- Issue#140
          -- || dest_schema
          || quote_ident(dest_schema)
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
  
        IF bDDLOnly THEN
          RAISE INFO '%;', dest_qry;
        ELSE
          lastsql = dest_qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
  
      END LOOP;
      RAISE NOTICE '   FUNCTIONS cloned: %', LPAD(cnt::text, 5, ' ');
  
    ELSE
      FOR func_oid IN SELECT oid FROM pg_proc WHERE pronamespace = src_oid AND proisagg
      LOOP
        cnt := cnt + 1;
        SELECT
          'CREATE AGGREGATE '
          -- Issue#140
          -- || dest_schema
          || quote_ident(dest_schema)
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
  
        IF bDDLOnly THEN
          RAISE INFO '%;', dest_qry;
        ELSE
          lastsql = dest_qry;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
        END IF;
  
      END LOOP;
      RAISE NOTICE '   FUNCTIONS cloned: %', LPAD(cnt::text, 5, ' ');
    END IF;
  
  -- Create views
  action := 'Views';
  rc = 29;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;

  -- Issue#61 FIX: use set_config for empty string
  -- MJV FIX #43: also had to reset search_path from source schema to empty.
  -- SET search_path = '';
  -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
  SELECT set_config('search_path', '', true)  INTO v_dummy;
  -- RAISE WARNING 'DEBUGGGG: search_path changed back to empty string:%', v_dummy; 

  cnt := 0;
  deferredviewcnt := 0;
  --FOR object IN
    -- SELECT table_name::text, view_definition
    -- FROM information_schema.views
    -- WHERE table_schema = quote_ident(source_schema)

  -- Issue#73 replace loop query to handle dependencies
  -- Issue#91 get view_owner
  FOR srctbl, aname, view_owner, object IN
    WITH RECURSIVE views AS (
       SELECT n.nspname as schemaname, v.relname as tablename, v.oid::regclass AS viewname,
              v.relkind = 'm' AS is_materialized, pg_catalog.pg_get_userbyid(v.relowner) as owner, 
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
         -- Issue#133 aded extra deptype
         -- AND d.deptype = 'n'
         AND d.deptype IN ('n', 'i')
    UNION
       -- add the views that depend on these
       SELECT n.nspname as schemaname, v.relname as tablename, v.oid::regclass AS viewname,
              v.relkind = 'm', pg_catalog.pg_get_userbyid(v.relowner) as owner, 
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
         -- Issue#133 aded extra deptype
         -- AND d.deptype = 'n'
         AND d.deptype IN ('n', 'i')
         AND v.oid <> views.viewname
    )
    SELECT tablename, viewname, owner, format('CREATE OR REPLACE%s VIEW %s AS%s',
                  CASE WHEN is_materialized
                       THEN ' MATERIALIZED'
                       ELSE ''
                  END,
                  viewname,
                  pg_get_viewdef(viewname))
    FROM views
    -- Issue#140
    -- WHERE schemaname = quote_ident(source_schema)
    WHERE quote_ident(schemaname) = quote_ident(source_schema)
    GROUP BY schemaname, tablename, viewname, owner, is_materialized
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
    SELECT REPLACE(aname, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO buffer3;
    
    -- Issue#133: Added logic to defer creation of views dependent on MVs.
    v_dummy = SUBSTRING(aname, POSITION('.' IN aname) + 1);
    WITH dependencies AS (SELECT distinct dependent_obj.relname, source_obj.relname FROM pg_depend
    JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
    JOIN pg_class as dependent_obj ON pg_rewrite.ev_class = dependent_obj.oid
    JOIN pg_class as source_obj ON pg_depend.refobjid = source_obj.oid
    JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_obj.relnamespace
    JOIN pg_namespace source_ns ON source_ns.oid = source_obj.relnamespace
    -- Issue#140
    -- WHERE source_ns.nspname = quote_ident(source_schema) AND dependent_ns.nspname = quote_ident(source_schema) 
    WHERE source_ns.nspname = source_schema AND dependent_ns.nspname = source_schema 
    AND dependent_obj.relname <> source_obj.relname AND dependent_obj.relkind in ('v') AND source_obj.relkind in ('m') AND dependent_obj.relname = v_dummy)
    SELECT count(*) into cnt2 FROM dependencies;
    IF bDebug THEN RAISE NOTICE 'dependent view count=% for view, %', cnt2, v_dummy; END IF;  
    IF cnt2 > 0 THEN
        -- defer view creation until after MVs are done
        deferredviews := deferredviews || v_def;
        deferredviewcnt = deferredviewcnt + 1;
        CONTINUE;
    END IF;
    
    IF bDDLOnly THEN
      RAISE INFO '%', v_def;
      -- Issue#91 Fix
      -- issue#95 
      IF NOT bNoOwner THEN
        -- Fixed Issue#108: double-quote roles in case they have special characters
        -- RAISE INFO 'ALTER TABLE % OWNER TO %', buffer3, view_owner || ';';
        RAISE INFO 'ALTER TABLE % OWNER TO %', buffer3, '"' ||view_owner || '";';
      END IF;        
    ELSE
      -- EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def;
      lastsql = v_def;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
      EXECUTE lastsql;
      lastsql = '';
      -- Issue#73: commented out comment logic for views since we do it elsewhere now.
      -- Issue#91 Fix
      -- issue#95 
      IF NOT bNoOwner THEN      
        -- Fixed Issue#108: double-quote roles in case they have special characters
        lastsql = 'ALTER TABLE ' || buffer3 || ' OWNER TO ' || '"' || view_owner || '";';
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    END IF;
  END LOOP;
  RAISE NOTICE '       VIEWS cloned: %', LPAD((cnt-deferredviewcnt)::text, 5, ' ');

  -- Create Materialized views
  action := 'Mat. Views';
  rc = 30;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  -- Issue#91 get view_owner
  FOR object, view_owner, v_def IN
      -- Issue#140
      -- SELECT matviewname::text, '"' || matviewowner::text || '"', replace(definition,';','') FROM pg_catalog.pg_matviews WHERE schemaname = quote_ident(source_schema)
      SELECT matviewname::text, '"' || matviewowner::text || '"', replace(definition,';','') FROM pg_catalog.pg_matviews WHERE schemaname = source_schema
  LOOP
      cnt := cnt + 1;
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on target schema and object
      buffer := quote_ident(dest_schema) || '.' || quote_ident(object);

      -- MJV FIX: #72 remove source schema in MV def
      SELECT REPLACE(v_def, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO buffer2;

      IF bData THEN
        -- issue#98 defer creation until after regular tables are populated. Also defer the ownership as well.
        -- EXECUTE 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH DATA;' ;
        IF bDebug THEN RAISE NOTICE 'DEBUG: Section=% deferring MV creation, %',action,buffer; END IF;
        buffer3 = 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH DATA;';
        mvarray := mvarray || buffer3;
        
        -- issue#95 
        IF NOT bNoOwner THEN      
          -- buffer3 = 'ALTER MATERIALIZED VIEW ' || buffer || ' OWNER TO ' || view_owner || ';' ;
          -- EXECUTE buffer3;
          -- Fixed Issue#108: double-quote roles in case they have special characters
          buffer3 = 'ALTER MATERIALIZED VIEW ' || buffer || ' OWNER TO ' || view_owner || ';' ;
          mvarray := mvarray || buffer3;
        END IF;
      ELSE
        IF bDDLOnly THEN
          RAISE INFO '%', 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH NO DATA;' ;
          -- Issue#91
          -- issue#95 
          IF NOT bNoOwner THEN      
            -- Fixed Issue#108: double-quote roles in case they have special characters
            RAISE INFO '%', 'ALTER MATERIALIZED VIEW ' || buffer || ' OWNER TO ' || view_owner || ';' ;
          END IF;
        ELSE
          lastsql = 'CREATE MATERIALIZED VIEW ' || buffer || ' AS ' || buffer2 || ' WITH NO DATA;' ; 
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
          EXECUTE lastsql;
          lastsql = '';
          -- Issue#91
          -- issue#95 
          IF NOT bNoOwner THEN      
            -- Fixed Issue#108: double-quote roles in case they have special characters
            lastsql = 'ALTER MATERIALIZED VIEW ' || buffer || ' OWNER TO ' || view_owner || ';' ;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
          END IF;
        END IF;
      END IF;
      SELECT coalesce(obj_description(oid), '') into adef from pg_class where relkind = 'm' and relname = object;
      IF adef <> '' THEN
        IF bDDLOnly THEN
          RAISE INFO '%', 'COMMENT ON MATERIALIZED VIEW ' || quote_ident(dest_schema) || '.' || object || ' IS ''' || adef || ''';';
        ELSE
          -- Issue#$98: also defer if copy rows is on since we defer MVIEWS in that case
          IF bData THEN
            buffer3 = 'COMMENT ON MATERIALIZED VIEW ' || quote_ident(dest_schema) || '.' || object || ' IS ''' || adef || ''';';
            mvarray = mvarray || buffer3;
          ELSE
            lastsql = 'COMMENT ON MATERIALIZED VIEW ' || quote_ident(dest_schema) || '.' || object || ' IS ''' || adef || ''';'; 
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;  
            EXECUTE lastsql;
            lastsql = '';
          END IF;
          
        END IF;
      END IF;

      FOR aname, adef IN
        SELECT indexname, replace(indexdef, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') as newdef FROM pg_indexes where schemaname = quote_ident(source_schema) and tablename = object order by indexname
      LOOP
        IF bDDLOnly THEN
          RAISE INFO '%', adef || ';';
        ELSE
          IF bData THEN
              -- #issue#116 defer materialized view index creations as well
              mvarray = mvarray || adef;  
          ELSE
              lastsql = adef || ';';
              IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
              EXECUTE lastsql;
              lastsql = '';
          END IF;        
        END IF;        
      END LOOP;

  END LOOP;
  RAISE NOTICE '   MAT VIEWS cloned: %', LPAD(cnt::text, 5, ' ');

  --Issue#133: create deferred views here since MVs they depend on are done now, but only if not in DATA mode where we do it after tables and MVs are created  
  IF NOT bData THEN
      action := 'Deferred Views';
      rc = 31;
      IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
      cnt = 0;
      FOREACH viewdef IN ARRAY deferredviews
        LOOP 
          cnt = cnt + 1;
          s = clock_timestamp();
          IF bDDLOnly THEN
            -- Issue#150: fixed bug
            -- RAISE INFO '%', v_def;
            RAISE INFO '%', viewdef;
          ELSE
            lastsql = viewdef;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
            EXECUTE lastsql;
            lastsql = '';
          END IF;
        END LOOP;
  RAISE NOTICE 'Deferrd VIEWS cloned:%', LPAD(cnt::text, 5, ' ');
  END IF;

  -- Issue 90 Move create functions to before views
  
  -- Issue#111: forces us to defer triggers til after we populate the tables, just like we did with FKeys (Issue#78).
  -- MV: Create Triggers
  -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
  SELECT set_config('search_path', '', true) into v_dummy;
  -- RAISE WARNING 'DEBUGGGG: search_path changed back to empty string:%', v_dummy; 

  -- MV: Create Rules
  -- Fixes Issue#59 Implement Rules
  action := 'Rules';
  rc = 32;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  FOR arec IN
    SELECT regexp_replace(definition, E'[\\n\\r]+', ' ', 'g' ) as definition
    FROM pg_rules
    -- Issue#140
    -- WHERE schemaname = quote_ident(source_schema)
    WHERE schemaname = source_schema
  LOOP
    cnt := cnt + 1;
    buffer := REPLACE(arec.definition, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.');
    IF bDDLOnly THEN
      RAISE INFO '%', buffer;
    ELSE
      lastsql = buffer;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
      EXECUTE buffer;
      lastsql = '';
    END IF;
  END LOOP;
  RAISE NOTICE '    RULES    cloned: %', LPAD(cnt::text, 5, ' ');


  -- MV: Create Policies
  -- Fixes Issue#66 Implement Security policies for RLS
  action := 'Policies';
  rc = 33;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  -- #106 Handle 9.6 which doesn't have "permissive"
  IF sq_server_version_num > 90624 THEN
    FOR arec IN
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on policy, tablename
      -- Issue#113 FIX: quote_ident() the policy name and handle case where qual is null (INSERT policies)
      -- SELECT schemaname as schemaname, tablename as tablename, 'CREATE POLICY ' || quote_ident(policyname) || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(tablename) || ' AS ' || permissive || ' FOR ' || cmd || ' TO '
      -- ||  array_to_string(roles, ',', '*') || ' USING (' || regexp_replace(qual, E'[\\n\\r]+', ' ', 'g' ) || ')'
      -- || CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' ELSE '' END || coalesce(with_check, '') || CASE WHEN with_check IS NOT NULL THEN ');' ELSE ';' END as definition
      -- FROM pg_policies WHERE schemaname = quote_ident(source_schema) ORDER BY policyname
      SELECT schemaname as schemaname, tablename as tablename, 'CREATE POLICY ' || quote_ident(policyname) || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(tablename) || ' AS ' || permissive || ' FOR ' || cmd || ' TO '
      ||  array_to_string(roles, ',', '*') || CASE WHEN qual is NULL THEN ' ' ELSE ' USING (' || regexp_replace(qual, E'[\\n\\r]+', ' ', 'g' )  || ')' END 
      || CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' ELSE '' END || coalesce(with_check, '') || CASE WHEN with_check IS NOT NULL THEN ');' ELSE ';' END as definition
      -- Issue#140
      -- FROM pg_policies WHERE schemaname = quote_ident(source_schema) ORDER BY policyname
      FROM pg_policies WHERE schemaname = source_schema ORDER BY policyname
    LOOP
      cnt := cnt + 1;
      IF bDDLOnly THEN
        RAISE INFO '%', arec.definition;
      ELSE
        IF bDebug THEN RAISE NOTICE 'DEBUG: policiesA - %', arec.definition; END IF;
        lastsql = arec.definition;
        IF bDebugExec THEN RAISE NOTICE 'EXEC3: %', lastsql; END IF;    
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    
      -- Issue#76: Enable row security if indicated
      -- Issue#140
      -- SELECT c.relrowsecurity INTO abool FROM pg_class c, pg_namespace n where n.nspname = quote_ident(arec.schemaname) AND n.oid = c.relnamespace AND c.relname = quote_ident(arec.tablename) and c.relkind = 'r';
      SELECT c.relrowsecurity INTO abool FROM pg_class c, pg_namespace n where n.nspname = arec.schemaname AND n.oid = c.relnamespace AND c.relname = quote_ident(arec.tablename) and c.relkind = 'r';
      IF abool THEN
        -- Issue#140
        -- lastsql = 'ALTER TABLE ' || dest_schema || '.' || arec.tablename || ' ENABLE ROW LEVEL SECURITY;';
        lastsql = 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || arec.tablename || ' ENABLE ROW LEVEL SECURITY;';
        IF bDDLOnly THEN
          RAISE INFO '%', lastsql;
          lastsql = '';
        ELSE
          IF bDebug THEN RAISE NOTICE 'DEBUG: policiesB - %', arec.definition; END IF;
          IF bDebugExec THEN RAISE NOTICE 'EXEC4: %', lastsql; END IF;    
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END IF;
    END LOOP;
  ELSE
    -- handle 9.6 versions
    FOR arec IN
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on policy, tablename
      -- Issue#113 FIX: quote_ident() the policy name and handle case where qual is null (INSERT policies)
      -- SELECT schemaname as schemaname, tablename as tablename, 'CREATE POLICY ' || policyname || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(tablename) || ' FOR ' || cmd || ' TO '
      -- ||  array_to_string(roles, ',', '*') || ' USING (' || regexp_replace(qual, E'[\\n\\r]+', ' ', 'g' ) || ')'
      -- || CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' ELSE '' END || coalesce(with_check, '') || CASE WHEN with_check IS NOT NULL THEN ');' ELSE ';' END as definition
      -- FROM pg_policies WHERE schemaname = quote_ident(source_schema) ORDER BY policyname
      SELECT schemaname as schemaname, tablename as tablename, 'CREATE POLICY ' || quote_ident(policyname) || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(tablename) || ' FOR ' || cmd || ' TO '
      ||  array_to_string(roles, ',', '*') || CASE WHEN qual is NULL THEN ' ' ELSE ' USING (' || regexp_replace(qual, E'[\\n\\r]+', ' ', 'g' )  || ')' END 
      || CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' ELSE '' END || coalesce(with_check, '') || CASE WHEN with_check IS NOT NULL THEN ');' ELSE ';' END as definition
      FROM pg_policies WHERE schemaname = quote_ident(source_schema) ORDER BY policyname
    LOOP
      cnt := cnt + 1;
      IF bDDLOnly THEN
        RAISE INFO '%', arec.definition;
      ELSE
        lastsql = arec.definition;
        IF bDebugExec THEN RAISE NOTICE 'EXEC1: %', lastsql; END IF;    
        EXECUTE lastsql;
        lastsql = '';
      END IF;
    
      -- Issue#76: Enable row security if indicated
      SELECT c.relrowsecurity INTO abool FROM pg_class c, pg_namespace n where n.nspname = quote_ident(arec.schemaname) AND n.oid = c.relnamespace AND c.relname = quote_ident(arec.tablename) and c.relkind = 'r';
      IF abool THEN
        -- Issue#140
        -- buffer = 'ALTER TABLE ' || dest_schema || '.' || arec.tablename || ' ENABLE ROW LEVEL SECURITY;';
        buffer = 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || arec.tablename || ' ENABLE ROW LEVEL SECURITY;';
        IF bDDLOnly THEN
          RAISE INFO '%', buffer;
        ELSE
          lastsql = buffer;
          IF bDebugExec THEN RAISE NOTICE 'EXEC2: %', lastsql; END IF;    
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END IF;
    END LOOP;  
  END IF;
  RAISE NOTICE '    POLICIES cloned: %', LPAD(cnt::text, 5, ' ');


  -- MJV Fixed #62 for comments (PASS 1)
  action := 'Comments1';
  rc = 34;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  FOR buffer, buffer2, qry IN
    -- Issue#74 Fix: Change schema from source to target. Also, do not include comments on foreign tables since we do not clone foreign tables at this time.
    SELECT c.relkind, c.relname, 'COMMENT ON ' || CASE WHEN c.relkind in ('r','p') AND a.attname IS NULL THEN 'TABLE ' WHEN c.relkind in ('r','p') AND
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
    -- Issue#140
    -- WHERE c.relkind <> 'f' AND d.description IS NOT NULL AND n.nspname = quote_ident(source_schema)
    WHERE c.relkind <> 'f' AND d.description IS NOT NULL AND n.nspname = source_schema
    ORDER BY ddl
  LOOP
    cnt := cnt + 1;
    
    -- BAD : "COMMENT ON SEQUENCE sample_clone2.CaseSensitive_ID_seq IS 'just a comment on CaseSensitive sequence';"
    -- GOOD: "COMMENT ON SEQUENCE "CaseSensitive_ID_seq" IS 'just a comment on CaseSensitive sequence';"

    -- Issue#133: might have to change index name since we do not do alter index rename anymore...
    -- See if it exists in new schema.  If not, change name to table name, column name ... _idx, which happens with CREATE TABLE LIKE construct.
    IF buffer = 'i' THEN
        -- Issue#150: TO DO, caught as error in DDLONLY mode for sampletable created with the CREATE TABLE ... LIKE method so arbitrary index names result
        -- we don't get this problem with ONLINE clone_schema since it uses pg_get_tabledef for definition which keeps the old index names
        -- User may have to comment out or fix this comment line in DDLONLY output to point to the correct index name
        -- Provide comment inline for user to guide them
        IF bDDLOnly THEN
            RAISE INFO '-- IMPORTANT NOTE: You may need to comment out the following comment since the index name may have changed from the source schema.';
        END IF;
    END IF;
    
    -- Issue#98 For MVs we create comments when we create the MVs
    IF substring(qry,1,28) = 'COMMENT ON MATERIALIZED VIEW' THEN
      IF bDebug THEN RAISE NOTICE 'DEBUG: deferring comments on MVs'; END IF;
      cnt = cnt - 1;
      continue;
    END IF;
    
    IF bDDLOnly THEN
      RAISE INFO '%', qry;
    ELSE
      lastsql = qry;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %',lastsql; END IF;
      EXECUTE lastsql;
      lastsql = '';
    END IF;
  END LOOP;
  RAISE NOTICE ' COMMENTS(1) cloned: %', LPAD(cnt::text, 5, ' ');

  -- MJV Fixed #62 for comments (PASS 2)
  action := 'Comments2';
  rc = 35;
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt2 := 0;
  IF is_prokind THEN
  FOR qry IN
    -- Issue#74 Fix: Change schema from source to target.
    -- Issue#140
    -- SELECT 'COMMENT ON SCHEMA ' || dest_schema ||
    SELECT 'COMMENT ON SCHEMA ' || quote_ident(dest_schema) ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    -- Issue#140
    -- from pg_namespace n, pg_description d where d.objoid = n.oid and n.nspname = quote_ident(source_schema)
    from pg_namespace n, pg_description d where d.objoid = n.oid and n.nspname = source_schema
    UNION
    -- Issue#74 Fix: need to replace source schema inline
    -- SELECT 'COMMENT ON TYPE ' || pg_catalog.format_type(t.oid, NULL) || ' IS ''' || pg_catalog.obj_description(t.oid, 'pg_type') || ''';' as ddl
    SELECT 'COMMENT ON TYPE ' || REPLACE(pg_catalog.format_type(t.oid, NULL), quote_ident(source_schema), quote_ident(dest_schema)) || ' IS ''' || pg_catalog.obj_description(t.oid, 'pg_type') || ''';' as ddl
    FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      -- Issue#140
      -- AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default
      AND n.nspname = source_schema COLLATE pg_catalog.default
      AND pg_catalog.obj_description(t.oid, 'pg_type') IS NOT NULL and t.typtype = 'c'
    UNION
    -- Issue#78: handle case-sensitive names with quote_ident()
    SELECT 'COMMENT ON COLLATION ' || quote_ident(dest_schema) || '.' || quote_ident(c.collname) || ' IS ''' || pg_catalog.obj_description(c.oid, 'pg_collation') || ''';' as ddl
    FROM pg_catalog.pg_collation c, pg_catalog.pg_namespace n
    WHERE n.oid = c.collnamespace AND c.collencoding IN (-1, pg_catalog.pg_char_to_encoding(pg_catalog.getdatabaseencoding()))
      -- Issue#140
      -- AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default AND pg_catalog.obj_description(c.oid, 'pg_collation') IS NOT NULL
      AND n.nspname = source_schema COLLATE pg_catalog.default AND pg_catalog.obj_description(c.oid, 'pg_collation') IS NOT NULL
    UNION
    SELECT 'COMMENT ON ' || CASE WHEN p.prokind = 'f' THEN 'FUNCTION ' WHEN p.prokind = 'p' THEN 'PROCEDURE ' WHEN p.prokind = 'a' THEN 'AGGREGATE ' END ||
    -- Issue#140
    -- dest_schema || '.' || p.proname || ' (' || oidvectortypes(p.proargtypes) || ')'
    quote_ident(dest_schema) || '.' || p.proname || ' (' || oidvectortypes(p.proargtypes) || ')'
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_catalog.pg_namespace n
    JOIN pg_catalog.pg_proc p ON p.pronamespace = n.oid
    JOIN pg_description d ON (d.objoid = p.oid)
    -- Issue#140
    -- WHERE n.nspname = quote_ident(source_schema)
    WHERE n.nspname = source_schema
    UNION
    -- Issue#140
    -- SELECT 'COMMENT ON POLICY ' || p1.policyname || ' ON ' || dest_schema || '.' || p1.tablename ||
    SELECT 'COMMENT ON POLICY ' || p1.policyname || ' ON ' || quote_ident(dest_schema) || '.' || p1.tablename ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_policies p1, pg_policy p2, pg_class c, pg_namespace n, pg_description d
    WHERE p1.schemaname = n.nspname AND p1.tablename = c.relname AND n.oid = c.relnamespace
      -- Issue#140
      -- AND c.relkind in ('r','p') AND p1.policyname = p2.polname AND d.objoid = p2.oid AND p1.schemaname = quote_ident(source_schema)
      AND c.relkind in ('r','p') AND p1.policyname = p2.polname AND d.objoid = p2.oid AND p1.schemaname = source_schema
    UNION
    -- Issue#140
    -- SELECT 'COMMENT ON DOMAIN ' || dest_schema || '.' || t.typname ||
    SELECT 'COMMENT ON DOMAIN ' || quote_ident(dest_schema) || '.' || t.typname ||
    -- Issue#74 Fix
    -- ' IS ''' || d.description || ''';' as ddl
    ' IS '   || quote_literal(d.description) || ';' as ddl
    FROM pg_catalog.pg_type t
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_catalog.pg_description d ON d.classoid = t.tableoid AND d.objoid = t.oid AND d.objsubid = 0
    -- Issue#140
    -- WHERE t.typtype = 'd' AND n.nspname = quote_ident(source_schema) COLLATE pg_catalog.default
    WHERE t.typtype = 'd' AND n.nspname = source_schema COLLATE pg_catalog.default
    ORDER BY 1
  LOOP
    -- TEMP!!!!!!!!
    -- IF POSITION('COMMENT ON DOMAIN' IN qry) > 0 THEN 
    --     RAISE NOTICE 'Bypassing domain comment, %',qry;
    --     continue;
    -- END IF;
    cnt2 := cnt2 + 1;
    IF bDDLOnly THEN
      RAISE INFO '%', qry;
    ELSE
      lastsql = qry;
      EXECUTE qry;
      lastsql = '';
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
    -- FIX Isse#87 by adding double quotes around collation name
    SELECT 'COMMENT ON COLLATION ' || dest_schema || '."' || c.collname || '" IS ''' || pg_catalog.obj_description(c.oid, 'pg_collation') || ''';' as ddl
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
    IF bDDLOnly THEN
      RAISE INFO '%', qry;
    ELSE
      lastsql = qry;
      EXECUTE qry;
      lastsql = '';
    END IF;
  END LOOP;
  END IF;
  RAISE NOTICE ' COMMENTS(2) cloned: %', LPAD(cnt2::text, 5, ' ');


  -- Issue#95 bypass if No ACL specified.
  IF NOT bNoACL THEN
    -- ---------------------
    -- MV: Permissions: Defaults
    -- ---------------------
    EXECUTE 'SET search_path = ' || quote_ident(source_schema) ;
    -- RAISE WARNING 'DEBUGGGG: search_path changed back to source schema:%', quote_ident(source_schema);
    action := 'PRIVS: Defaults';
    rc = 36;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    cnt := 0;
    FOR arec IN
      SELECT pg_catalog.pg_get_userbyid(d.defaclrole) AS "owner", n.nspname AS schema,
      CASE d.defaclobjtype WHEN 'r' THEN 'table' WHEN 'S' THEN 'sequence' WHEN 'f' THEN 'function' WHEN 'T' THEN 'type' WHEN 'n' THEN 'schema' END AS atype,
      d.defaclacl as defaclacl, pg_catalog.array_to_string(d.defaclacl, ',') as defaclstr
      FROM pg_catalog.pg_default_acl d LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = d.defaclnamespace)
      -- Issue#130
      -- WHERE n.nspname IS NOT NULL AND n.nspname = quote_ident(source_schema)
      WHERE n.nspname IS NOT NULL AND n.nspname = source_schema
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
            
              -- Issue#92 Fix
              -- set role = cm_stage_ro_grp;
              -- ALTER DEFAULT PRIVILEGES FOR ROLE cm_stage_ro_grp IN SCHEMA cm_stage GRANT REFERENCES, TRIGGER ON TABLES TO cm_stage_ro_grp;
              IF grantor = grantee THEN
                  -- append set role to statement
                  -- Issue#131: double quote schema/roles
                  -- buffer = 'SET ROLE = ' || grantor || '; ' || buffer;
                  buffer = 'SET ROLE = "' || grantor || '"; ' || buffer;
              END IF;
            
              IF bDDLOnly THEN
                RAISE INFO '%', buffer;
              ELSE
                lastsql = buffer;
                IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                EXECUTE lastsql;
                lastsql = '';
              END IF;
              -- Issue#92 Fix:
              EXECUTE 'SET ROLE = ' || calleruser;
            
            ELSIF arec.atype = 'sequence' THEN
              IF POSITION('r' IN privs) > 0 AND POSITION('w' IN privs) > 0 AND POSITION('U' IN privs) > 0 THEN
                -- arU is enough for all privs
                buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ALL ON SEQUENCES TO "' || grantee || '";';
              
                -- Issue#92 Fix
                IF grantor = grantee THEN
                    -- append set role to statement
                    buffer = 'SET ROLE = ' || grantor || '; ' || buffer;
                END IF;

                IF bDDLOnly THEN
                  RAISE INFO '%', buffer;
                ELSE
                  lastsql = buffer;
                  IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                  EXECUTE lastsql;
                  lastsql = '';
                END IF;
                -- Issue#92 Fix:
                lastsql = 'SET ROLE = ' || calleruser; 
                -- IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                EXECUTE lastsql;
                lastsql = '';

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

                -- Issue#92 Fix
                IF grantor = grantee THEN
                    -- append set role to statement
                    buffer = 'SET ROLE = ' || grantor || '; ' || buffer;
                END IF;
              
                IF bDDLOnly THEN
                  RAISE INFO '%', buffer;
                ELSE
                  lastsql = buffer;
                  IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                  EXECUTE lastsql;
                  lastsql = '';
                END IF;
                select current_user into buffer;
                -- Issue#92 Fix:
                -- IF bDebugExec THEN RAISE NOTICE 'EXEC: %', 'SET ROLE = ' || calleruser; END IF;    
                EXECUTE 'SET ROLE = ' || calleruser;
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
            
              -- Issue#92 Fix
              IF grantor = grantee THEN
                  -- append set role to statement
                  buffer = 'SET ROLE = ' || grantor || '; ' || buffer;
              END IF;
            
              IF bDDLOnly THEN
                RAISE INFO '%', buffer;
              ELSE
                lastsql = buffer;
                IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                EXECUTE lastsql;
                lastsql = '';
              END IF;
              select current_user into buffer;
              -- Issue#92 Fix:
              EXECUTE 'SET ROLE = ' || calleruser;
              -- IF bDebugExec THEN RAISE NOTICE 'EXEC: %', 'SET ROLE = ' || calleruser; END IF;    

            ELSIF arec.atype = 'type' THEN
              IF POSITION('r' IN privs) > 0 AND POSITION('w' IN privs) > 0 AND POSITION('U' IN privs) > 0 THEN
                -- arU is enough for all privs
                buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT ALL ON TYPES TO "' || grantee || '";';
                
                -- Issue#92 Fix
                IF grantor = grantee THEN
                    -- append set role to statement
                    buffer = 'SET ROLE = ' || grantor || '; ' || buffer;
                END IF;
              
                IF bDDLOnly THEN
                  RAISE INFO '%', buffer;
                ELSE
                  lastsql = buffer;
                  IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                  EXECUTE lastsql;
                  lastsql = '';
                END IF;
                -- Issue#92 Fix:
                -- IF bDebugExec THEN RAISE NOTICE 'EXEC: %', 'SET ROLE = ' || calleruser; END IF;    
                lastsql = 'SET ROLE = ' || calleruser;
                EXECUTE lastsql;
                lastsql = '';
              
              ELSIF POSITION('U' IN privs) THEN
                buffer := 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || grantor || ' IN SCHEMA ' || quote_ident(dest_schema) || ' GRANT USAGE ON TYPES TO "' || grantee || '";';
              
                -- Issue#92 Fix
                IF grantor = grantee THEN
                    -- append set role to statement
                    buffer = 'SET ROLE = ' || grantor || '; ' || buffer;
                END IF;
              
                IF bDDLOnly THEN
                  RAISE INFO '%', buffer;
                ELSE
                  lastsql = buffer;
                  IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                  EXECUTE lastsql;
                  lastsql = '';
                END IF;
                -- Issue#92 Fix:
                lastsql = 'SET ROLE = ' || calleruser;
                IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
                EXECUTE lastsql;
                lastsql = '';
              
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
  END IF; -- NO ACL BRANCH

  IF bDDLOnly THEN
      -- Issue#150: In DDLONLY mode, changing the current role in the previous DEFAULT PRIVILEGES section will affect permissions going forward to reset to the original user that invoked clone_schema
      v_dummy = 'SET ROLE ' || role_invoker || ';';
      RAISE INFO '%', v_dummy;
  END IF;
    
  -- Issue#95 bypass if No ACL specified
  IF NOT bNoACL THEN
    -- crunchy data extension, check_access
    -- SELECT role_path, base_role, as_role, objtype, schemaname, objname, array_to_string(array_agg(privname),',') as privs  FROM all_access()
    -- WHERE base_role != CURRENT_USER and objtype = 'schema' and schemaname = 'public' group by 1,2,3,4,5,6;

    action := 'PRIVS: Schema';
    rc = 37;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    cnt := 0;
    FOR arec IN
      SELECT 'GRANT ' || p.perm::public.permm_type || ' ON SCHEMA ' || quote_ident(dest_schema) || ' TO "' || r.rolname || '";' as schema_ddl
      FROM pg_catalog.pg_namespace AS n
      CROSS JOIN pg_catalog.pg_roles AS r
      CROSS JOIN (VALUES ('USAGE'), ('CREATE')) AS p(perm)
      -- Issue#140
      -- WHERE n.nspname = quote_ident(source_schema) AND NOT r.rolsuper AND has_schema_privilege(r.oid, n.oid, p.perm) AND
      WHERE n.nspname = source_schema AND NOT r.rolsuper AND has_schema_privilege(r.oid, n.oid, p.perm) AND      
      --Issue#123: do not assign to system roles
      r.rolname NOT IN ('pg_read_all_data','pg_write_all_data') 
      ORDER BY r.rolname, p.perm::public.permm_type
    LOOP
      BEGIN
        cnt := cnt + 1;
        IF bDDLOnly THEN
          RAISE INFO '%', arec.schema_ddl;
        ELSE
          lastsql = arec.schema_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
          EXECUTE lastsql;
          lastsql = '';
        END IF;
  
      END;
    END LOOP;
    RAISE NOTICE 'SCHEMA PRIVS cloned: %', LPAD(cnt::text, 5, ' ');
  END IF; -- NO ACL BRANCH

  -- Issue#95 bypass if No ACL specified
  IF NOT bNoACL THEN
    -- MV: PRIVS: sequences
    action := 'PRIVS: Sequences';
    rc = 38;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    cnt := 0;
    FOR arec IN
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on t.relname
      SELECT 'GRANT ' || p.perm::public.permm_type || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(t.relname::text) || ' TO "' || r.rolname || '";' as seq_ddl
      FROM pg_catalog.pg_class AS t
      CROSS JOIN pg_catalog.pg_roles AS r
      CROSS JOIN (VALUES ('SELECT'), ('USAGE'), ('UPDATE')) AS p(perm)
      WHERE t.relnamespace::regnamespace::name = quote_ident(source_schema) AND t.relkind = 'S'  AND NOT r.rolsuper AND has_sequence_privilege(r.oid, t.oid, p.perm) AND
      --Issue#123: do not assign to system roles
      r.rolname NOT IN ('pg_read_all_data','pg_write_all_data') 
    LOOP
      BEGIN
        cnt := cnt + 1;
        -- IF bDebug THEN RAISE NOTICE 'DEBUG: ddl=%', arec.seq_ddl; END IF;
        IF bDDLOnly THEN
          RAISE INFO '%', arec.seq_ddl;
        ELSE
          lastsql = arec.seq_ddl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END;
    END LOOP;
    RAISE NOTICE '  SEQ. PRIVS cloned: %', LPAD(cnt::text, 5, ' ');
  END IF; -- NO ACL BRANCH    

  -- Issue#95 bypass if No ACL specified
  IF NOT bNoACL THEN
    -- MV: PRIVS: functions
    action := 'PRIVS: Functions/Procedures';
    rc = 39;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    cnt := 0;

    -- Issue#61 FIX: use set_config for empty string
    -- SET search_path = '';
    -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
    SELECT set_config('search_path', '', true) into v_dummy;
    -- RAISE WARNING 'DEBUGGGG: search_path changed to empty string:%', v_dummy; 

    -- RAISE NOTICE ' source_schema=%  dest_schema=%',source_schema, dest_schema;
    FOR arec IN
      -- 2021-03-05 MJV FIX: issue#35: caused exception in some functions with parameters and gave privileges to other users that should not have gotten them.
      -- SELECT 'GRANT EXECUTE ON FUNCTION ' || quote_ident(dest_schema) || '.' || replace(regexp_replace(f.oid::regprocedure::text, '^((("[^"]*")|([^"][^.]*))\.)?', ''), source_schema, dest_schema) || ' TO "' || r.rolname || '";' as func_ddl
      -- FROM pg_catalog.pg_proc f CROSS JOIN pg_catalog.pg_roles AS r WHERE f.pronamespace::regnamespace::name = quote_ident(source_schema) AND NOT r.rolsuper AND has_function_privilege(r.oid, f.oid, 'EXECUTE')
      -- order by regexp_replace(f.oid::regprocedure::text, '^((("[^"]*")|([^"][^.]*))\.)?', '')

      -- 2021-03-05 MJV FIX: issue#37: defaults cause problems, use system function that returns args WITHOUT DEFAULTS
      -- COALESCE(r.routine_type, 'FUNCTION'): for aggregate functions, information_schema.routines contains NULL as routine_type value.
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on rp.routine_name
      -- Issue#131: do the same for schema/owners
      -- SELECT 'GRANT ' || rp.privilege_type || ' ON ' || COALESCE(r.routine_type, 'FUNCTION') || ' ' || quote_ident(dest_schema) || '.' || quote_ident(rp.routine_name) || ' (' || pg_get_function_identity_arguments(p.oid) || ') TO ' || string_agg(distinct rp.grantee, ',') || ';' as func_dcl
      SELECT 'GRANT ' || rp.privilege_type || ' ON ' || COALESCE(r.routine_type, 'FUNCTION') || ' ' || quote_ident(dest_schema) || '.' || quote_ident(rp.routine_name) || ' (' || pg_get_function_identity_arguments(p.oid) || ') TO "' || string_agg(distinct rp.grantee, '","') || '";' as func_dcl
      FROM information_schema.routine_privileges rp, information_schema.routines r, pg_proc p, pg_namespace n
      -- Issue#140
      -- WHERE rp.routine_schema = quote_ident(source_schema)
      WHERE rp.routine_schema = source_schema
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
        IF bDDLOnly THEN
          RAISE INFO '%', arec.func_dcl;
        ELSE
          lastsql = arec.func_dcl;
          IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
          EXECUTE lastsql;
          lastsql = '';
        END IF;
      END;
    END LOOP;
    EXECUTE 'SET search_path = ' || quote_ident(source_schema);
    -- RAISE WARNING 'DEBUGGGG: search_path changed back to source schema:%', quote_ident(source_schema);
    RAISE NOTICE '  FUNC PRIVS cloned: %', LPAD(cnt::text, 5, ' ');
  END IF; -- NO ACL BRANCH

  -- LOOP for regular tables and populate them if specified
  -- Issue#75 moved from big table loop above to here.
  IF bData THEN
    r = clock_timestamp();
    -- IF bVerbose THEN RAISE NOTICE 'START: copy rows %',clock_timestamp() - t; END IF;  
    IF bVerbose THEN RAISE NOTICE 'Copying rows...'; END IF;  

    EXECUTE 'SET search_path = ' || quote_ident(dest_schema) ;
    -- RAISE WARNING 'DEBUGGGG: search_path changed to target schema:%', quote_ident(dest_schema);
    action := 'Copy Rows';
    rc = 40;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    FOREACH tblelement IN ARRAY tblarray
    LOOP 
       s = clock_timestamp();
       IF bDebug THEN RAISE NOTICE 'DEBUG1: no UDTs %', tblelement; END IF;
       lastsql = tblelement;
       IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
       EXECUTE lastsql;       
       lastsql = '';
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
       cnt2 := cast(extract(epoch from (clock_timestamp() - s)) as numeric(18,3));
       IF bVerbose THEN RAISE NOTICE 'Populated cloned table, %   Rows Copied: %    seconds: %', buffer, LPAD(cnt::text, 10, ' '), LPAD(cnt2::text, 5, ' '); END IF;
       tblscopied := tblscopied + 1;
    END LOOP;
    
    -- Issue#79 implementation
    -- Do same for tables with user-defined elements using copy to file method
    FOREACH tblelement IN ARRAY tblarray2
    LOOP 
       s = clock_timestamp();
       IF bDebug THEN RAISE NOTICE 'DEBUG2: UDTs %', tblelement; END IF;
       lastsql = tblelement;
       IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
       EXECUTE lastsql;       
       lastsql = '';
       GET DIAGNOSTICS cnt = ROW_COUNT;  
       
       -- STATEMENT LOOKS LIKE THIS:
       -- INSERT INTO sample11.warehouses SELECT * FROM sample.warehouses;
       -- INSERT INTO sample11.person OVERRIDING SYSTEM VALUE SELECT * FROM sample.person;  
       -- COPY sample.address TO '/tmp/cloneschema.tmp' WITH DELIMITER AS ',';\
       buffer = TRIM(tblelement::text);
       -- RAISE NOTICE 'element=%', buffer;
       cnt1 = POSITION('INSERT INTO' IN buffer);
       cnt2 = POSITION('COPY ' IN buffer);
       IF cnt1 > 0 THEN
           buffer = substring(buffer, 12);
       ELSIF cnt2 > 0 THEN
           buffer = substring(buffer, 5);
       ELSE
           RAISE EXCEPTION 'Programming Error for parsing tblarray2.';
       END IF;

       -- RAISE NOTICE 'buffer1=%', buffer;
       cnt1 = POSITION(' OVERRIDING ' IN buffer);
       cnt2 = POSITION('SELECT * FROM ' IN buffer);
       cnt3 = POSITION(' FROM ' IN buffer);
       cnt4 = POSITION(' TO ' IN buffer);
       IF cnt1 > 0 THEN
           buffer = substring(buffer, 1, cnt1-2);
       ELSIF cnt2 > 0 THEN
           buffer = substring(buffer, 1, cnt2-2);
       ELSIF cnt3 > 0 THEN
           buffer = substring(buffer, 1, cnt3-1);           
       ELSIF cnt4 > 0 THEN
           -- skip the COPY TO statements
           continue;
       ELSE
           RAISE EXCEPTION 'Programming Error for parsing tblarray2.';
       END IF;
       -- RAISE NOTICE 'buffer2=%', buffer;
       
       SELECT RPAD(buffer, 35, ' ') INTO buffer;
       -- RAISE NOTICE 'buffer3=%', buffer;
       cnt2 := cast(extract(epoch from (clock_timestamp() - s)) as numeric(18,3));
       IF bVerbose THEN RAISE NOTICE 'Populated cloned table, %   Rows Copied: %    seconds: %', buffer, LPAD(cnt::text, 10, ' '), LPAD(cnt2::text, 5, ' '); END IF;
       tblscopied := tblscopied + 1;
    END LOOP;    
    
    -- Issue#101 
    -- Do same for tables with user-defined elements using direct method with text cast
    FOREACH tblelement IN ARRAY tblarray3
    LOOP 
       s = clock_timestamp();
       IF bDebug THEN RAISE NOTICE 'DEBUG3: UDTs %', tblelement; END IF;
       lastsql = tblelement;
       IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
       EXECUTE lastsql;       
       lastsql = '';
       GET DIAGNOSTICS cnt = ROW_COUNT;  
       cnt2 = POSITION(' (' IN tblelement::text);
       cnt3 = POSITION('INSERT INTO ' IN tblelement::text);
       IF cnt3 > 0 THEN
           -- INSERT INTO sample7.citextusers           
           tblname = substring(tblelement, 12);
           tblname = Trim(substring(tblname, 1, cnt2 - 12));           
       ELSEIF cnt2 > 0 THEN
           tblname = substring(tblelement, 1, cnt2);
       ELSE
           -- program error
           RAISE EXCEPTION 'Program error: unable to parse tblarray3 for documenting row copy.';
       END IF;           
       SELECT RPAD(tblname, 35, ' ') INTO buffer;
       cnt2 := cast(extract(epoch from (clock_timestamp() - s)) as numeric(18,3));
       IF bVerbose THEN RAISE NOTICE 'Populated cloned table, %   Rows Copied: %    seconds: %', buffer, LPAD(cnt::text, 10, ' '), LPAD(cnt2::text, 5, ' '); END IF;
       tblscopied := tblscopied + 1;
    END LOOP;    
    
    -- Issue#98 MVs deferred until now
    FOREACH tblelement IN ARRAY mvarray
    LOOP 
       s = clock_timestamp();
       lastsql = tblelement;
       IF bDebugExec THEN RAISE NOTICE 'EXEC: %', lastsql; END IF;    
       EXECUTE lastsql;       
       lastsql = '';
       -- get diagnostics for MV creates or refreshes does not work, always returns 1
       GET DIAGNOSTICS cnt = ROW_COUNT;  
       buffer = substring(tblelement, 25);
       cnt2 = POSITION(' AS ' IN buffer);
       IF cnt2 > 0 THEN
         buffer = Trim(substring(buffer, 1, cnt2));
         SELECT RPAD(buffer, 36, ' ') INTO buffer;
         cnt2 := cast(extract(epoch from (clock_timestamp() - s)) as numeric(18,3));
         IF bVerbose THEN RAISE NOTICE 'Populated Mat. View,    %  Rows Inserted:        ?    seconds: %', buffer, LPAD(cnt2::text, 5, ' '); END IF;
         mvscopied := mvscopied + 1;
       END IF;
    END LOOP;    
    
    cnt := cast(extract(epoch from (clock_timestamp() - r)) as numeric(18,3));
    IF bVerbose THEN RAISE NOTICE 'Copy rows duration: % seconds',cnt; END IF;  
  END IF;
 
  --Issue#133: create deferred views here since MVs they depend on are done now, but only if not in DATA mode where we do it after tables and MVs are created  
  IF bData THEN
      action := 'Deferred Views';
      rc = 41;
      IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
      cnt = 0;
      FOREACH viewdef IN ARRAY deferredviews
        LOOP 
          cnt = cnt + 1;
          s = clock_timestamp();
          IF bDebug THEN RAISE NOTICE 'DEBUG: executing deferred view, %',viewdef; END IF;    
          IF bDDLOnly THEN
            RAISE INFO '%', v_def;
          ELSE
            lastsql = viewdef;
            IF bDebugExec THEN RAISE NOTICE 'EXEC: %', substring(lastsql,1,25); END IF;    
            EXECUTE lastsql;
            lastsql = '';
          END IF;
        END LOOP;
  RAISE NOTICE 'Deferrd VIEWS cloned:%', LPAD(cnt::text, 5, ' ');
  END IF;

  -- Issue#120: deferred sequence owner definitions until now
  FOREACH tblelement IN ARRAY tblarray4
  LOOP 
     s = clock_timestamp();
     IF bDebug THEN RAISE NOTICE 'DEBUG: %', tblelement; END IF;
     IF bDDLOnly THEN
         RAISE INFO '%', tblelement;
     ELSE 
         IF bDebugExec THEN RAISE NOTICE 'EXEC: %', tblelement; END IF;
         EXECUTE tblelement;       
     END IF;
  END LOOP;    

  -- Issue#95 bypass if No ACL specified
  -- Issue#133: move to after table creation below
  IF NOT bNoACL THEN
    -- MV: PRIVS: tables
    action := 'PRIVS: Tables';
    rc = 42;
    IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
    -- regular, partitioned, and foreign tables plus view and materialized view permissions. Ignored for now: implement foreign table defs.
    cnt := 0;
    FOR arec IN
      -- 2021-03-05  MJV FIX: Fixed Issue#36 for tables
      -- Issue#78 FIX: handle case-sensitive names with quote_ident() on t.relname      
      -- 2024-01-24  MJV FIX: Issue#117    
      SELECT c.relkind, 'GRANT ' || tb.privilege_type || CASE WHEN c.relkind in ('r', 'p') THEN ' ON TABLE ' WHEN c.relkind in ('v', 'm')  THEN ' ON ' END ||
      -- Issue#131: double quote schema/roles
      -- quote_ident(dest_schema) || '.' || quote_ident(tb.table_name) || ' TO ' || string_agg(tb.grantee, ',') || ';' as tbl_dcl
      quote_ident(dest_schema) || '.' || quote_ident(tb.table_name) || ' TO "' || string_agg(tb.grantee, '","') || '";' as tbl_dcl
      FROM information_schema.table_privileges tb, pg_class c, pg_namespace n
      -- Issue#140
      -- WHERE tb.table_schema = quote_ident(source_schema) AND tb.table_name = c.relname AND c.relkind in ('r', 'p', 'v', 'm')
      --  AND c.relnamespace = n.oid AND n.nspname = quote_ident(source_schema)
      WHERE tb.table_schema = source_schema AND tb.table_name = c.relname AND c.relkind in ('r', 'p', 'v', 'm')
        AND c.relnamespace = n.oid AND n.nspname = source_schema
        GROUP BY c.relkind, tb.privilege_type, tb.table_schema, tb.table_name 
        ORDER BY tb.table_name, tb.privilege_type
    LOOP
      BEGIN
        cnt := cnt + 1;
        -- IF bDebug THEN RAISE NOTICE 'DEBUG: ddl=%', arec.tbl_dcl; END IF;
        -- Issue#46. Fixed reference to invalid record name (tbl_ddl --> tbl_dcl).
        IF arec.relkind = 'f' THEN
          RAISE WARNING 'Foreign tables are not currently implemented, so skipping privs for them. ddl=%', arec.tbl_dcl;
        ELSE
            IF bDDLOnly THEN
                RAISE INFO '%', arec.tbl_dcl;
            ELSE
                lastsql = arec.tbl_dcl;
                IF bDebugExec THEN RAISE NOTICE 'EXEC: %', arec.tbl_dcl; END IF;    
                EXECUTE arec.tbl_dcl;
                lastsql = '';
              END IF;
      END IF;
      END;
    END LOOP;
    RAISE NOTICE ' TABLE PRIVS cloned: %', LPAD(cnt::text, 5, ' ');
  END IF; -- NO ACL BRANCH
  
  -- Issue#78 forces us to defer FKeys until the end since we previously did row copies before FKeys
  --  add FK constraint
  action := 'FK Constraints';
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;

  -- Issue#61 FIX: use set_config for empty string
  -- SET search_path = '';
  -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
  SELECT set_config('search_path', '', true) into v_dummy;
  -- RAISE WARNING 'DEBUGGGG: search_path changed to empty string:%', v_dummy; 

  FOR qry IN
    SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname)
                          || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || REPLACE(pg_get_constraintdef(ct.oid), 'REFERENCES ' || quote_ident(source_schema) || '.', 'REFERENCES ' 
                          || quote_ident(dest_schema) || '.') || ';'
    FROM pg_constraint ct
    JOIN pg_class rn ON rn.oid = ct.conrelid
    -- Issue#103 needed to addd this left join
    LEFT JOIN pg_inherits i ON (rn.oid = i.inhrelid)
    WHERE connamespace = src_oid
        AND rn.relkind = 'r'
        AND ct.contype = 'f'
        -- Issue#103 fix: needed to also add this null check
        AND i.inhrelid is null
  LOOP
    cnt := cnt + 1;
    IF bDDLOnly THEN
      RAISE INFO '%', qry;
    ELSE
      IF bDebug THEN RAISE NOTICE 'DEBUG: adding FKEY constraint: %', qry; END IF;
      lastsql = qry;
      IF bDebugExec THEN RAISE NOTICE 'EXEC: %', qry; END IF;    
      EXECUTE qry;
      lastsql = '';
    END IF;
  END LOOP;
  EXECUTE 'SET search_path = ' || quote_ident(source_schema);
  -- RAISE WARNING 'DEBUGGGG: search_path changed to source schema:%', quote_ident(source_schema); 
  RAISE NOTICE '       FKEYS cloned: %', LPAD(cnt::text, 5, ' ');

  -- Issue#111: forces us to defer triggers til after we populate the tables, just like we did with FKeys (Issue#78).
  -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
  SELECT set_config('search_path', '', true) into v_dummy;
  -- RAISE WARNING 'DEBUGGGG: search_path changed to empty string:%', v_dummy; 

  action := 'Triggers';
  IF bDebug THEN RAISE NOTICE 'DEBUG: Section=%',action; END IF;
  cnt := 0;
  FOR arec IN
    -- 2021-03-09 MJV FIX:  #40  fixed sql to get the def using pg_get_triggerdef() sql
    -- 2024-11-14 MJV FIX: #140  fixed case sensitive schemas
    -- 2024-12-12 MJV FIX: #147  fixed sql to get the trigger def even if function resides in public schema, but qualify it as such
    SELECT n1.nspname as trigger_schema, c.relname as table, t.tgname as trigger_name, n2.nspname as function_schema, p.proname as function_name,
    REPLACE(pg_get_triggerdef(t.oid), quote_ident(source_schema), quote_ident(dest_schema)) || ';' AS trig_ddl
    FROM pg_trigger t, pg_namespace n1, pg_class c, pg_proc p, pg_namespace n2
    WHERE n1.nspname = quote_ident(source_schema) AND n1.oid = c.relnamespace AND c.relkind in ('r','p') AND (n2.nspname = quote_ident(source_schema) OR n2.nspname = 'public') 
    AND c.oid = t.tgrelid AND t.tgfoid = p.oid AND p.pronamespace = n2.oid
    ORDER BY c.relname, t.tgname
  LOOP
    BEGIN
      cnt := cnt + 1;
      IF bDDLOnly THEN
        RAISE INFO '%', arec.trig_ddl;
      ELSE
        lastsql = arec.trig_ddl;
        IF bDebugExec THEN RAISE NOTICE 'EXEC: %', arec.trig_ddl; END IF;    
        EXECUTE arec.trig_ddl;
        lastsql = '';
      END IF;
    END;
  END LOOP;
  RAISE NOTICE '    TRIGGERS cloned: %', LPAD(cnt::text, 5, ' ');

  RAISE NOTICE '      TABLES copied: %', LPAD(tblscopied::text, 5, ' ');
  RAISE NOTICE ' MATVIEWS refreshed: %', LPAD(mvscopied::text, 5, ' ');

  IF v_src_path_old = '' OR v_src_path_old = '""' THEN
    -- RAISE NOTICE 'Restoring old search_path to empty string';
    -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
    SELECT set_config('search_path', '', true) into v_dummy;
    -- RAISE WARNING 'DEBUGGGG: search_path changed to empty string:%', v_dummy; 
  ELSE
    -- RAISE NOTICE 'Restoring old search_path to:%', v_src_path_old;
    EXECUTE 'SET search_path = ' || v_src_path_old;
    -- RAISE WARNING 'DEBUGGGG: search_path changed to old one:%', v_src_path_old; 
  END IF;
  SELECT setting INTO v_dummy FROM pg_settings WHERE name = 'search_path';
  -- RAISE WARNING 'DEBUGGGG: setting search_path back to what it was: %', v_dummy; 
  cnt := cast(extract(epoch from (clock_timestamp() - t)) as numeric(18,3));
  
  -- Issue#141: Remove processing types before leaving
  DROP TYPE IF EXISTS public.objj_type;
  DROP TYPE IF EXISTS public.permm_type;
  
  IF bVerbose THEN RAISE NOTICE 'clone_schema duration: % seconds',cnt; END IF;  
  RETURN RC_OK;
  
  EXCEPTION
     WHEN others THEN
     BEGIN
         GET STACKED DIAGNOSTICS v_diag1 = MESSAGE_TEXT, v_diag2 = PG_EXCEPTION_DETAIL, v_diag3 = PG_EXCEPTION_HINT, v_diag4 = RETURNED_SQLSTATE, v_diag5 = PG_CONTEXT, v_diag6 = PG_EXCEPTION_CONTEXT;
         v_ret := 'line=' || v_diag6 || '. '|| v_diag4 || '. ' || v_diag1;
         -- Issue#101: added version to exception output
         -- RAISE NOTICE 'v_diag1=%  v_diag2=%  v_diag3=%  v_diag4=%  v_diag5=%  v_diag6=%', v_diag1, v_diag2, v_diag3, v_diag4, v_diag5, v_diag6; 
         buffer2 = '';
         IF action = 'Copy Rows' AND v_diag4 = '42704' THEN
             -- Issue#105 Help user to fix the problem.
             buffer2 = 'It appears you have a USER-DEFINED column type mismatch.  Try running clone_schema with the FILECOPY option. ';
         END IF;

         IF lastsql <> '' THEN
             buffer = v_ret || E'\n'|| buffer2 || E'\naction=' || action || '  LastSQL='|| lastsql;
         ELSE
             buffer = v_ret || E'\n'|| buffer2 || 'action =' || action;
         END IF;         
         
         -- get current state of search_path too
         SELECT setting INTO spath_tmp FROM pg_settings WHERE name = 'search_path';
         RAISE EXCEPTION 'Version: %  Action: %  CurrentSP: %  oldSP=%  newSP=%  Diagnostics: %',v_version, action, spath_tmp, v_src_path_old, v_src_path_new, buffer;

         IF v_src_path_old = '' THEN
           -- RAISE NOTICE 'setting old search_path to empty string';
           -- Issue#138: make search path changes only effective for the current transaction (last parm goes from false to true)
           SELECT set_config('search_path', '', true);
         ELSE
           -- RAISE NOTICE 'setting old search_path to:%', v_src_path_old;
           EXECUTE 'SET search_path = ' || v_src_path_old;
         END IF;
         RETURN rc;
     END;
END;

$BODY$
  LANGUAGE plpgsql VOLATILE  COST 100;

-- ALTER FUNCTION public.clone_schema(text, text, cloneparms[]) OWNER TO postgres;
-- REVOKE ALL PRIVILEGES ON FUNCTION clone_schema(text, text, cloneparms[]) FROM public;
