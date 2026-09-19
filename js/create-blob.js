const log = (...args) => console.error('[create-blob]', ...args);

log('Loading dependencies...');

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

  log('Connected OK; creating blob function...');

  const blobSizeMb = 250;
  log(`Function created OK; creating blob of ${blobSizeMb} MB...`);
  await client.query(`
    INSERT INTO blobs (sha, "contentType", md5, content)
               VALUES ( '',            '',  '', pg_read_binary_file('/dev/urandom', 0, ${blobSizeMb * 1_000_000}));
  `);

  log('Complete.');
  process.exit();
})();
