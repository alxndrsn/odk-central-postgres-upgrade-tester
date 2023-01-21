const log = (...args) => console.error('[count-db-contents]', ...args);

log('Loading dependencies...');

const { Client } = require('pg');
const config = require('config').get('default.database');

const { password, ...redactedConfig } = config;
log('DB config:', redactedConfig);

(async () => {
  log('Connecting to DB...');

  const client = new Client(config);
  await client.connect();

  log('Connected OK; counting contents...');
	await client.query(`
		SELECT (SELECT COUNT(*) AS blobs       FROM blobs)
		     , (SELECT COUNT(*) AS projects    FROM projects)
				 , (SELECT COUNT(*) AS submissions FROM submissions)
				 , (SELECT COUNT(*) AS users       FROM users)
	`);


  log('Complete.');
  process.exit();
})();
