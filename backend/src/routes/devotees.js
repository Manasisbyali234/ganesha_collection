const express = require('express');
const pool = require('../db');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

// POST /api/devotees  - member adds a new devotee/user with initial payment
router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { name, address, phone, initial_payment, payment_method, total_amount } = req.body;
    if (!name) return res.status(400).json({ error: 'name is required' });

    const paid = Number(initial_payment) || 0;
    const total = total_amount != null ? Number(total_amount) : paid;
    const status = paid <= 0 ? 'pending' : paid >= total ? 'paid' : 'partially_paid';

    const result = await pool.query(
      `INSERT INTO devotees (member_id, name, address, phone, initial_payment, payment_method, total_amount, paid_amount, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [req.user.id, name, address || null, phone || null, paid, payment_method || 'cash', total, paid, status]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/devotees - member's own devotee list (supports ?status=paid|pending|partially_paid)
router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { status } = req.query;
    let query = 'SELECT * FROM devotees WHERE member_id = $1';
    const params = [req.user.id];
    if (status) {
      query += ' AND status = $2';
      params.push(status);
    }
    query += ' ORDER BY created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/devotees/:id/pay - record an additional payment towards outstanding balance
router.patch('/:id/pay', verifyToken, requireMember, async (req, res) => {
  try {
    const { id } = req.params;
    const { amount, payment_method } = req.body;
    const amt = Number(amount);
    if (!amt || amt <= 0) return res.status(400).json({ error: 'A positive amount is required' });

    const existing = await pool.query('SELECT * FROM devotees WHERE id = $1 AND member_id = $2', [id, req.user.id]);
    if (!existing.rows.length) return res.status(404).json({ error: 'Devotee not found' });

    const dev = existing.rows[0];
    const newPaid = Number(dev.paid_amount) + amt;
    const newStatus = newPaid >= Number(dev.total_amount) ? 'paid' : 'partially_paid';

    const result = await pool.query(
      `UPDATE devotees SET paid_amount = $1, status = $2, payment_method = COALESCE($3, payment_method)
       WHERE id = $4 RETURNING *`,
      [newPaid, newStatus, payment_method || null, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/devotees/summary - totals for the logged-in member's dashboard
router.get('/summary/me', verifyToken, requireMember, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        COALESCE(SUM(paid_amount),0) AS total_collected,
        COALESCE(SUM(outstanding_amount),0) AS total_outstanding,
        COUNT(*) FILTER (WHERE status = 'paid') AS paid_count,
        COUNT(*) AS total_count
       FROM devotees WHERE member_id = $1`,
      [req.user.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
