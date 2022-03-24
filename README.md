# clone_schema

Handles following objects:

* Tables - structure (indexes, constraints, keys) and optionally, data
* Views
* Materialized Views - Structure and data
* Sequences
* Functions/Procedures
* Types (composite and enum)
* Collations, Domains, and Rules
* Triggers, Trigger Functions
* Comments (in progress: see Issue#62)
* Permissions/GRANTs

<br/>

Arguments:
* source schema
* target schema
* clone with data
* only generate DDL

You can call function like this to copy schema with data:
<br/>
>select clone_schema('sample', 'sample_clone', true, false);
<br/>

Alternatively, if you want to copy only schema without data:
<br/>
>select clone_schema('sample', 'sample_clone', false, false);
<br/>

If you just want to generate the DDL, call it like this:
<br/>
>select clone_schema('sample', 'sample_clone', false, true);

In this case, standard output with "INFO" lines are the generated DDL.
<br/><br/><br/>
The **schema_object_counts.sql** file is useful for validating the cloning results.  Just run it against source and target schemas to validate object counts after changing default schema name, **sample**.
<br/><br/>

# Limitations
* You should not clone the "public" schema.  The resulting output may not be accurate even if it finishes without any errors.
* Foreign Tables are not handled at the present time.  They must be done manually.
* DDL only option is not complete since it depends on objects that aren't created yet. See issue#29
* Functions that reference schema-qualified objects will not clone successfully.  The target schema will still reference the source schema in these cases.  To use this utility at the present time, you need to remove schema-qualified references within your functions.
<br/>
<br/>
Sponsor:
 http://elephas.io/
<br/>
<br/> 
Compare cloning with EnterpriseDB's version that only works with their Advanced Server:
https://www.enterprisedb.com/edb-docs/d/edb-postgres-advanced-server/user-guides/user-guide/11/EDB_Postgres_Advanced_Server_Guide.1.078.html

 
 
 
