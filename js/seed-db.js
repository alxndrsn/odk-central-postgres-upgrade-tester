const log = (...args) => console.error('[seed-db]', ...args);

log('Loading dependencies...');

const { Client } = require('pg');
const config = require('config').get('default.database');

const { password, ...redactedConfig } = config;
log('DB config:', redactedConfig);
log('DB env vars:');
Object.entries(process.env).filter(([ k ]) => k.startsWith('PG')).sort(([k1], [k2]) => k1<k2?-1:1).forEach(([ k, v ]) => log(`  ${k}=${v}`));

(async () => {
  try {
    log('Connecting to DB...');

    const client = new Client(config);
    await client.connect();

    log('Connected OK; inserting...');

    await client.query(`INSERT INTO config (key, value) VALUES('db-seed', '{"ok":true}')`);

    log('Complete.');
    process.exit();
  } catch(err) {
    console.log(err);
    process.exit(1);
  }
})();
