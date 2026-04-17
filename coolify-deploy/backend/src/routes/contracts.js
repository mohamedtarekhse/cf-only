import express from 'express';
import db from '../config/database.js';
import { authenticate, authorize } from '../middleware/auth.js';

const router = express.Router();

// Get all contracts
router.get('/', authenticate, async (req, res) => {
  try {
    const [contracts] = await db.query('SELECT * FROM contracts ORDER BY created_at DESC');
    res.json({ success: true, data: contracts });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch contracts' });
  }
});

// Get single contract
router.get('/:id', authenticate, async (req, res) => {
  try {
    const [contracts] = await db.query('SELECT * FROM contracts WHERE id = ?', [req.params.id]);
    if (!contracts || contracts.length === 0) {
      return res.status(404).json({ success: false, error: 'Contract not found' });
    }
    res.json({ success: true, data: contracts[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch contract' });
  }
});

// Create contract
router.post('/', authenticate, authorize('Admin', 'Manager'), async (req, res) => {
  try {
    const { id, rig, value, start_date, end_date, status } = req.body;
    if (!id || !rig) {
      return res.status(400).json({ success: false, error: 'id and rig required' });
    }
    await db.query(
      'INSERT INTO contracts (id, rig, value, start_date, end_date, status) VALUES (?, ?, ?, ?, ?, ?)',
      [id, rig, value, start_date, end_date, status || 'Active']
    );
    res.status(201).json({ success: true, data: { id, ...req.body } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to create contract' });
  }
});

// Update contract
router.put('/:id', authenticate, authorize('Admin', 'Manager'), async (req, res) => {
  try {
    const { rig, value, start_date, end_date, status } = req.body;
    await db.query(
      'UPDATE contracts SET rig=?, value=?, start_date=?, end_date=?, status=? WHERE id=?',
      [rig, value, start_date, end_date, status, req.params.id]
    );
    const [updated] = await db.query('SELECT * FROM contracts WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: updated[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to update contract' });
  }
});

// Delete contract
router.delete('/:id', authenticate, authorize('Admin'), async (req, res) => {
  try {
    await db.query('DELETE FROM contracts WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: { deleted: req.params.id } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to delete contract' });
  }
});

export default router;
