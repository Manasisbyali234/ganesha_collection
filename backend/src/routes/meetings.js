const express = require('express');
const pool = require('../db');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

// POST /api/meetings
// body: { title, meeting_date, meeting_time, notes, items: [{item_name, item_type, quantity, notes}] }
router.post('/', verifyToken, requireMember, async (req, res) => {
  const client = await pool.connect();
  try {
    const { title, meeting_date, meeting_time, notes, items } = req.body;
    if (!title || !meeting_date) {
      return res.status(400).json({ error: 'title and meeting_date are required' });
    }
    await client.query('BEGIN');
    const meetingResult = await client.query(
      `INSERT INTO meetings (member_id, title, meeting_date, meeting_time, notes)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [req.user.id, title, meeting_date, meeting_time || null, notes || null]
    );
    const meeting = meetingResult.rows[0];

    const insertedItems = [];
    if (Array.isArray(items)) {
      for (const item of items) {
        if (!item.item_name) continue;
        const itemResult = await client.query(
          `INSERT INTO meeting_items (meeting_id, item_name, item_type, quantity, notes)
           VALUES ($1,$2,$3,$4,$5) RETURNING *`,
          [meeting.id, item.item_name, item.item_type || null, item.quantity || null, item.notes || null]
        );
        insertedItems.push(itemResult.rows[0]);
      }
    }
    await client.query('COMMIT');
    res.status(201).json({ ...meeting, items: insertedItems });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    client.release();
  }
});

// GET /api/meetings - member's meetings with their items
router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const meetings = await pool.query(
      'SELECT * FROM meetings WHERE member_id = $1 ORDER BY meeting_date DESC',
      [req.user.id]
    );
    const meetingIds = meetings.rows.map(m => m.id);
    let itemsByMeeting = {};
    if (meetingIds.length) {
      const items = await pool.query(
        'SELECT * FROM meeting_items WHERE meeting_id = ANY($1::int[])',
        [meetingIds]
      );
      itemsByMeeting = items.rows.reduce((acc, item) => {
        (acc[item.meeting_id] ||= []).push(item);
        return acc;
      }, {});
    }
    const result = meetings.rows.map(m => ({ ...m, items: itemsByMeeting[m.id] || [] }));
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
