const { Client } = require('pg');
const config = require('config').get('default.database');

const log = (...args) => console.log('[wait-for-postgres]', ...args);

process.stdout.write('[wait-for-postgres] Waiting for postgres...');
(async () => {
  const timeout = Date.now() + 30_000;

  while(true) {
    const sleep1 = () => new Promise(resolve => {
      process.stdout.write('.');
      setTimeout(resolve, 1000);
    });

    let client;
    try {
      client = await new Client(config);
      await client.connect(); // N.B. for backwards compatibility, this cannot be chained
      const { rows:[ { ready } ] } = await client.query(`SELECT NOT pg_is_in_recovery() AS ready`);
      if(ready === true) {
        // Extra sleep for luck ¯\_(ツ)_/¯
        await sleep1();

        process.stdout.write('OK.');
        console.log();
        process.exitCode = 0;
        return;
      }
    } catch(err) {
      if(Date.now() < timeout && !isFatal(err)) {
        await sleep1();
      } else {
        process.stdout.write('FAILED!');
        console.log();
        log('Error:', err.message, err, Object.keys(err));
        process.exitCode = 1;
        return;
      }
    } finally {
      try { await client?.end(); } catch(_) { /*ignore*/ }
    }
  }
})();

// Fail faster for well-understood issues which won't resolve by retrying.
function isFatal(err) {
  // See: https://www.postgresql.org/docs/current/errcodes-appendix.html
  if(err.code === '28P01') return true; // auth failure
  if(err.code === '3D000') return true; // db does not exist
}
