import express from 'express';
import db from '../config/database.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

// Get all workshops
router.get('/', authenticate, async (req, res) => {
  try {
    const { status, assigned_rig } = req.query;
    let query = 'SELECT * FROM workshops WHERE 1=1';
    const params = [];

    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }
    if (assigned_rig) {
      query += ' AND assigned_rig = ?';
      params.push(assigned_rig);
    }

    query += ' ORDER BY name ASC';
    const [workshops] = await db.query(query, params);
    res.json({ success: true, data: workshops });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch workshops' });
  }
});

export default router;
