require('dotenv').config();
const bcrypt = require('bcryptjs');
const pool = require('./db');

async function seed() {
  const name = process.env.SEED_ADMIN_NAME || 'Super Admin';
  const email = process.env.SEED_ADMIN_EMAIL || 'admin@temple.com';
  const password = process.env.SEED_ADMIN_PASSWORD || 'Admin@123';

  const existing = await pool.query('SELECT id FROM admins WHERE email = $1', [email]);
  if (existing.rows.length) {
    console.log(`Admin with email ${email} already exists. Skipping.`);
    process.exit(0);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  await pool.query(
    'INSERT INTO admins (name, email, password_hash) VALUES ($1, $2, $3)',
    [name, email, passwordHash]
  );
  console.log('=================================================');
  console.log('Default admin created:');
  console.log(`  Email:    ${email}`);
  console.log(`  Password: ${password}`);
  console.log('Please log in and change this password.');
  console.log('=================================================');
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
