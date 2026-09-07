const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function runSchema() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  const sql = fs.readFileSync(path.join(__dirname, '..', 'schema.sql'), 'utf8');
  await client.query(sql);
  console.log('Schema applied successfully!');
  await client.end();
}

runSchema().catch(e => { console.error('Schema failed:', e.message); process.exit(1); });
