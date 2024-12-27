# clone_schema

**clone_schema** is a PostgreSQL tool for making a copy of a schema.  It includes all objects associated with a schema.


Handles following objects:

* Tables - structure (UDT columns, indexes, constraints, keys) and optionally, data
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
* source schema   <pre>Required: text - schema name</pre>
* target schema   <pre>Required: text - table name</pre>
* action          <pre>Required: One of 'DATA','NODATA','DDLONLY'</pre>
* Enumerated list <pre>Optional: 'NOOWNER','NOACL','VERBOSE','FILECOPY'</pre>

Returns: INTEGER (0 for success, positive non-zero number for an error)
<br/><br/>
<pre>source schema  Required: text - schema name</pre>
<pre>target schema  Required: text - table name</pre>
<pre>Action         Required: One of 'DATA','NODATA','DDLONLY'</pre>
<pre>ENUM list      Optional: 'NOOWNER','NOACL','VERBOSE','FILECOPY'</pre>
<br/>

**Examples**<br/>
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
<br/><br/>
**Ownership/Privileges**<br/>
By default, ownership and privileges are also cloned from source to target schema.  To override, specify **NOOWNER** and/or **NOACL** (similar to how pg_dump works). When **NOOWNER** is specified, the one running the script is the default owner unless overridden by a **SET ROLE** command before running this script. 

**Copying Data**
You may get faster results copying data to/from disk instead of in-memory copy. **FILECOPY** is a workaround for tables with complex UDT-type columns that fail to copy.  It only works for On-Prem PG Instances since it relies on using the COPY command to write to and read from disk on which the PostgreSQL server resides. <br/>
Although pg_clone_schema supports data copy, it is not very efficient for large datasets.  It only copies tables one at a time.  Using pg_dump/pg_restore in directory mode using parallel jobs would be a lot more efficient for large datasets.
<br/><br/>
**Sequences, Serial, and Identity**<br/>
Serial is treated the same way as sequences are with explicit sequence definitions.  Although you can create a serial column with the **serial** keyword, when you export it through pg_dump, it loses its **serial** definition and looks like a plain sequence.  This program also attempts to set the nextval (using **setval**) for all 3 types which have a valid **last_value** from the **pg_sequences** table.
<br/><br/>
The **schema_object_counts.sql** file is useful for validating the cloning results.  Just run it against source and target schemas to validate object counts after changing default schema name, **sample**.
<br/><br/>

# Regression Testing Overview
Regression Testing is done in the following order:
* Execute the **sampledb.sql** script to create the **clone_testing** database and the **sample** schema within it as the basis for the source schema.
* Clone the **sample** schema in the 3 ways possible (NODATA, DATA, DDLONLY).
* Run the **schema_object_counts.sql** queries to compare object counts and rows from the source and target schemas.
* Repeat all of the above for all supported versions of PG.

# Assumptions
* Testing and validation is done only through the Community version of PostgreSQL.
* The target schema uses the same tablespace(s) as the source schema.

# Limitations
* Only works for PG Versions 10 and up.
* You should not clone the "public" schema.  The resulting output may not be accurate even if it finishes without any errors.
* You should not use multiple, user-defined schema objects and expect cloning one schema to another to work.  This project does not support that at the present time.  It only supports 3 schemas basically: the source schema, the target schema, and objects defined in the public schema referenced by those user-defined schemas.
* Index and key names are not all the same in the cloned schema since some of the tables are created with the CREATE TABLE ... (LIKE ...) construct.  Those index names are automatically fabricated by PG with naming format that is prepended with table and column names separated by underscores and ending with "_idx" or "_key".  In DDLOnly mode, this will cause errors when attempting to make comments on indexes.  Follow the NOTE in DDL output for lines you may want to comment out or fix.
* Foreign Tables are not handled at the present time.  They must be done manually.
<br/>
<br/>
Sponsor:
 http://elephas.io/
<br/>
<br/> 
Compare cloning with EnterpriseDB's version that only works with their Advanced Server:
https://www.enterprisedb.com/edb-docs/d/edb-postgres-advanced-server/user-guides/user-guide/11/EDB_Postgres_Advanced_Server_Guide.1.078.html

 
 
 
