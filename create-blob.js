const log = (...args) => console.error('[create-blob]', ...args);

log('Loading dependencies...');

const { Client } = require('pg');
const config = require('config').get('default.database');

const { password, ...redactedConfig } = config;
log('DB config:', redactedConfig);

(async () => {
  log('Connecting to DB...');

  const client = new Client(config);
  await client.connect();

  log('Connected OK; creating blob function...');
	// random_bytea() from: https://dba.stackexchange.com/a/22571
	await client.query(`
		CREATE OR REPLACE FUNCTION random_bytea(bytea_length integer)
			RETURNS bytea AS $body$
				SELECT decode(string_agg(lpad(to_hex(width_bucket(random(), 0, 1, 256) -1), 2, '0'), ''), 'hex')
					FROM generate_series(1, $1);
			$body$
			LANGUAGE 'sql'
			VOLATILE
			SET search_path = 'pg_catalog';
	`);

	const blobSizeMb = 250;
  log(`Function created OK; creating blob of ${blobSizeMb} MB...`);
	await client.query(`
		INSERT INTO blobs (sha, "contentType", md5, content)
							 VALUES ( '',            '',  '', random_bytea(${blobSizeMb * 1_000_000}));
	`);

  log('Complete.');
  process.exit();
})();
