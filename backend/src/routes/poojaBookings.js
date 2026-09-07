const express = require('express');
const pool = require('../db');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { devotee_name, phone, pooja_name, booking_date, booking_time, amount, payment_method } = req.body;
    if (!devotee_name || !pooja_name || !booking_date) {
      return res.status(400).json({ error: 'devotee_name, pooja_name and booking_date are required' });
    }
    const result = await pool.query(
      `INSERT INTO pooja_bookings (member_id, devotee_name, phone, pooja_name, booking_date, booking_time, amount, payment_method)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.user.id, devotee_name, phone || null, pooja_name, booking_date, booking_time || null, Number(amount) || 0, payment_method || 'cash']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM pooja_bookings WHERE member_id = $1 ORDER BY booking_date DESC',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.patch('/:id/status', verifyToken, requireMember, async (req, res) => {
  try {
    const { status } = req.body; // booked / completed / cancelled
    if (!['booked', 'completed', 'cancelled'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    const result = await pool.query(
      'UPDATE pooja_bookings SET status = $1 WHERE id = $2 AND member_id = $3 RETURNING *',
      [status, req.params.id, req.user.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Booking not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
