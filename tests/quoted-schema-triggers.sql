-- Install clone_schema.sql first. Run with psql -X -v ON_ERROR_STOP=1
-- against a disposable database; fixture names must not already exist.
BEGIN;
SET LOCAL statement_timeout = '15s';
CREATE SCHEMA "Trigger Source";
CREATE TABLE "Trigger Source".items (id integer, touched boolean DEFAULT false);
CREATE FUNCTION "Trigger Source".bump() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.id := NEW.id + 1; RETURN NEW; END $$;
CREATE FUNCTION public.quoted_schema_touch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.touched := true; RETURN NEW; END $$;
CREATE TRIGGER bump BEFORE INSERT ON "Trigger Source".items
  FOR EACH ROW EXECUTE FUNCTION "Trigger Source".bump();
CREATE TRIGGER touch BEFORE INSERT ON "Trigger Source".items
  FOR EACH ROW EXECUTE FUNCTION public.quoted_schema_touch();
SELECT public.clone_schema('Trigger Source', 'Trigger Destination', 'NODATA');
INSERT INTO "Trigger Destination".items(id) VALUES (1);
DO $$ BEGIN
  IF (SELECT count(*) FROM "Trigger Destination".items WHERE id=2 AND touched) <> 1 THEN
    RAISE EXCEPTION 'destination triggers did not run';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid='"Trigger Destination".items'::regclass AND NOT tgisinternal) <> 2 THEN
    RAISE EXCEPTION 'destination triggers missing';
  END IF;
END $$;
ROLLBACK;
