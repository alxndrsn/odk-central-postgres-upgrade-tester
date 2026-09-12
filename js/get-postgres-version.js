const log = (...args) => console.error('[get-postgres-version]', ...args);

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

    log('Connected OK; fetching version...');

    const { rows } = await client.query('SELECT VERSION()');
    const fullVersion = rows[0].version.match(/^PostgreSQL (\S+) /)[1];

    log('Got full version:', fullVersion);

    const parts = fullVersion.split('.', 2);

    if(parts[0] < 10) console.log(parts.join('.'));
    else              console.log(parts[0]);

    log('Complete.');
    process.exit();
  } catch(err) {
    console.log(err.code || err.message || err);
  }
})();
