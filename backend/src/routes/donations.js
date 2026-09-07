const express = require('express');
const pool = require('../db');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

const VALID_SECTIONS = ['gold', 'silver', 'food', 'cash', 'other'];

// POST /api/donations
router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { devotee_id, donor_name, donor_phone, section, description, amount, payment_method, paid, donation_date } = req.body;
    if (!donor_name || !section) {
      return res.status(400).json({ error: 'donor_name and section are required' });
    }
    if (!VALID_SECTIONS.includes(section)) {
      return res.status(400).json({ error: `section must be one of: ${VALID_SECTIONS.join(', ')}` });
    }
    const result = await pool.query(
      `INSERT INTO donations (member_id, devotee_id, donor_name, donor_phone, section, description, amount, payment_method, paid, donation_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, COALESCE($10, CURRENT_DATE)) RETURNING *`,
      [req.user.id, devotee_id || null, donor_name, donor_phone || null, section, description || null,
       Number(amount) || 0, payment_method || 'cash', paid !== false, donation_date || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/donations?section=gold&paid=true
router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { section, paid } = req.query;
    let query = 'SELECT * FROM donations WHERE member_id = $1';
    const params = [req.user.id];
    if (section) {
      params.push(section);
      query += ` AND section = $${params.length}`;
    }
    if (paid !== undefined) {
      params.push(paid === 'true');
      query += ` AND paid = $${params.length}`;
    }
    query += ' ORDER BY donation_date DESC, created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/donations/summary/me - totals grouped by section, for the logged-in member
router.get('/summary/me', verifyToken, requireMember, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT section, COUNT(*) AS count, COALESCE(SUM(amount) FILTER (WHERE paid), 0) AS total_paid
       FROM donations WHERE member_id = $1 GROUP BY section`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
