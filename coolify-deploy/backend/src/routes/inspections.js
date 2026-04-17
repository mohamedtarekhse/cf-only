import express from 'express';
import db from '../config/database.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

// Get all inspections
router.get('/', authenticate, async (req, res) => {
  try {
    const { inspection_type, rig_name } = req.query;
    let query = 'SELECT * FROM inspections WHERE 1=1';
    const params = [];

    if (inspection_type) {
      query += ' AND inspection_type = ?';
      params.push(inspection_type);
    }
    if (rig_name) {
      query += ' AND rig_name = ?';
      params.push(rig_name);
    }

    query += ' ORDER BY start_date DESC';
    const [inspections] = await db.query(query, params);
    res.json({ success: true, data: inspections });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch inspections' });
  }
});

// Create inspection
router.post('/', authenticate, async (req, res) => {
  try {
    const { id, inspection_type, rig_name, start_date, end_date, inspector, status, notes } = req.body;

    if (!id) {
      return res.status(400).json({ success: false, error: 'id required' });
    }

    await db.query(
      `INSERT INTO inspections (id, inspection_type, rig_name, start_date, end_date, inspector, status, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, inspection_type, rig_name, start_date, end_date, inspector, status || 'Scheduled', notes]
    );

    res.status(201).json({ success: true, data: { id, ...req.body } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to create inspection' });
  }
});

export default router;
