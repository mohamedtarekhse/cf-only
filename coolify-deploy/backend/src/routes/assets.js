import express from 'express';
import db from '../config/database.js';
import { authenticate, authorize } from '../middleware/auth.js';

const router = express.Router();

// Get all assets (with optional filters)
router.get('/', authenticate, async (req, res) => {
  try {
    const { status, rig_name, location, category, search } = req.query;
    
    let query = 'SELECT * FROM assets WHERE 1=1';
    const params = [];

    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }
    if (rig_name) {
      query += ' AND rig_name = ?';
      params.push(rig_name);
    }
    if (location) {
      query += ' AND location = ?';
      params.push(location);
    }
    if (category) {
      query += ' AND category = ?';
      params.push(category);
    }
    if (search) {
      query += ' AND (name LIKE ? OR serial LIKE ? OR asset_id LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    query += ' ORDER BY name ASC';
    
    const [assets] = await db.query(query, params);
    res.json({ success: true, data: assets });
  } catch (err) {
    console.error('Error fetching assets:', err);
    res.status(500).json({ success: false, error: 'Failed to fetch assets' });
  }
});

// Get single asset by ID
router.get('/:id', authenticate, async (req, res) => {
  try {
    const [assets] = await db.query(
      'SELECT * FROM assets WHERE asset_id = ?',
      [req.params.id]
    );

    if (!assets || assets.length === 0) {
      return res.status(404).json({ success: false, error: 'Asset not found' });
    }

    res.json({ success: true, data: assets[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch asset' });
  }
});

// Create new asset
router.post('/', authenticate, authorize('Admin', 'Manager', 'Asset Manager'), async (req, res) => {
  try {
    const { asset_id, name, category, rig_name, location, status, value, acquisition_date, serial, notes, last_inspection, inspection_type, cert_link } = req.body;

    if (!asset_id || !name) {
      return res.status(400).json({ success: false, error: 'asset_id and name are required' });
    }

    const [existing] = await db.query('SELECT asset_id FROM assets WHERE asset_id = ?', [asset_id]);
    if (existing && existing.length > 0) {
      return res.status(400).json({ success: false, error: 'Asset ID already exists' });
    }

    const result = await db.query(
      `INSERT INTO assets (asset_id, name, category, rig_name, location, status, value, acquisition_date, serial, notes, last_inspection, inspection_type, cert_link)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [asset_id, name, category, rig_name, location, status || 'Active', value, acquisition_date, serial, notes, last_inspection, inspection_type, cert_link]
    );

    res.status(201).json({ success: true, data: { asset_id, ...req.body } });
  } catch (err) {
    console.error('Error creating asset:', err);
    res.status(500).json({ success: false, error: 'Failed to create asset' });
  }
});

// Update asset
router.put('/:id', authenticate, authorize('Admin', 'Manager', 'Asset Manager'), async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;
    
    // Remove fields that shouldn't be updated
    delete updates.asset_id;
    delete updates.created_at;
    delete updates.updated_at;

    const fields = Object.keys(updates);
    if (fields.length === 0) {
      return res.status(400).json({ success: false, error: 'No fields to update' });
    }

    const values = Object.values(updates);
    const setClause = fields.map(f => `${f} = ?`).join(', ');

    await db.query(
      `UPDATE assets SET ${setClause} WHERE asset_id = ?`,
      [...values, id]
    );

    const [updated] = await db.query('SELECT * FROM assets WHERE asset_id = ?', [id]);
    res.json({ success: true, data: updated[0] });
  } catch (err) {
    console.error('Error updating asset:', err);
    res.status(500).json({ success: false, error: 'Failed to update asset' });
  }
});

// Delete asset
router.delete('/:id', authenticate, authorize('Admin'), async (req, res) => {
  try {
    await db.query('DELETE FROM assets WHERE asset_id = ?', [req.params.id]);
    res.json({ success: true, data: { deleted: req.params.id } });
  } catch (err) {
    console.error('Error deleting asset:', err);
    res.status(500).json({ success: false, error: 'Failed to delete asset' });
  }
});

export default router;
