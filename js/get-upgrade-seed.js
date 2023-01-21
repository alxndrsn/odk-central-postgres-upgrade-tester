const log = (...args) => console.error('[get-upgrade-seed]', ...args);

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

  const { rows } = await client.query(`SELECT value->'ok' AS is_ok FROM config WHERE key='upgrade-seed'`);
  if(!rows.length) throw new Error('Upgrade seed not found in DB - upgrade probably failed!');
  if(rows.length > 1) throw new Error('Wrong result count:', rows);

  console.log(rows[0].is_ok);

  log('Complete.');
  process.exit();
})();
