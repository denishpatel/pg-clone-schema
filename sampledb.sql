--
-- Sample database used for clone_schema() testing
-- psql -b postgres < ./sampledb.sql
-- psql -v ON_ERROR_STOP=1 -e -b postgres < ./sampledb.sql
-- psql clone_testing < /var/lib/pgsql/clone_schema/clone_schema.sql
-- psql clone_testing; select clone_schema('sample', 'sample_clone1', false, false);
--

-- drop/create clone schema database
drop database if exists clone_testing;
create database clone_testing;
\connect clone_testing;
COMMENT ON DATABASE clone_testing IS 'just a comment on my sample database';

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- drop roles related to this database
DROP ROLE IF EXISTS mydb_admin;
DROP ROLE IF EXISTS mydb_app;
DROP ROLE IF EXISTS mydb_dev;
DROP ROLE IF EXISTS mydb_owner;
DROP ROLE IF EXISTS mydb_read;
DROP ROLE IF EXISTS mydb_reader;
DROP ROLE IF EXISTS mydb_update;
DROP ROLE IF EXISTS sysdba;

-- set global stuff: 

-- don't worry if roles already exist, since they are cluster-wide, not just database-wide
CREATE ROLE mydb_admin;
ALTER ROLE mydb_admin WITH SUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md52a9d1ad681c50b59ac5490fe0ed52331';
CREATE ROLE mydb_app;
ALTER ROLE mydb_app WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md5820313583c1e870894141ecdc09b21c4';
CREATE ROLE mydb_dev;
ALTER ROLE mydb_dev WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md573a6b2a984951530ee73faee1f7a50eb';
CREATE ROLE mydb_owner;
ALTER ROLE mydb_owner WITH NOSUPERUSER INHERIT CREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE mydb_read;
ALTER ROLE mydb_read WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE mydb_reader;
ALTER ROLE mydb_reader WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md53f632bcce057ab249fa3808470195eff';
CREATE ROLE mydb_update;
ALTER ROLE mydb_update WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE sysdba;
ALTER ROLE sysdba WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION NOBYPASSRLS PASSWORD 'md54f2192d28c96b5e38d4553264cb2f448';
ALTER ROLE mydb_admin SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_app SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_dev SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_read SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_reader SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_update SET search_path TO 'public, pg_catalog';


-- Role memberships
GRANT mydb_owner TO mydb_admin GRANTED BY postgres;
GRANT mydb_read TO mydb_app GRANTED BY mydb_owner;
GRANT mydb_read TO mydb_dev GRANTED BY mydb_owner;
GRANT mydb_read TO mydb_owner GRANTED BY postgres;
GRANT mydb_read TO mydb_reader GRANTED BY mydb_owner;
GRANT mydb_read TO mydb_update GRANTED BY mydb_owner;
GRANT mydb_update TO mydb_app GRANTED BY mydb_owner;
GRANT mydb_update TO mydb_dev GRANTED BY mydb_owner;
GRANT mydb_update TO mydb_owner GRANTED BY postgres;

-- end of global stuff

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA public;
COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';

CREATE SERVER my_foreign_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
    dbname 'testing2',
    host 'localhost',
    port '5443'
);
ALTER SERVER my_foreign_server OWNER TO sysdba;

CREATE USER MAPPING FOR postgres SERVER my_foreign_server OPTIONS (
    password 'sysdbapass',
    "user" 'sysdba'
);

CREATE USER MAPPING FOR sysdba SERVER my_foreign_server OPTIONS (
    password 'sysdbapass',
    "user" 'sysdba'
);


--
-- Name: sample; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA sample;
SET search_path = sample, public;


ALTER SCHEMA sample OWNER TO postgres;

--
-- Name: SCHEMA sample; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA sample IS 'standard sample schema';


--
-- Name: de-u-co-phonebk-x-icu; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION "de-u-co-phonebk-x-icu" (provider = icu, locale = 'de-u-co-phonebk');


ALTER COLLATION "de-u-co-phonebk-x-icu" OWNER TO postgres;

--
-- Name: french; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION french (provider = icu, locale = 'fr');
COMMENT ON COLLATION french IS 'my comments on french collation';


ALTER COLLATION french OWNER TO postgres;

--
-- Name: german_phonebook; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION german_phonebook (provider = icu, locale = 'de-u-co-phonebk');


ALTER COLLATION german_phonebook OWNER TO postgres;

--
-- Name: und-u-co-emoji-x-icu; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION "und-u-co-emoji-x-icu" (provider = icu, locale = 'und-u-co-emoji');


ALTER COLLATION "und-u-co-emoji-x-icu" OWNER TO postgres;

--
-- Name: addr; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE TYPE udt_myint AS (myint INTEGER);

CREATE DOMAIN addr AS character varying(90) NOT NULL;
COMMENT ON DOMAIN addr IS 'my domain comments on addr';


ALTER DOMAIN addr OWNER TO postgres;

--
-- Name: addr2; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN addr2 AS character varying(90) NOT NULL DEFAULT 'N/A'::character varying;


ALTER DOMAIN addr2 OWNER TO postgres;

--
-- Name: addr3; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN addr3 AS character varying(90) NOT NULL DEFAULT 'N/A'::character varying
        CONSTRAINT addr3_check CHECK (((VALUE)::text > ''::text));


ALTER DOMAIN addr3 OWNER TO postgres;

--
-- Name: compfoo; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE compfoo AS (
        f1 integer,
        f2 text
);

COMMENT ON TYPE compfoo IS 'just a comment on compfoo type';

ALTER TYPE compfoo OWNER TO postgres;

--
-- Name: compfoo2; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE compfoo2 AS (
        x1 integer,
        x2 text
);


ALTER TYPE compfoo2 OWNER TO postgres;

--
-- Name: cycle_frequency; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE cycle_frequency AS ENUM (
    'WEEKLY',
    'MONTHLY',
    'QUARTERLY',
    'ANNUALLY'
);
ALTER TYPE cycle_frequency OWNER TO postgres;

CREATE TYPE banner_color AS ENUM ('green','blue','lightblue','purple','red','yellow','orange','grey','pink');
ALTER TYPE banner_color OWNER TO postgres;
--
-- Name: idx; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN idx AS integer NOT NULL
        CONSTRAINT idx_check CHECK (((VALUE > 100) AND (VALUE < 999)));


ALTER DOMAIN idx OWNER TO postgres;

--
-- Name: obj_type; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE obj_type AS ENUM (
    'TABLE',
    'VIEW',
    'COLUMN',
    'SEQUENCE',
    'FUNCTION',
    'SCHEMA',
    'DATABASE'
);


ALTER TYPE obj_type OWNER TO postgres;

--
-- Name: perm_type; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE perm_type AS ENUM (
    'SELECT',
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'REFERENCES',
    'TRIGGER',
    'USAGE',
    'CREATE',
    'EXECUTE',
    'CONNECT',
    'TEMPORARY'
);


ALTER TYPE perm_type OWNER TO postgres;

--
-- Name: us_postal_code; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN us_postal_code AS text NOT NULL
        CONSTRAINT us_postal_code_check CHECK (((VALUE ~ '^\d{5}$'::text) OR (VALUE ~ '^\d{5}-\d{4}$'::text)));


ALTER DOMAIN us_postal_code OWNER TO postgres;

CREATE AGGREGATE avg (float8)
(
    sfunc = float8_accum,
    stype = float8[],
    finalfunc = float8_avg,
    initcond = '{0,0,0}'
);

-- CREATE AGGREGATE array_accum (anyelement)
-- (
--     sfunc = array_append,
--     stype = anyarray,
--     initcond = '{}'
-- );

create function greaterint (int, int)
returns int language sql
as $$
    select case when $1 < $2 then $2 else $1 end
$$;

create function intplus10 (int)
returns int language sql
as $$
    select $1+ 10;
$$;

create aggregate incremented_max (int) (
    sfunc = greaterint,
    finalfunc = intplus10,
    stype = integer,
    initcond = 0
);


CREATE OR REPLACE FUNCTION database_principal_id()
RETURNS INTEGER
AS
$BODY$
DECLARE
ownerid  integer;
myint    udt_myint;
BEGIN
    SELECT U.oid into ownerid FROM pg_roles AS U JOIN pg_database AS D ON (D.datdba = U.oid) WHERE D.datname = current_database();	   
    RETURN ownerid;
END;
$BODY$
LANGUAGE  plpgsql;
                                                                             
                                                                              
CREATE FUNCTION aaa() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
  stmt  text;
BEGIN

stmt =
  $xxx$
  select n.nspname AS schemaname, t.typname AS typename, t.typcategory AS typcategory, t.typinput AS typinput, t.typstorage AS typstorage, CASE WHEN t.typcategory='C' THEN ''
  WHEN t.typcategory='E' THEN 'CREATE TYPE quote_ident(dest_schema).' || t.typname || ' AS ENUM (' || REPLACE(quote_literal(array_to_string(array_agg(e.enumlabel ORDER BY e.enumsortorder),',')), ',', ''',''') || ');'
  ELSE 'type category: ' || t.typcategory || ' not implemented yet' END AS enum_ddl FROM pg_type t JOIN pg_namespace n ON (n.oid = t.typnamespace)
  LEFT JOIN pg_enum e ON (t.oid = e.enumtypid) where n.nspname = quote_ident(source_schema) group by 1,2,3,4,5
  $xxx$;

RAISE NOTICE '%', stmt;

RETURN;
END;
$_$;

ALTER FUNCTION aaa() OWNER TO postgres;
COMMENT ON FUNCTION aaa() IS 'comment on my aaa() function';


--
-- Name: emp_stamp(); Type: FUNCTION; Schema: sample; Owner: postgres
--

CREATE FUNCTION emp_stamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        -- Check that empname and salary are given
        IF NEW.empname IS NULL THEN
            RAISE EXCEPTION 'empname cannot be null';
        END IF;
        IF NEW.salary IS NULL THEN
            RAISE EXCEPTION '% cannot have null salary', NEW.empname;
        END IF;

        -- Who works for us when she must pay for it?
        IF NEW.salary < 0 THEN
            RAISE EXCEPTION '% cannot have a negative salary', NEW.empname;
        END IF;

        -- Remember who changed the payroll when
        NEW.last_date := current_timestamp;
        NEW.last_user := current_user;
        RETURN NEW;
    END;
$$;

ALTER FUNCTION emp_stamp() OWNER TO postgres;

CREATE OR REPLACE FUNCTION fnsplitstring(IN par_string VARCHAR, IN par_delimiter CHAR)
RETURNS TABLE (splitdata VARCHAR)
AS
$BODY$
# variable_conflict use_column
DECLARE
    var_start INTEGER;
    var_end INTEGER;
BEGIN
    CREATE TEMPORARY TABLE IF NOT EXISTS fnsplitstring$tmptbl    (splitdata VARCHAR) ON COMMIT DELETE ROWS;
    SELECT 1, STRPOS(par_string, par_delimiter) INTO var_start, var_end;

    WHILE var_start < LENGTH(par_string) + 1 LOOP
        IF var_end = 0 THEN
            var_end := (LENGTH(par_string) + 1)::INT;
        END IF;
        INSERT INTO fnsplitstring$tmptbl (splitdata)
        VALUES (SUBSTR(par_string, var_start, var_end - var_start));
        var_start := (var_end + 1)::INT;
        var_end := aws_sqlserver_ext.STRPOS3(par_delimiter, par_string, var_start);
    END LOOP;
    RETURN QUERY (SELECT * FROM fnsplitstring$tmptbl);    
END;
$BODY$
LANGUAGE  plpgsql;
GRANT EXECUTE ON FUNCTION fnsplitstring(varchar, char) TO postgres;                                                                                                                            
                             
CREATE PROCEDURE get_userscans(IN aschema text, IN atable text, INOUT scans INTEGER) AS
$BODY$
BEGIN
-- Select seq_scan into scans FROM pg_stat_user_tables where schemaname = aschema and relname = atable;
Select seq_scan FROM pg_stat_user_tables where schemaname = aschema and relname = atable INTO scans;
RETURN;
END;
$BODY$
LANGUAGE plpgsql;
GRANT EXECUTE ON PROCEDURE get_userscans(text, text, integer) TO postgres;
COMMENT ON PROCEDURE get_userscans(text, text, integer) IS 'my comments on get_userscans procedure';

CREATE PROCEDURE get_userscans(IN aschema text, IN atable text, INOUT scans INTEGER, INOUT ok boolean) AS
$BODY$
BEGIN
-- Select seq_scan into scans FROM pg_stat_user_tables where schemaname = aschema and relname = atable;
Select seq_scan FROM pg_stat_user_tables where schemaname = aschema and relname = atable INTO scans;
ok := True;
RETURN;
END;
$BODY$
LANGUAGE plpgsql;
GRANT EXECUTE ON PROCEDURE get_userscans(text, text, integer, boolean) TO postgres;

CREATE OR REPLACE FUNCTION aaa(IN akey integer default 0)
RETURNS integer
AS
$BODY$
DECLARE
    var_start INTEGER;
    var_end INTEGER;
BEGIN
    Return 1;
END;
$BODY$
LANGUAGE  plpgsql;
GRANT EXECUTE ON FUNCTION aaa(IN akey integer) to PUBLIC;
COMMENT ON FUNCTION aaa(integer) IS 'comment on my aaa(int) function';

SET default_tablespace = '';

SET default_with_oids = false;


CREATE UNLOGGED TABLE myunloggedtbl (id integer PRIMARY KEY, val text NOT NULL) WITH (autovacuum_enabled = off);

CREATE table timestamptbl (akey int not null, color sample.banner_color, avalue text, tmstmp timestamptz NOT NULL, tmstmp_null timestamptz NULL,  tmstmp_null2 timestamp(0) with time zone);
INSERT INTO timestamptbl (akey, color, avalue, tmstmp, tmstmp_null, tmstmp_null2) VALUES (1,  'green', 'aaa', now(), now(), now());
INSERT INTO timestamptbl (akey, color, avalue, tmstmp ) VALUES (2, 'red', 'bbb', now());

CREATE TABLE numerics (
    id integer,
    anumeric numeric,
    anumeric2 numeric(1,0),
    anumeric3 numeric(1,1),
    anumeric4 numeric(25,0),
    anumeric5 numeric(25,0)
);
ALTER TABLE numerics OWNER TO postgres;

CREATE TABLE arrays (
    name            text,
    aarray1  integer[],
    aarray2  text[][],
    aarray3  text[3][3],
    aarray4  integer ARRAY[4],
    aarray5  integer ARRAY
);
ALTER TABLE numerics OWNER TO postgres;

--
-- Name: address; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE address (
    id bigint NOT NULL,
    id2 udt_myint,
    id3 udt_myint,
    addr text
);
COMMENT ON TABLE address IS 'This table is where I keep address info.';

INSERT INTO address OVERRIDING SYSTEM VALUE SELECT 1, '(1)', '(1)', 'text1';
INSERT INTO address OVERRIDING SYSTEM VALUE SELECT 2, '(2)', '(2)', 'text2';

ALTER TABLE address OWNER TO postgres;

--
-- Name: address_id_seq; Type: SEQUENCE; Schema: sample; Owner: postgres
--

ALTER TABLE address ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TYPE status AS ENUM ('Notconfirmed','Coming', 'Notcoming', 'Maycome');
CREATE TABLE statuses (id serial, s status default 'Notconfirmed');
COMMENT ON TABLE statuses IS 'This table is where I keep status info.';
INSERT INTO statuses Select 1, 'Coming';
INSERT INTO statuses Select 1, 'Notcoming';
INSERT INTO statuses Select 1, 'Maycome';

--
-- Name: emp; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE emp (
    empname text,
    salary integer,
    last_date timestamp without time zone,
    last_user text
);
COMMENT ON TABLE emp IS 'Employee info';
COMMENT ON COLUMN emp.salary IS 'Employee Salary info';
ALTER TABLE emp OWNER TO postgres;

INSERT INTO emp select 'michael', 100, current_timestamp, 'john';

--
-- Name: foo; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo (
    foo_id integer NOT NULL,
    foo_name character varying(10)
);

CREATE TABLE foo2 (
    foo_id integer NOT NULL,
    foo_name character varying(10)
);


ALTER TABLE foo OWNER TO postgres;
ALTER TABLE foo2 OWNER TO postgres;

CREATE RULE "_RETURN" AS ON SELECT TO foo DO INSTEAD SELECT * FROM foo2;
CREATE RULE notify_me AS ON UPDATE TO foo DO ALSO NOTIFY foo;

INSERT INTO foo  (foo_id, foo_name) VALUES(1,'haha');
INSERT INTO foo2 (foo_id, foo_name) VALUES(1,'hoho');

-- -----------------------------------------------
-- Create partitions the old way using inheritance
-- -----------------------------------------------
CREATE TABLE measurement (
    city_id         int not null,
    logdate         date not null,
    peaktemp        int,
    unitsales       int
);
CREATE TABLE measurement_y2006m02 (
    CHECK ( logdate >= DATE '2006-02-01' AND logdate < DATE '2006-03-01' )
) INHERITS (measurement);
CREATE TABLE measurement_y2006m03 (
    CHECK ( logdate >= DATE '2006-03-01' AND logdate < DATE '2006-04-01' )
) INHERITS (measurement);
CREATE TABLE measurement_y2022mAll (
    CHECK ( logdate >= DATE '2022-01-01' AND logdate < DATE '2022-12-31' )
) INHERITS (measurement);
CREATE INDEX measurement_y2006m02_logdate_ix ON measurement_y2006m02  (logdate);
CREATE INDEX measurement_y2006m03_logdate_ix ON measurement_y2006m03  (logdate);
CREATE INDEX measurement_y2022mAll_ix        ON measurement_y2022mAll (logdate);
CREATE OR REPLACE FUNCTION measurement_insert_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF ( NEW.logdate >= DATE '2006-02-01' AND
         NEW.logdate < DATE '2006-03-01' ) THEN
        INSERT INTO measurement_y2006m02 VALUES (NEW.*);
    ELSIF ( NEW.logdate >= DATE '2006-03-01' AND
            NEW.logdate < DATE '2006-04-01' ) THEN
        INSERT INTO measurement_y2006m03 VALUES (NEW.*);
    ELSIF ( NEW.logdate >= DATE '2022-01-01' AND
            NEW.logdate < DATE '2022-12-31' ) THEN
        INSERT INTO measurement_y2022mAll VALUES (NEW.*);        
    ELSE
        RAISE EXCEPTION 'Date out of range.  Fix the measurement_insert_trigger() function!';
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER insert_measurement_trigger
    BEFORE INSERT ON measurement
    FOR EACH ROW EXECUTE PROCEDURE measurement_insert_trigger();

INSERT INTO measurement SELECT 1, now(), 70, 100;
INSERT INTO measurement SELECT 1, now(), 80, 120;

--
-- Name: foo_bar_baz; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
)
PARTITION BY RANGE (foo_id);


ALTER TABLE foo_bar_baz OWNER TO postgres;
COMMENT ON TABLE foo_bar_baz IS 'just a comment on a partitioned table';

--
-- Name: foo_bar_baz_0; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz_0 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY foo_bar_baz ATTACH PARTITION foo_bar_baz_0 FOR VALUES FROM (0) TO (1);


ALTER TABLE foo_bar_baz_0 OWNER TO postgres;

--
-- Name: foo_bar_baz_1; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz_1 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY foo_bar_baz ATTACH PARTITION foo_bar_baz_1 FOR VALUES FROM (1) TO (2);


ALTER TABLE foo_bar_baz_1 OWNER TO postgres;

--
-- Name: foo_bar_baz_2; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz_2 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY foo_bar_baz ATTACH PARTITION foo_bar_baz_2 FOR VALUES FROM (2) TO (3);


ALTER TABLE foo_bar_baz_2 OWNER TO postgres;

--
-- Name: foo_bar_baz_3; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz_3 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY foo_bar_baz ATTACH PARTITION foo_bar_baz_3 FOR VALUES FROM (3) TO (4);


ALTER TABLE foo_bar_baz_3 OWNER TO postgres;

--
-- Name: foo_bar_baz_4; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz_4 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY foo_bar_baz ATTACH PARTITION foo_bar_baz_4 FOR VALUES FROM (4) TO (5);


ALTER TABLE foo_bar_baz_4 OWNER TO postgres;

--
-- Name: foo_bar_baz_5; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE foo_bar_baz_5 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY foo_bar_baz ATTACH PARTITION foo_bar_baz_5 FOR VALUES FROM (5) TO (6);
ALTER TABLE foo_bar_baz_5 OWNER TO postgres;

INSERT INTO foo_bar_baz SELECT 1, 1, 1;
INSERT INTO foo_bar_baz SELECT 2, 2, 2;
INSERT INTO foo_bar_baz SELECT 3, 3, 3;

--
-- Name: haha; Type: FOREIGN TABLE; Schema: sample; Owner: sysdba
--

CREATE FOREIGN TABLE haha (
    id integer NOT NULL,
    adate timestamp with time zone NOT NULL
)
SERVER my_foreign_server
OPTIONS (
    schema_name 'sample',
    table_name 'haha'
);
COMMENT ON FOREIGN TABLE haha IS 'just a comment on a foreign table';

ALTER FOREIGN TABLE haha OWNER TO sysdba;

--
-- Name: hoho; Type: MATERIALIZED VIEW; Schema: sample; Owner: postgres
--

CREATE MATERIALIZED VIEW hoho AS
 SELECT count(*) AS count
   FROM pg_stat_activity
  WITH NO DATA;
ALTER TABLE hoho OWNER TO postgres;
COMMENT ON MATERIALIZED VIEW hoho IS 'just a comment on the hoho materialized view';

CREATE MATERIALIZED VIEW mv_foo_bar_baz AS 
 SELECT count(*) as count
   FROM foo_bar_baz;
ALTER TABLE mv_foo_bar_baz OWNER TO postgres;

--
-- Name: hoho2; Type: VIEW; Schema: sample; Owner: postgres
--

CREATE VIEW hoho2 AS
 SELECT count(*) AS count
   FROM pg_stat_activity;
ALTER TABLE hoho2 OWNER TO postgres;

-- THIS WONT WORK UNTIL WE FIX dependency ORDERINGS
-- CREATE VIEW hoho3 AS
--  SELECT count(*) as count
--    FROM hoho2;
-- ALTER TABLE hoho3 OWNER TO postgres;   

--
-- Name: person; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE person (
    id bigint NOT NULL,
    firstname text NOT NULL,
    lastname text NOT NULL
);
ALTER TABLE person OWNER TO postgres;

ALTER TABLE person ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

INSERT into person OVERRIDING SYSTEM VALUE select 1, 'joe','shmoe';
INSERT into person OVERRIDING SYSTEM VALUE select 2, 'james','bond';
--
-- Name: sampletable; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sampletable (x numeric);
ALTER TABLE sampletable OWNER TO postgres;
CREATE VIEW v_sampletable AS Select * from sampletable;
COMMENT ON VIEW v_sampletable IS 'just a view on the sample table';
INSERT INTO sampletable SELECT 1.00;
INSERT INTO sampletable SELECT 2.00;

--
-- Name: seq111; Type: SEQUENCE; Schema: sample; Owner: postgres
--

CREATE SEQUENCE seq111
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
COMMENT ON SEQUENCE seq111 IS 'just a comment on seq111 sequence';    


ALTER TABLE seq111 OWNER TO postgres;

--
-- Name: test; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE test (
    major integer DEFAULT 2 NOT NULL,
    minor integer
);
ALTER TABLE test OWNER TO postgres;

INSERT INTO test SELECT 1,1;
INSERT INTO test SELECT 2,2;

--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_pkey PRIMARY KEY (id);


--
-- Name: foo_bar_baz foo_bar_baz_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz
    ADD CONSTRAINT foo_bar_baz_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_0 foo_bar_baz_0_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz_0
    ADD CONSTRAINT foo_bar_baz_0_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_1 foo_bar_baz_1_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz_1
    ADD CONSTRAINT foo_bar_baz_1_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_2 foo_bar_baz_2_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz_2
    ADD CONSTRAINT foo_bar_baz_2_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_3 foo_bar_baz_3_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz_3
    ADD CONSTRAINT foo_bar_baz_3_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_4 foo_bar_baz_4_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz_4
    ADD CONSTRAINT foo_bar_baz_4_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_5 foo_bar_baz_5_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY foo_bar_baz_5
    ADD CONSTRAINT foo_bar_baz_5_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: test test_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY test
    ADD CONSTRAINT test_pkey PRIMARY KEY (major);


--
-- Name: idx_x; Type: INDEX; Schema: sample; Owner: postgres
--

CREATE INDEX idx_x ON sampletable USING btree (x);
COMMENT ON INDEX idx_x IS 'just another btree index';


CREATE TABLE tablewithindexes(akey int, anum int, avalue text, 
                              CONSTRAINT pk_akey_anum PRIMARY KEY (akey,anum), 
                              CONSTRAINT uix_akey_anum UNIQUE (akey,anum));

CREATE TABLE t_site (
site_key integer NOT NULL,
initial_trip character varying(7) NOT NULL,
stn_code character varying(6) NULL,
area character varying(4) NULL,
stratum character varying(4) NULL,
lat integer NULL,
nors character varying(1) NULL,
long integer NULL,
eorw character varying(1) NULL,
site_type character varying(8) NULL,
dlat numeric(7,5) NULL,
dlon numeric(8,5) NULL,
position geometry NULL,
CONSTRAINT pk_t_site PRIMARY KEY (site_key),
CONSTRAINT ui_t_site UNIQUE (initial_trip, stn_code),
CONSTRAINT enforce_dims_geom CHECK ((st_ndims("position") = 2)),
CONSTRAINT enforce_geotype_geom CHECK (((geometrytype("position") = 'POINT'::text) OR ("position" IS NULL))),
CONSTRAINT enforce_srid_geom CHECK ((st_srid("position") = 4326))
) TABLESPACE pg_default;


--
-- Name: minor_idx; Type: INDEX; Schema: sample; Owner: postgres
--

CREATE INDEX minor_idx ON test USING btree (major, minor);
COMMENT ON INDEX minor_idx IS 'just another btree index';

--
-- Name: foo_bar_baz_0_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX foo_bar_baz_pkey ATTACH PARTITION foo_bar_baz_0_pkey;


--
-- Name: foo_bar_baz_1_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX foo_bar_baz_pkey ATTACH PARTITION foo_bar_baz_1_pkey;


--
-- Name: foo_bar_baz_2_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX foo_bar_baz_pkey ATTACH PARTITION foo_bar_baz_2_pkey;


--
-- Name: foo_bar_baz_3_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX foo_bar_baz_pkey ATTACH PARTITION foo_bar_baz_3_pkey;


--
-- Name: foo_bar_baz_4_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX foo_bar_baz_pkey ATTACH PARTITION foo_bar_baz_4_pkey;


--
-- Name: foo_bar_baz_5_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX foo_bar_baz_pkey ATTACH PARTITION foo_bar_baz_5_pkey;


--
-- Name: emp emp_stamp; Type: TRIGGER; Schema: sample; Owner: postgres
--

CREATE TRIGGER emp_stamp BEFORE INSERT OR UPDATE ON emp FOR EACH ROW EXECUTE PROCEDURE emp_stamp();


--
-- Name: address address_id_fkey; Type: FK CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_id_fkey FOREIGN KEY (id) REFERENCES person(id);


--
-- Name: SCHEMA sample; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA sample TO mydb_read;
GRANT ALL ON SCHEMA sample TO pg_stat_scan_tables;
GRANT ALL ON SCHEMA sample TO mydb_app;
GRANT ALL ON SCHEMA sample TO mydb_dev;
GRANT ALL ON SCHEMA sample TO mydb_owner;
GRANT ALL ON SCHEMA sample TO mydb_reader;
GRANT ALL ON SCHEMA sample TO mydb_update;
GRANT ALL ON SCHEMA sample TO pg_execute_server_program;
GRANT ALL ON SCHEMA sample TO pg_monitor;
GRANT ALL ON SCHEMA sample TO pg_read_all_settings;
GRANT ALL ON SCHEMA sample TO pg_read_all_stats;
GRANT ALL ON SCHEMA sample TO pg_read_server_files;
GRANT ALL ON SCHEMA sample TO pg_signal_backend;
GRANT ALL ON SCHEMA sample TO pg_write_server_files;


--
-- Name: FUNCTION aaa(); Type: ACL; Schema: sample; Owner: postgres
--

GRANT ALL ON FUNCTION aaa() TO mydb_update;


--
-- Name: FUNCTION emp_stamp(); Type: ACL; Schema: sample; Owner: postgres
--

GRANT ALL ON FUNCTION emp_stamp() TO mydb_update;


--
-- Name: TABLE emp; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE emp TO mydb_read;
GRANT ALL ON TABLE emp TO mydb_update;


--
-- Name: TABLE foo; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo TO mydb_read;
GRANT SELECT ON TABLE foo2 TO mydb_read;
GRANT ALL ON TABLE foo TO mydb_update;
GRANT ALL ON TABLE foo2 TO mydb_update;


--
-- Name: TABLE foo_bar_baz; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz TO mydb_update;


--
-- Name: TABLE foo_bar_baz_0; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz_0 TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz_0 TO mydb_update;

GRANT SELECT ON TABLE timestamptbl TO mydb_read;
GRANT ALL ON TABLE timestamptbl TO mydb_update;

--
-- Name: TABLE foo_bar_baz_1; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz_1 TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz_1 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_2; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz_2 TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz_2 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_3; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz_3 TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz_3 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_4; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz_4 TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz_4 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_5; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE foo_bar_baz_5 TO mydb_read;
GRANT ALL ON TABLE foo_bar_baz_5 TO mydb_update;


--
-- Name: TABLE haha; Type: ACL; Schema: sample; Owner: sysdba
--

GRANT SELECT ON TABLE haha TO mydb_dev;


--
-- Name: TABLE hoho; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE hoho TO mydb_dev;


--
-- Name: TABLE hoho2; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE hoho2 TO mydb_dev;


--
-- Name: TABLE sampletable; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sampletable TO mydb_read;
GRANT ALL ON TABLE sampletable TO mydb_update;


--
-- Name: SEQUENCE seq111; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT,UPDATE ON SEQUENCE seq111 TO mydb_dev;
GRANT SELECT,UPDATE ON SEQUENCE seq111 TO mydb_update;


--
-- Name: TABLE test; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE test TO mydb_read;
GRANT ALL ON TABLE test TO mydb_update;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: sample; Owner: mydb_owner
--
ALTER DEFAULT PRIVILEGES FOR ROLE mydb_owner IN SCHEMA sample GRANT ALL ON SEQUENCES TO mydb_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres   IN SCHEMA sample GRANT ALL ON SEQUENCES TO mydb_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE mydb_owner IN SCHEMA sample GRANT ALL ON SEQUENCES  TO mydb_update;                                                                                                                            

--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: sample; Owner: mydb_owner
--

ALTER DEFAULT PRIVILEGES FOR ROLE mydb_owner IN SCHEMA sample REVOKE ALL ON FUNCTIONS  FROM mydb_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE mydb_owner IN SCHEMA sample GRANT ALL ON FUNCTIONS  TO mydb_update;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: sample; Owner: mydb_read
--

ALTER DEFAULT PRIVILEGES FOR ROLE mydb_read IN SCHEMA sample REVOKE ALL ON TABLES  FROM mydb_read;
ALTER DEFAULT PRIVILEGES FOR ROLE mydb_read IN SCHEMA sample GRANT SELECT ON TABLES  TO mydb_read;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: sample; Owner: mydb_update
--

ALTER DEFAULT PRIVILEGES FOR ROLE mydb_update IN SCHEMA sample REVOKE ALL ON TABLES  FROM mydb_update;
ALTER DEFAULT PRIVILEGES FOR ROLE mydb_update IN SCHEMA sample GRANT INSERT,DELETE,UPDATE ON TABLES  TO mydb_update;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: sample; Owner: mydb_owner
--

ALTER DEFAULT PRIVILEGES FOR ROLE mydb_owner IN SCHEMA sample REVOKE ALL ON TABLES  FROM mydb_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE mydb_owner IN SCHEMA sample GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLES  TO mydb_update;


-- RLS and policies. See pg_policies;  https://www.postgresql.org/docs/current/ddl-rowsecurity.html
DROP ROLE IF EXISTS managers;
DROP ROLE IF EXISTS users;
DROP ROLE IF EXISTS admin;
DROP ROLE IF EXISTS bob;
DROP ROLE IF EXISTS alice;

CREATE ROLE managers;
CREATE ROLE users;

CREATE TABLE groups (group_id int PRIMARY KEY, group_name text NOT NULL);
INSERT INTO groups VALUES (1, 'low'), (2, 'medium'), (5, 'high');
CREATE TABLE users (user_name text PRIMARY KEY, group_id int NOT NULL REFERENCES groups);
INSERT INTO users VALUES ('alice', 5), ('bob', 2), ('mallory', 2);
CREATE TABLE accounts (manager text, company text, contact_email text);
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
INSERT INTO accounts SELECT 'admin','Sears','joe@sears.com';

CREATE TABLE information (info text, group_id int NOT NULL REFERENCES groups);
INSERT INTO information VALUES ('barely secret', 1), ('slightly secret', 2), ('very secret', 5);

CREATE POLICY account_managers ON accounts TO managers  USING (manager = current_user);
COMMENT ON POLICY account_managers ON ACCOUNTS IS 'my comments on account_managers policy';
CREATE POLICY user_policy ON users USING (user_name = current_user);

CREATE POLICY user_sel_policy ON users FOR SELECT USING (true);
CREATE POLICY user_mod_policy ON users USING (user_name = current_user);
CREATE TABLE passwd (
  user_name             text UNIQUE NOT NULL,
  pwhash                text,
  uid                   int  PRIMARY KEY,
  gid                   int  NOT NULL,
  real_name             text NOT NULL,
  home_phone            text,
  extra_info            text,
  home_dir              text NOT NULL,
  shell                 text NOT NULL
);
CREATE ROLE admin;  -- Administrator
CREATE ROLE bob;    -- Normal user
CREATE ROLE alice;  -- Normal user

INSERT INTO passwd VALUES ('admin','xxx',0,0,'Admin','111-222-3333',null,'/root','/bin/dash');
INSERT INTO passwd VALUES ('bob','xxx',1,1,'Bob','123-456-7890',null,'/home/bob','/bin/zsh');
INSERT INTO passwd VALUES ('alice','xxx',2,1,'Alice','098-765-4321',null,'/home/alice','/bin/zsh');

ALTER TABLE passwd ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_all ON passwd TO admin USING (true) WITH CHECK (true);
CREATE POLICY all_view ON passwd FOR SELECT USING (true);
CREATE POLICY user_mod ON passwd FOR UPDATE USING (current_user = user_name) WITH CHECK (current_user = user_name AND shell IN ('/bin/bash','/bin/sh','/bin/dash','/bin/zsh','/bin/tcsh'));

GRANT SELECT, INSERT, UPDATE, DELETE ON passwd TO admin;
GRANT SELECT (user_name, uid, gid, real_name, home_phone, extra_info, home_dir, shell) ON passwd TO public;
GRANT UPDATE (pwhash, real_name, home_phone, extra_info, shell) ON passwd TO public;

CREATE POLICY admin_local_only ON passwd AS RESTRICTIVE TO admin USING (pg_catalog.inet_client_addr() IS NULL);

GRANT ALL ON groups TO alice;  -- alice is the administrator
GRANT SELECT ON groups TO public;

GRANT ALL ON users TO alice;
GRANT SELECT ON users TO public;

ALTER TABLE information ENABLE ROW LEVEL SECURITY;

CREATE POLICY fp_s ON information FOR SELECT USING (group_id <= (SELECT group_id FROM users WHERE user_name = current_user));
CREATE POLICY fp_u ON information FOR UPDATE USING (group_id <= (SELECT group_id FROM users WHERE user_name = current_user));

GRANT ALL ON information TO public;

-- -----------------------------
-- Create case-sensitive objects
-- -----------------------------
CREATE TABLE "CaseSensitive" ("ID" integer, "aValue" text);
ALTER TABLE "CaseSensitive" OWNER TO postgres;
CREATE VIEW "CaseSensitiveView" AS SELECT * FROM "CaseSensitive";
CREATE SEQUENCE "CaseSensitive_ID_seq" START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER TABLE "CaseSensitive_ID_seq" OWNER TO postgres;
COMMENT ON TABLE "CaseSensitive" IS 'just a comment on the CaseSensitive table';    
ALTER SEQUENCE "CaseSensitive_ID_seq" OWNED BY "CaseSensitive"."ID";
ALTER TABLE ONLY "CaseSensitive" ALTER COLUMN "ID" SET DEFAULT nextval('"CaseSensitive_ID_seq"'::regclass);
ALTER TABLE ONLY "CaseSensitive" ADD CONSTRAINT "CaseSensitive_pkey" PRIMARY KEY ("ID");
COMMENT ON SEQUENCE "CaseSensitive_ID_seq" IS 'just a comment on CaseSensitive sequence';    
CREATE INDEX "CaseSensitive_aValue_ix" ON "CaseSensitive" ("aValue");
GRANT SELECT, UPDATE, DELETE ON "CaseSensitive" TO public;
GRANT SELECT,UPDATE ON SEQUENCE "CaseSensitive_ID_seq" TO public;
CREATE FUNCTION "CaseSensitiveFunc" (int, int)
returns int language sql
as $$
    select case when $1 < $2 then $2 else $1 end
$$;
GRANT EXECUTE ON FUNCTION "CaseSensitiveFunc" (int, int) TO postgres;                                                                                                                            
CREATE POLICY "All_View" ON "CaseSensitive" FOR SELECT USING (true);
CREATE COLLATION "Frenchie" (provider = icu, locale = 'fr');
COMMENT ON COLLATION "Frenchie" IS 'my comments on "Frenchie" collation';
CREATE DOMAIN "Addr2" AS character varying(90) NOT NULL;
COMMENT ON DOMAIN "Addr2" IS 'my domain comments on "Addr2"';
CREATE TYPE "CompFoo3" AS (x1 integer,x2 text);

-- --------------------
-- Create PostGIS table
-- --------------------
CREATE TABLE geometries (name varchar, geom geometry);

INSERT INTO geometries VALUES
  ('Point', 'POINT(0 0)'),
  ('Linestring', 'LINESTRING(0 0, 1 1, 2 1, 2 2)'),
  ('Polygon', 'POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))'),
  ('PolygonWithHole', 'POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(1 1, 1 2, 2 2, 2 1, 1 1))'),
  ('Collection', 'GEOMETRYCOLLECTION(POINT(2 0),POLYGON((0 0, 1 0, 1 1, 0 1, 0 0)))');

-- SELECT name, ST_AsText(geom) FROM geometries;
 

CREATE TABLE Students (
  Id INTEGER PRIMARY KEY,
  FirstName VARCHAR(50),
  LastName VARCHAR(50),
  FullName VARCHAR(101) GENERATED ALWAYS AS (FirstName || ' ' || LastName) STORED
); 
INSERT INTO Students (Id, FirstName, LastName) VALUES (0001, 'Lucy', 'Green');
INSERT INTO Students (Id, FirstName, LastName) VALUES (0002, 'Aziz', 'Ahmad');
INSERT INTO Students (Id, FirstName, LastName) VALUES (0003, 'Zohan', 'Ahuja');
INSERT INTO Students (Id, FirstName, LastName) VALUES (0004, 'Homer', 'Presley');
INSERT INTO Students (Id, FirstName, LastName) VALUES (0005, 'Sally', 'Smith');

-- Create table with citext:
CREATE TABLE citextusers (nick CITEXT PRIMARY KEY, pass TEXT   NOT NULL);
INSERT INTO citextusers VALUES ( 'larry',  sha256(random()::text::bytea) );
INSERT INTO citextusers VALUES ( 'Tom',    sha256(random()::text::bytea) );
INSERT INTO citextusers VALUES ( 'Damian', sha256(random()::text::bytea) );
INSERT INTO citextusers VALUES ( 'NEAL',   sha256(random()::text::bytea) );
INSERT INTO citextusers VALUES ( 'Bjørn',  sha256(random()::text::bytea) );
-- SELECT * FROM citextusers WHERE nick = 'Larry';

                                                                                                                            
--
-- End Sample database
--

                                                                                                                                                                                                                                                                                                                                                                                 
