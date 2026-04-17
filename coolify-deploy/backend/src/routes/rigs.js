import express from 'express';
import db from '../config/database.js';
import { authenticate, authorize } from '../middleware/auth.js';

const router = express.Router();

// Get all rigs
router.get('/', authenticate, async (req, res) => {
  try {
    const [rigs] = await db.query('SELECT * FROM rigs ORDER BY name ASC');
    res.json({ success: true, data: rigs });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch rigs' });
  }
});

// Get single rig
router.get('/:id', authenticate, async (req, res) => {
  try {
    const [rigs] = await db.query('SELECT * FROM rigs WHERE id = ?', [req.params.id]);
    if (!rigs || rigs.length === 0) {
      return res.status(404).json({ success: false, error: 'Rig not found' });
    }
    res.json({ success: true, data: rigs[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch rig' });
  }
});

// Create rig
router.post('/', authenticate, authorize('Admin', 'Manager'), async (req, res) => {
  try {
    const { id, name, type, location, depth, hp, status } = req.body;
    if (!id || !name) {
      return res.status(400).json({ success: false, error: 'id and name required' });
    }
    await db.query(
      'INSERT INTO rigs (id, name, type, location, depth, hp, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, name, type, location, depth, hp, status || 'Active']
    );
    res.status(201).json({ success: true, data: { id, ...req.body } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to create rig' });
  }
});

// Update rig
router.put('/:id', authenticate, authorize('Admin', 'Manager'), async (req, res) => {
  try {
    const { name, type, location, depth, hp, status } = req.body;
    await db.query(
      'UPDATE rigs SET name=?, type=?, location=?, depth=?, hp=?, status=? WHERE id=?',
      [name, type, location, depth, hp, status, req.params.id]
    );
    const [updated] = await db.query('SELECT * FROM rigs WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: updated[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to update rig' });
  }
});

// Delete rig
router.delete('/:id', authenticate, authorize('Admin'), async (req, res) => {
  try {
    await db.query('DELETE FROM rigs WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: { deleted: req.params.id } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to delete rig' });
  }
});

export default router;
