const express = require('express');
const pool = require('../db');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

// POST /api/banners
router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { title, image_url, description, start_date, end_date, start_time, end_time } = req.body;
    if (!title || !start_date || !end_date) {
      return res.status(400).json({ error: 'title, start_date and end_date are required' });
    }
    const result = await pool.query(
      `INSERT INTO banners (member_id, title, image_url, description, start_date, end_date, start_time, end_time)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.user.id, title, image_url || null, description || null, start_date, end_date, start_time || null, end_time || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/banners - all active banners (any logged-in member can view, e.g. for a home carousel)
router.get('/', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.*, m.name AS created_by_name FROM banners b
       LEFT JOIN members m ON m.id = b.member_id
       ORDER BY b.start_date DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/banners/:id/active
router.patch('/:id/active', verifyToken, requireMember, async (req, res) => {
  try {
    const { active } = req.body;
    const result = await pool.query(
      'UPDATE banners SET active = $1 WHERE id = $2 AND member_id = $3 RETURNING *',
      [!!active, req.params.id, req.user.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Banner not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
