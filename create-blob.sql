-- From: https://dba.stackexchange.com/a/22571 --
CREATE OR REPLACE FUNCTION random_bytea(bytea_length integer)
  RETURNS bytea AS $body$
    SELECT decode(string_agg(lpad(to_hex(width_bucket(random(), 0, 1, 256) -1), 2, '0'), ''), 'hex')
      FROM generate_series(1, $1);
  $body$
  LANGUAGE 'sql'
  VOLATILE
  SET search_path = 'pg_catalog';

INSERT INTO blobs (sha, content,                "contentType", md5)
           VALUES ('',  random_bytea(50000000), '',            '');
