# clone_schema

Works on Linux distros and all Windows versions.  It also runs on PostgreSQL in the cloud (AWS, GCP, MS Azure).

Handles following objects:

* Tables - structure (indexes, constraints, keys) and optionally, data
* Views, Materialized Views - Structure and data
* Sequences, Serial, Identity
* Functions/Procedures
* Types (composite and enum)
* Collations, Domains, Rules, Policies
* Triggers, Trigger Functions
* Comments
* ACLs (Permissions/Grants)

<br/>

Arguments:
* source schema
* target schema
* Enumerated list

<pre>source schema  Required: text - schema name</pre>
<pre>target schema  Required: text - table name</pre>
<pre>ENUM list      Required: One of 'DATA','NODATA','DDLONLY'</pre>
<pre>ENUM list      Optional: 'NOOWNER','NOACL','VERBOSE'</pre>
By default, ownership and privileges are also cloned from source to target schema.  To override, specify **NOOWNER** and/or **NOACL** (similar to how pg_dump works). When **NOOWNER** is specified, the one running the script is the default owner unless overridden by a **SET ROLE** command before running this script.
<br/><br/>

Clone the schema with no data:
<br/>
>select clone_schema('sample', 'sample_clone', 'NODATA');
<br/>

Clone the schema with data:
<br/>
>select clone_schema('sample', 'sample_clone', 'DATA');<br/>
>select clone_schema('sample', 'sample_clone', 'DATA','VERBOSE');  -- show row copy progress
<br/>

Just generate DDL:
<br/>
>select clone_schema('sample', 'sample_clone', 'DDLONLY');

In this case, standard output with "INFO" lines are the generated DDL.
<br/><br/><br/>
The **schema_object_counts.sql** file is useful for validating the cloning results.  Just run it against source and target schemas to validate object counts after changing default schema name, **sample**.
<br/><br/>

# Regression Testing Overview
Regression Testing is done in the following order:
* Execute the **sampledb.sql** script to create the **clone_testing** database and the **sample** schema within it as the basis for the source schema.
* Clone the **sample** schema in the 3 ways possible (NODATA, DATA, DDLONLY).
* Run the **schema_object_counts.sql** queries to compare object counts and rows from the source and target schemas.
* Repeat all of the above for all supported versions of PG.

# Assumptions
* The target schema uses the same tablespace(s) as the source schema.

# Limitations
* Only works for PG Versions 10 and up.
* You should not clone the "public" schema.  The resulting output may not be accurate even if it finishes without any errors.
* Foreign Tables are not handled at the present time.  They must be done manually.
* Functions/procedures that reference schema-qualified objects in the body may not clone as expected.  The target functions/objects will still reference whatever qualifications exist in the body.  To use this utility at the present time, you may need to remove schema-qualified references within your functions.
* With PG DBaaS instances (AWS, GCP, Azure, etc.), you cannot copy data from source to target if a table has user-defined datatypes created in the source schema. A workaround is to create user-defined datatypes for the source schema in the public schema.  For instance, when you create the **citext** datatype through the **citex** extension, by default it is created in the public schema.
<br/>
<br/>
Sponsor:
 http://elephas.io/
<br/>
<br/> 
Compare cloning with EnterpriseDB's version that only works with their Advanced Server:
https://www.enterprisedb.com/edb-docs/d/edb-postgres-advanced-server/user-guides/user-guide/11/EDB_Postgres_Advanced_Server_Guide.1.078.html

 
 
 
