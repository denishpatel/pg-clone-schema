--
-- Sample database
--


-- drop/create clone schema database
drop database if exists clone_testing;
create database clone_testing;
\connect clone_testing;

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

-- set global stuff: 

-- don't worry if roles already exist, since they are cluster-wide, not just database-wide
CREATE ROLE iodb_admin;
ALTER ROLE iodb_admin WITH SUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md5f0d8c0ad9329be789034a8f6fda63d97';
CREATE ROLE iodb_app;
ALTER ROLE iodb_app WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md56145cfc4b8d0620b81cd224e153a0200';
CREATE ROLE iodb_dev;
ALTER ROLE iodb_dev WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md55fb5893f7091e85194823cea292f57a6';
CREATE ROLE iodb_owner;
ALTER ROLE iodb_owner WITH NOSUPERUSER INHERIT CREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE iodb_read;
ALTER ROLE iodb_read WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE iodb_reader;
ALTER ROLE iodb_reader WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md521b8b06eca27bb96e28c5e88462db2a6';
CREATE ROLE iodb_update;
ALTER ROLE iodb_update WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
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
CREATE ROLE myuser1;
ALTER ROLE myuser1 WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md53c769cae3570d6ed52d58c5fdfd5a1e0';
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'md54182a4fed857c8024598a0b0fe47fcb7';
CREATE ROLE readonly;
ALTER ROLE readonly WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE sysdba;
ALTER ROLE sysdba WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION NOBYPASSRLS PASSWORD 'md54f2192d28c96b5e38d4553264cb2f448';
ALTER ROLE iodb_admin SET search_path TO 'io';
ALTER ROLE iodb_app SET search_path TO 'io';
ALTER ROLE iodb_dev SET search_path TO 'io';
ALTER ROLE iodb_read SET search_path TO 'io';
ALTER ROLE iodb_reader SET search_path TO 'io';
ALTER ROLE iodb_update SET search_path TO 'io';
ALTER ROLE mydb_admin SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_app SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_dev SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_read SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_reader SET search_path TO 'public, pg_catalog';
ALTER ROLE mydb_update SET search_path TO 'public, pg_catalog';
ALTER ROLE myuser1 SET search_path TO 't3';
ALTER ROLE readonly SET search_path TO 't3';

-- Role memberships
GRANT iodb_owner TO iodb_admin GRANTED BY postgres;
GRANT iodb_read TO iodb_app GRANTED BY iodb_owner;
GRANT iodb_read TO iodb_dev GRANTED BY iodb_owner;
GRANT iodb_read TO iodb_owner GRANTED BY postgres;
GRANT iodb_read TO iodb_reader GRANTED BY iodb_owner;
GRANT iodb_read TO iodb_update GRANTED BY iodb_owner;
GRANT iodb_update TO iodb_app GRANTED BY iodb_owner;
GRANT iodb_update TO iodb_dev GRANTED BY iodb_owner;
GRANT iodb_update TO iodb_owner GRANTED BY postgres;
GRANT mydb_owner TO mydb_admin GRANTED BY postgres;
GRANT mydb_read TO mydb_app GRANTED BY mydb_owner;
GRANT mydb_read TO mydb_dev GRANTED BY mydb_owner;
GRANT mydb_read TO mydb_owner GRANTED BY postgres;
GRANT mydb_read TO mydb_reader GRANTED BY mydb_owner;
GRANT mydb_read TO mydb_update GRANTED BY mydb_owner;
GRANT mydb_update TO mydb_app GRANTED BY mydb_owner;
GRANT mydb_update TO mydb_dev GRANTED BY mydb_owner;
GRANT mydb_update TO mydb_owner GRANTED BY postgres;
GRANT readonly TO myuser1 GRANTED BY postgres;

-- end of global stuff

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


ALTER SCHEMA sample OWNER TO postgres;

--
-- Name: SCHEMA sample; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA sample IS 'standard sample schema';


--
-- Name: de-u-co-phonebk-x-icu; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION sample."de-u-co-phonebk-x-icu" (provider = icu, locale = 'de-u-co-phonebk');


ALTER COLLATION sample."de-u-co-phonebk-x-icu" OWNER TO postgres;

--
-- Name: french; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION sample.french (provider = icu, locale = 'fr');


ALTER COLLATION sample.french OWNER TO postgres;

--
-- Name: german_phonebook; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION sample.german_phonebook (provider = icu, locale = 'de-u-co-phonebk');


ALTER COLLATION sample.german_phonebook OWNER TO postgres;

--
-- Name: und-u-co-emoji-x-icu; Type: COLLATION; Schema: sample; Owner: postgres
--

CREATE COLLATION sample."und-u-co-emoji-x-icu" (provider = icu, locale = 'und-u-co-emoji');


ALTER COLLATION sample."und-u-co-emoji-x-icu" OWNER TO postgres;

--
-- Name: addr; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN sample.addr AS character varying(90) NOT NULL;


ALTER DOMAIN sample.addr OWNER TO postgres;

--
-- Name: addr2; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN sample.addr2 AS character varying(90) NOT NULL DEFAULT 'N/A'::character varying;


ALTER DOMAIN sample.addr2 OWNER TO postgres;

--
-- Name: addr3; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN sample.addr3 AS character varying(90) NOT NULL DEFAULT 'N/A'::character varying
        CONSTRAINT addr3_check CHECK (((VALUE)::text > ''::text));


ALTER DOMAIN sample.addr3 OWNER TO postgres;

--
-- Name: compfoo; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE sample.compfoo AS (
        f1 integer,
        f2 text
);


ALTER TYPE sample.compfoo OWNER TO postgres;

--
-- Name: compfoo2; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE sample.compfoo2 AS (
        x1 integer,
        x2 text
);


ALTER TYPE sample.compfoo2 OWNER TO postgres;

--
-- Name: cycle_frequency; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE sample.cycle_frequency AS ENUM (
    'WEEKLY',
    'MONTHLY',
    'QUARTERLY',
    'ANNUALLY'
);


ALTER TYPE sample.cycle_frequency OWNER TO postgres;

--
-- Name: idx; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN sample.idx AS integer NOT NULL
        CONSTRAINT idx_check CHECK (((VALUE > 100) AND (VALUE < 999)));


ALTER DOMAIN sample.idx OWNER TO postgres;

--
-- Name: obj_type; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE sample.obj_type AS ENUM (
    'TABLE',
    'VIEW',
    'COLUMN',
    'SEQUENCE',
    'FUNCTION',
    'SCHEMA',
    'DATABASE'
);


ALTER TYPE sample.obj_type OWNER TO postgres;

--
-- Name: perm_type; Type: TYPE; Schema: sample; Owner: postgres
--

CREATE TYPE sample.perm_type AS ENUM (
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


ALTER TYPE sample.perm_type OWNER TO postgres;

--
-- Name: us_postal_code; Type: DOMAIN; Schema: sample; Owner: postgres
--

CREATE DOMAIN sample.us_postal_code AS text NOT NULL
        CONSTRAINT us_postal_code_check CHECK (((VALUE ~ '^\d{5}$'::text) OR (VALUE ~ '^\d{5}-\d{4}$'::text)));


ALTER DOMAIN sample.us_postal_code OWNER TO postgres;

--
-- Name: aaa(); Type: FUNCTION; Schema: sample; Owner: postgres
--

CREATE FUNCTION sample.aaa() RETURNS void
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


ALTER FUNCTION sample.aaa() OWNER TO postgres;


--
-- Name: emp_stamp(); Type: FUNCTION; Schema: sample; Owner: postgres
--

CREATE FUNCTION sample.emp_stamp() RETURNS trigger
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


ALTER FUNCTION sample.emp_stamp() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: address; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.address (
    id bigint NOT NULL,
    addr text
);


ALTER TABLE sample.address OWNER TO postgres;

--
-- Name: address_id_seq; Type: SEQUENCE; Schema: sample; Owner: postgres
--

ALTER TABLE sample.address ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sample.address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: emp; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.emp (
    empname text,
    salary integer,
    last_date timestamp without time zone,
    last_user text
);


ALTER TABLE sample.emp OWNER TO postgres;

--
-- Name: foo; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo (
    foo_id integer NOT NULL,
    foo_name character varying(10)
);


ALTER TABLE sample.foo OWNER TO postgres;

--
-- Name: foo_bar_baz; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
)
PARTITION BY RANGE (foo_id);


ALTER TABLE sample.foo_bar_baz OWNER TO postgres;

--
-- Name: foo_bar_baz_0; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz_0 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY sample.foo_bar_baz ATTACH PARTITION sample.foo_bar_baz_0 FOR VALUES FROM (0) TO (1);


ALTER TABLE sample.foo_bar_baz_0 OWNER TO postgres;

--
-- Name: foo_bar_baz_1; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz_1 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY sample.foo_bar_baz ATTACH PARTITION sample.foo_bar_baz_1 FOR VALUES FROM (1) TO (2);


ALTER TABLE sample.foo_bar_baz_1 OWNER TO postgres;

--
-- Name: foo_bar_baz_2; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz_2 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY sample.foo_bar_baz ATTACH PARTITION sample.foo_bar_baz_2 FOR VALUES FROM (2) TO (3);


ALTER TABLE sample.foo_bar_baz_2 OWNER TO postgres;

--
-- Name: foo_bar_baz_3; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz_3 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY sample.foo_bar_baz ATTACH PARTITION sample.foo_bar_baz_3 FOR VALUES FROM (3) TO (4);


ALTER TABLE sample.foo_bar_baz_3 OWNER TO postgres;

--
-- Name: foo_bar_baz_4; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz_4 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY sample.foo_bar_baz ATTACH PARTITION sample.foo_bar_baz_4 FOR VALUES FROM (4) TO (5);


ALTER TABLE sample.foo_bar_baz_4 OWNER TO postgres;

--
-- Name: foo_bar_baz_5; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.foo_bar_baz_5 (
    foo_id integer NOT NULL,
    bar_id integer NOT NULL,
    baz integer NOT NULL
);
ALTER TABLE ONLY sample.foo_bar_baz ATTACH PARTITION sample.foo_bar_baz_5 FOR VALUES FROM (5) TO (6);


ALTER TABLE sample.foo_bar_baz_5 OWNER TO postgres;

--
-- Name: haha; Type: FOREIGN TABLE; Schema: sample; Owner: sysdba
--

CREATE FOREIGN TABLE sample.haha (
    id integer NOT NULL,
    adate timestamp with time zone NOT NULL
)
SERVER my_foreign_server
OPTIONS (
    schema_name 'sample',
    table_name 'haha'
);


ALTER FOREIGN TABLE sample.haha OWNER TO sysdba;

--
-- Name: hoho; Type: MATERIALIZED VIEW; Schema: sample; Owner: postgres
--

CREATE MATERIALIZED VIEW sample.hoho AS
 SELECT count(*) AS count
   FROM pg_stat_activity
  WITH NO DATA;


ALTER TABLE sample.hoho OWNER TO postgres;

--
-- Name: hoho2; Type: VIEW; Schema: sample; Owner: postgres
--

CREATE VIEW sample.hoho2 AS
 SELECT count(*) AS count
   FROM pg_stat_activity;


ALTER TABLE sample.hoho2 OWNER TO postgres;

--
-- Name: person; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.person (
    id bigint NOT NULL,
    firstname text NOT NULL,
    lastname text NOT NULL
);


ALTER TABLE sample.person OWNER TO postgres;

--
-- Name: person_id_seq; Type: SEQUENCE; Schema: sample; Owner: postgres
--

ALTER TABLE sample.person ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sample.person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sampletable; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.sampletable (
    x numeric
);


ALTER TABLE sample.sampletable OWNER TO postgres;

--
-- Name: seq111; Type: SEQUENCE; Schema: sample; Owner: postgres
--

CREATE SEQUENCE sample.seq111
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sample.seq111 OWNER TO postgres;

--
-- Name: test; Type: TABLE; Schema: sample; Owner: postgres
--

CREATE TABLE sample.test (
    major integer DEFAULT 2 NOT NULL,
    minor integer
);


ALTER TABLE sample.test OWNER TO postgres;

--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (id);


--
-- Name: foo_bar_baz foo_bar_baz_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz
    ADD CONSTRAINT foo_bar_baz_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_0 foo_bar_baz_0_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz_0
    ADD CONSTRAINT foo_bar_baz_0_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_1 foo_bar_baz_1_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz_1
    ADD CONSTRAINT foo_bar_baz_1_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_2 foo_bar_baz_2_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz_2
    ADD CONSTRAINT foo_bar_baz_2_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_3 foo_bar_baz_3_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz_3
    ADD CONSTRAINT foo_bar_baz_3_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_4 foo_bar_baz_4_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz_4
    ADD CONSTRAINT foo_bar_baz_4_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: foo_bar_baz_5 foo_bar_baz_5_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.foo_bar_baz_5
    ADD CONSTRAINT foo_bar_baz_5_pkey PRIMARY KEY (foo_id, bar_id, baz);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: test test_pkey; Type: CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.test
    ADD CONSTRAINT test_pkey PRIMARY KEY (major);


--
-- Name: idx_x; Type: INDEX; Schema: sample; Owner: postgres
--

CREATE INDEX idx_x ON sample.sampletable USING btree (x);


--
-- Name: minor_idx; Type: INDEX; Schema: sample; Owner: postgres
--

CREATE INDEX minor_idx ON sample.test USING btree (major, minor);


--
-- Name: foo_bar_baz_0_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX sample.foo_bar_baz_pkey ATTACH PARTITION sample.foo_bar_baz_0_pkey;


--
-- Name: foo_bar_baz_1_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX sample.foo_bar_baz_pkey ATTACH PARTITION sample.foo_bar_baz_1_pkey;


--
-- Name: foo_bar_baz_2_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX sample.foo_bar_baz_pkey ATTACH PARTITION sample.foo_bar_baz_2_pkey;


--
-- Name: foo_bar_baz_3_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX sample.foo_bar_baz_pkey ATTACH PARTITION sample.foo_bar_baz_3_pkey;


--
-- Name: foo_bar_baz_4_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX sample.foo_bar_baz_pkey ATTACH PARTITION sample.foo_bar_baz_4_pkey;


--
-- Name: foo_bar_baz_5_pkey; Type: INDEX ATTACH; Schema: sample; Owner:
--

ALTER INDEX sample.foo_bar_baz_pkey ATTACH PARTITION sample.foo_bar_baz_5_pkey;


--
-- Name: emp emp_stamp; Type: TRIGGER; Schema: sample; Owner: postgres
--

CREATE TRIGGER emp_stamp BEFORE INSERT OR UPDATE ON sample.emp FOR EACH ROW EXECUTE PROCEDURE sample.emp_stamp();


--
-- Name: address address_id_fkey; Type: FK CONSTRAINT; Schema: sample; Owner: postgres
--

ALTER TABLE ONLY sample.address
    ADD CONSTRAINT address_id_fkey FOREIGN KEY (id) REFERENCES sample.person(id);


--
-- Name: SCHEMA sample; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA sample TO mydb_read;
GRANT ALL ON SCHEMA sample TO pg_stat_scan_tables;
GRANT ALL ON SCHEMA sample TO iodb_app;
GRANT ALL ON SCHEMA sample TO iodb_dev;
GRANT ALL ON SCHEMA sample TO iodb_owner;
GRANT ALL ON SCHEMA sample TO iodb_read;
GRANT ALL ON SCHEMA sample TO iodb_reader;
GRANT ALL ON SCHEMA sample TO iodb_update;
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

GRANT ALL ON FUNCTION sample.aaa() TO mydb_update;


--
-- Name: FUNCTION emp_stamp(); Type: ACL; Schema: sample; Owner: postgres
--

GRANT ALL ON FUNCTION sample.emp_stamp() TO mydb_update;


--
-- Name: TABLE emp; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.emp TO mydb_read;
GRANT ALL ON TABLE sample.emp TO mydb_update;


--
-- Name: TABLE foo; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo TO mydb_read;
GRANT ALL ON TABLE sample.foo TO mydb_update;


--
-- Name: TABLE foo_bar_baz; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz TO mydb_update;


--
-- Name: TABLE foo_bar_baz_0; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz_0 TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz_0 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_1; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz_1 TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz_1 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_2; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz_2 TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz_2 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_3; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz_3 TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz_3 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_4; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz_4 TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz_4 TO mydb_update;


--
-- Name: TABLE foo_bar_baz_5; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.foo_bar_baz_5 TO mydb_read;
GRANT ALL ON TABLE sample.foo_bar_baz_5 TO mydb_update;


--
-- Name: TABLE haha; Type: ACL; Schema: sample; Owner: sysdba
--

GRANT SELECT ON TABLE sample.haha TO mydb_dev;


--
-- Name: TABLE hoho; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.hoho TO mydb_dev;


--
-- Name: TABLE hoho2; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.hoho2 TO mydb_dev;


--
-- Name: TABLE sampletable; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.sampletable TO mydb_read;
GRANT ALL ON TABLE sample.sampletable TO mydb_update;


--
-- Name: SEQUENCE seq111; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT,UPDATE ON SEQUENCE sample.seq111 TO mydb_dev;
GRANT SELECT,UPDATE ON SEQUENCE sample.seq111 TO mydb_update;


--
-- Name: TABLE test; Type: ACL; Schema: sample; Owner: postgres
--

GRANT SELECT ON TABLE sample.test TO mydb_read;
GRANT ALL ON TABLE sample.test TO mydb_update;


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

-- add some data
set search_path = 'sample';

COPY person (id, firstname, lastname) FROM stdin;
1       john    doe
2       mike    smith
\.


COPY address (id, addr) FROM stdin;
1       1234 whatever st., Reno, NV
\.


COPY emp (empname, salary, last_date, last_user) FROM stdin;
Post Gres       100     2019-10-09 07:43:21.579145      postgres
\.


COPY foo (foo_id, foo_name) FROM stdin;
1       eeny
2       meeny
3       miny
4       moe
5       tiger
6       toe
\.


COPY foo_bar_baz_0 (foo_id, bar_id, baz) FROM stdin;
\.
                                                                                                                            
COPY foo_bar_baz_1 (foo_id, bar_id, baz) FROM stdin;
1       9       1
1       32      1
1       44      1
1       48      1
1       57      1
1       61      1
1       84      1
1       86      1
1       110     1
1       112     1
1       114     1
1       115     1
1       117     1
1       127     1
1       131     1
1       152     1
1       156     1
1       161     1
1       164     1
1       166     1
1       170     1
1       185     1
1       187     1
1       194     1
1       197     1
1       205     1
1       217     1
1       219     1
1       226     1
1       238     1
1       242     1
1       249     1
1       253     1
1       255     1
1       292     1
1       305     1
1       306     1
1       310     1
1       318     1
1       324     1
1       332     1
1       347     1
1       358     1
1       362     1
1       377     1
1       388     1
\.
                                                                                                                            
COPY foo_bar_baz_2 (foo_id, bar_id, baz) FROM stdin;
2       0       2
2       1       2
2       3       2
2       4       2
2       7       2
2       11      2
2       14      2
2       16      2
2       19      2
2       20      2
2       22      2
2       24      2
2       26      2
2       27      2
2       28      2
2       30      2
2       36      2
2       41      2
2       42      2
2       46      2
2       51      2
2       56      2
2       66      2
2       72      2
2       75      2
2       77      2
2       81      2
2       83      2
2       87      2
2       91      2
2       94      2
2       96      2
2       99      2
2       100     2
2       101     2
2       104     2
2       116     2
2       118     2
2       121     2
2       122     2
2       125     2
2       129     2
2       130     2
2       138     2
2       142     2
2       144     2
2       145     2
2       148     2
2       151     2
2       154     2
2       163     2
2       173     2
2       174     2
2       175     2
2       176     2
2       181     2
\.
                                                                                                                            
COPY foo_bar_baz_3 (foo_id, bar_id, baz) FROM stdin;
3       2       3
3       8       3
3       17      3
3       18      3
3       23      3
3       25      3
3       31      3
3       34      3
3       35      3
3       37      3
3       40      3
3       43      3
3       45      3
3       47      3
3       50      3
3       52      3
3       59      3
3       65      3
3       71      3
3       76      3
3       79      3
3       85      3
3       88      3
3       97      3
3       98      3
3       103     3
3       126     3
3       132     3
3       136     3
3       139     3
3       140     3
3       141     3
3       143     3
3       146     3
3       147     3
3       150     3
3       167     3
3       168     3
3       169     3
3       179     3
3       189     3
3       196     3
3       200     3
3       203     3
3       204     3
3       206     3
3       209     3
3       210     3
\.

COPY foo_bar_baz_4 (foo_id, bar_id, baz) FROM stdin;
4       5       4
4       10      4
4       12      4
4       13      4
4       15      4
4       21      4
4       29      4
4       33      4
4       38      4
4       39      4
4       49      4
4       53      4
4       54      4
4       55      4
4       60      4
4       63      4
4       64      4
4       70      4
4       78      4
4       80      4
4       82      4
4       90      4
4       93      4
4       95      4
4       102     4
4       105     4
4       107     4
4       108     4
4       109     4
\.

COPY foo_bar_baz_5 (foo_id, bar_id, baz) FROM stdin;
5       6       5
5       58      5
5       62      5
5       67      5
5       68      5
5       69      5
5       73      5
5       74      5
5       89      5
5       92      5
5       106     5
5       120     5
5       123     5
5       133     5
5       149     5
5       158     5
5       160     5
5       162     5
5       172     5
5       184     5
5       199     5
5       227     5
5       228     5
\.
                                                                                                                            
--
-- End Sample database
--

                                                                                                                            
                                                                                                                            
                                                                                                                            
