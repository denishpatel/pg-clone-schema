# pg-clone-schema

Handles following objects:

* Tables - structure (indexes and keys) and optionally, data
* Views
* Materialized Views - Structure and data
* Sequences
* Functions/Procedures
* Types (composite and enum)
* Collations and Domains
* Triggers
* Permissions/GRANTs

<br/>
<br/>

Arguments:
* source schema
* target schema
* clone with data
* only generate DDL

You can call function like this to copy schema with data:
<br/>
>select clone_schema('development', 'development_clone', true, false);
<br/>

Alternatively, if you want to copy only schema without data:
<br/>
>select clone_schema('development', 'development_clone', false, false);
<br/>

If you just want to generate the DDL, call it like this:
<br/>
>select clone_schema('development', 'development_clone', false, true);

In this case, standard output with "INFO" lines are the generated DDL.
<br/><br/><br/><br/>

NOTE: Currently there is a dependency on installing the pg_permissions extension from Cybertec.  Here are instructions for downloading and installing:

       sudo su -
       git clone https://github.com/cybertec-postgresql/pg_permission.git pg_permission
       cd pg_permission
       -- make sure target pg_config is in your path. This example uses PG v11 on Ubuntu.
       PATH=/usr/lib/postgresql/11/bin/pg_config:$PATH
       --compile and install
       make install
       -- Inside sql session, create the extension:
       create extension pg_permissions;
