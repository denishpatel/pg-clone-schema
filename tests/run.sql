\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '60s';
\ir ../clone_schema.sql
\ir composite_type_bindings.sql
ROLLBACK;