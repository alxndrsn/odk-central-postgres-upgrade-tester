const log = (...args) => console.error('[seed-db]', ...args);

log('Loading dependencies...');

const { Client } = require('pg');
const config = require('config').get('default.database');

const { password, ...redactedConfig } = config;
log('DB config:', redactedConfig);

(async () => {
  log('Connecting to DB...');

  const client = new Client(config);
  await client.connect();

  log('Connected OK; inserting...');

  await client.query(`INSERT INTO config (key, value) VALUES('migration-seed', '{"ok":true}')`);

  log('Complete.');
  process.exit();
})();
