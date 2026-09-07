const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { verifyToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

function signToken(payload) {
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

// ---------------------------------------------------------
// POST /api/auth/admin/login
// ---------------------------------------------------------
router.post('/admin/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const result = await pool.query('SELECT * FROM admins WHERE email = $1', [email]);
    const admin = result.rows[0];
    if (!admin) return res.status(401).json({ error: 'Invalid credentials' });

    const match = await bcrypt.compare(password, admin.password_hash);
    if (!match) return res.status(401).json({ error: 'Invalid credentials' });

    const token = signToken({ id: admin.id, role: 'admin', name: admin.name, email: admin.email });
    res.json({ token, user: { id: admin.id, name: admin.name, email: admin.email, role: 'admin' } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------
// POST /api/auth/member/login
// ---------------------------------------------------------
router.post('/member/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const result = await pool.query('SELECT * FROM members WHERE email = $1', [email]);
    const member = result.rows[0];
    if (!member) return res.status(401).json({ error: 'Invalid credentials' });
    if (member.status !== 'active') {
      return res.status(403).json({ error: 'Your account has been deactivated. Contact admin.' });
    }

    const match = await bcrypt.compare(password, member.password_hash);
    if (!match) return res.status(401).json({ error: 'Invalid credentials' });

    const token = signToken({ id: member.id, role: 'member', name: member.name, email: member.email });
    res.json({
      token,
      user: { id: member.id, name: member.name, email: member.email, phone: member.phone, role: 'member' },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------
// POST /api/auth/members  (Admin creates a member/user account)
// body: { name, email, phone, password }
// ---------------------------------------------------------
router.post('/members', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;
    if (!name || !email || !phone || !password) {
      return res.status(400).json({ error: 'name, email, phone and password are required' });
    }
    const existing = await pool.query('SELECT id FROM members WHERE email = $1', [email]);
    if (existing.rows.length) {
      return res.status(409).json({ error: 'A member with this email already exists' });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      `INSERT INTO members (name, email, phone, password_hash, created_by)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, phone, status, created_at`,
      [name, email, phone, passwordHash, req.user.id]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
