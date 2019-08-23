# pg-clone-schema

Handles following objects:

* Tables - structure and data
* Views
* Materialized Views - Structure and data
* Sequence
* Functions
* Types

You can call function like this to copy schema with data:
>select clone_schema('development', 'development_clone', true);
<br/>
Alternatively, if you want to copy only schema without data:
>select clone_schema('development', 'development_clone', false);
<br/>
