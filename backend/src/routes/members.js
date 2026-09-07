const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { verifyToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// ---------------------------------------------------------
// GET /api/members  (Admin: list all members with a quick
// financial summary for each - donations + devotee payments)
// ---------------------------------------------------------
router.get('/', verifyToken, requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        m.id, m.name, m.email, m.phone, m.status, m.created_at,
        COALESCE(d.total_paid, 0) + COALESCE(dn.total_donations, 0) AS total_collection,
        COALESCE(d.total_outstanding, 0) AS total_outstanding,
        COALESCE(d.devotee_count, 0) AS devotee_count,
        COALESCE(dn.donation_count, 0) AS donation_count
      FROM members m
      LEFT JOIN (
        SELECT member_id,
               SUM(paid_amount) AS total_paid,
               SUM(outstanding_amount) AS total_outstanding,
               COUNT(*) AS devotee_count
        FROM devotees GROUP BY member_id
      ) d ON d.member_id = m.id
      LEFT JOIN (
        SELECT member_id,
               SUM(amount) FILTER (WHERE paid = true) AS total_donations,
               COUNT(*) AS donation_count
        FROM donations GROUP BY member_id
      ) dn ON dn.member_id = m.id
      ORDER BY m.created_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------
// GET /api/members/:id/summary  (Admin: full detail on one member)
// ---------------------------------------------------------
router.get('/:id/summary', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const member = await pool.query('SELECT id, name, email, phone, status, created_at FROM members WHERE id = $1', [id]);
    if (!member.rows.length) return res.status(404).json({ error: 'Member not found' });

    const devotees = await pool.query('SELECT * FROM devotees WHERE member_id = $1 ORDER BY created_at DESC', [id]);
    const donations = await pool.query('SELECT * FROM donations WHERE member_id = $1 ORDER BY created_at DESC', [id]);
    const pooja = await pool.query('SELECT * FROM pooja_bookings WHERE member_id = $1 ORDER BY booking_date DESC', [id]);
    const sankalp = await pool.query('SELECT * FROM sankalp_bookings WHERE member_id = $1 ORDER BY booking_date DESC', [id]);

    const totalPaid = devotees.rows.reduce((s, d) => s + Number(d.paid_amount), 0);
    const totalOutstanding = devotees.rows.reduce((s, d) => s + Number(d.outstanding_amount), 0);
    const totalDonations = donations.rows.filter(d => d.paid).reduce((s, d) => s + Number(d.amount), 0);

    res.json({
      member: member.rows[0],
      totals: {
        total_collection: totalPaid + totalDonations,
        total_outstanding: totalOutstanding,
        devotee_count: devotees.rows.length,
        donation_count: donations.rows.length,
      },
      devotees: devotees.rows,
      donations: donations.rows,
      pooja_bookings: pooja.rows,
      sankalp_bookings: sankalp.rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------
// PATCH /api/members/:id/status  (Admin: activate/deactivate)
// ---------------------------------------------------------
router.patch('/:id/status', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'active' | 'inactive'
    if (!['active', 'inactive'].includes(status)) {
      return res.status(400).json({ error: 'status must be active or inactive' });
    }
    const result = await pool.query(
      'UPDATE members SET status = $1 WHERE id = $2 RETURNING id, name, status',
      [status, id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Member not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------
// PATCH /api/members/:id/reset-password (Admin)
// ---------------------------------------------------------
router.patch('/:id/reset-password', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { password } = req.body;
    if (!password || password.length < 4) {
      return res.status(400).json({ error: 'A password of at least 4 characters is required' });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    await pool.query('UPDATE members SET password_hash = $1 WHERE id = $2', [passwordHash, id]);
    res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------
// GET /api/members/dashboard/admin  (Admin: org-wide totals)
// ---------------------------------------------------------
router.get('/dashboard/admin', verifyToken, requireAdmin, async (req, res) => {
  try {
    const totals = await pool.query(`
      SELECT
        (SELECT COALESCE(SUM(paid_amount),0) FROM devotees) +
        (SELECT COALESCE(SUM(amount),0) FROM donations WHERE paid = true) AS total_collection,
        (SELECT COALESCE(SUM(outstanding_amount),0) FROM devotees) AS total_outstanding,
        (SELECT COUNT(*) FROM members) AS total_members,
        (SELECT COUNT(*) FROM devotees) AS total_devotees,
        (SELECT COUNT(*) FROM donations) AS total_donations,
        (SELECT COUNT(*) FROM pooja_bookings) AS total_pooja_bookings,
        (SELECT COUNT(*) FROM sankalp_bookings) AS total_sankalp_bookings
    `);
    res.json(totals.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
