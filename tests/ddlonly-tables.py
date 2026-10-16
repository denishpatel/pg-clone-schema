"""Install clone_schema.sql, then run with psycopg2 and an explicit disposable DB DSN.

python tests/ddlonly-tables.py 'host=127.0.0.1 port=PORT user=TEST_ROLE dbname=TEST_DB'
Fixture schema names must not already exist. All changes are rolled back.
"""
import sys

import psycopg2


def main(dsn):
    connection = psycopg2.connect(dsn)
    try:
        cursor = connection.cursor()
        cursor.execute("SET LOCAL statement_timeout = '15s'")
        cursor.execute("CREATE SCHEMA ddl_tables_src")
        cursor.execute("CREATE TABLE ddl_tables_src.items (id serial PRIMARY KEY, name text)")
        cursor.execute("INSERT INTO ddl_tables_src.items(name) VALUES ('tiny')")
        cursor.execute("CREATE FUNCTION ddl_tables_src.plus_one(i integer) RETURNS integer LANGUAGE sql AS 'SELECT i+1'")
        for target, options in (
            ("ddl_tables_default", "'DDLONLY'"),
            ("ddl_tables_noacl", "'DDLONLY','NOOWNER','NOACL'"),
            ("ddl_tables_debug", "'DDLONLY','DEBUGEXEC'"),
        ):
            connection.notices = []
            cursor.execute(
                "SELECT public.clone_schema('ddl_tables_src', %s, " + options + ")",
                (target,),
            )
            assert cursor.fetchone() == (0,)
            ddl = "\n".join(n[7:] for n in connection.notices if n.startswith("INFO:  "))
            assert "CREATE TABLE " + target + ".items " in ddl, ddl
            cursor.execute(ddl)
            cursor.execute("INSERT INTO " + target + ".items(name) VALUES ('next') RETURNING id")
            assert cursor.fetchone() == (2,)
            cursor.execute("SELECT count(*) FROM " + target + ".items")
            assert cursor.fetchone() == (1,)
            cursor.execute("SELECT " + target + ".plus_one(2)")
            assert cursor.fetchone() == (3,)
        print("DDLONLY default, NOOWNER/NOACL, and DEBUGEXEC replay passed")
    finally:
        connection.rollback()
        connection.close()


if __name__ == "__main__":
    main(sys.argv[1])
