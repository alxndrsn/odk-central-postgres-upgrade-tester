const log = (...args) => console.error(new Date(), '[create-blob]', ...args);

log('Loading dependencies...');

const { randomBytes } = require('node:crypto');

const { Client } = require('pg');
const config = require('config').get('default.database');

const { password, ...redactedConfig } = config;
log('DB config:', redactedConfig);
log('DB env vars:');
Object.entries(process.env).filter(([ k ]) => k.startsWith('PG')).sort(([k1], [k2]) => k1<k2?-1:1).forEach(([ k, v ]) => log(`  ${k}=${v}`));

(async () => {
  log('Connecting to DB...');

  const client = new Client(config);
  await client.connect();

  const blobSizeMb = 250;
  log(`Creating blob of ${blobSizeMb} MB...`);
  const randomBuffer = randomBytes(blobSizeMb * 1_000_000);
  await client.query(
    'INSERT INTO blobs (sha, "contentType", md5, content) VALUES ($1, $2, $3, $4)',
    ['', '', '', randomBuffer]
  );

  log('Complete.');
  process.exit();
})();
