const log = (...args) => console.error('[get-migration-seed]', ...args);

log('Loading dependencies...');

const { Client } = require('pg');
const config = require('config').get('default.database');

const { password, ...redactedConfig } = config;
log('DB config:', redactedConfig);

(async () => {
	log('Connecting to DB...');

  const client = new Client(config);
	await client.connect();

	log('Connected OK; fetching version...');

	const { rows } = await client.query(`SELECT value->'ok' AS is_ok FROM config WHERE key='migration-seed'`);
	if(!rows.length) throw new Error('Migration seed not found in DB - migration probably failed!');
	if(rows.length > 1) throw new Error('Wrong result count:', rows);

	console.log(rows[0].is_ok);

	log('Complete.');
	process.exit();
})();
