import express from 'express';
import db from '../config/database.js';
import { authenticate, authorize } from '../middleware/auth.js';

const router = express.Router();

// Get all transfers
router.get('/', authenticate, async (req, res) => {
  try {
    const { status, priority } = req.query;
    let query = 'SELECT * FROM transfers WHERE 1=1';
    const params = [];

    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }
    if (priority) {
      query += ' AND priority = ?';
      params.push(priority);
    }

    query += ' ORDER BY created_at DESC';
    const [transfers] = await db.query(query, params);
    res.json({ success: true, data: transfers });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch transfers' });
  }
});

// Get single transfer
router.get('/:id', authenticate, async (req, res) => {
  try {
    const [transfers] = await db.query('SELECT * FROM transfers WHERE id = ?', [req.params.id]);
    if (!transfers || transfers.length === 0) {
      return res.status(404).json({ success: false, error: 'Transfer not found' });
    }
    res.json({ success: true, data: transfers[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch transfer' });
  }
});

// Create transfer request
router.post('/', authenticate, async (req, res) => {
  try {
    const { id, asset_id, asset_name, current_loc, destination, dest_rig, priority, type, requested_by, request_date, required_date, reason, instructions } = req.body;
    
    if (!id || !asset_id || !destination) {
      return res.status(400).json({ success: false, error: 'id, asset_id, and destination required' });
    }

    await db.query(
      `INSERT INTO transfers (id, asset_id, asset_name, current_loc, destination, dest_rig, priority, type, requested_by, request_date, required_date, reason, instructions, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending')`,
      [id, asset_id, asset_name, current_loc, destination, dest_rig, priority || 'Medium', type, requested_by, request_date, required_date, reason, instructions]
    );

    res.status(201).json({ success: true, data: { id, ...req.body, status: 'Pending' } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to create transfer' });
  }
});

// Approve/reject transfer (stage-based)
router.post('/:id/:action', authenticate, async (req, res) => {
  try {
    const { id, action } = req.params; // action: approve-stage1, approve-stage2, approve-stage3
    const { role, comment, approved_by } = req.body;

    if (!role || !comment || !approved_by) {
      return res.status(400).json({ success: false, error: 'role, comment, and approved_by required' });
    }

    const today = new Date().toISOString().slice(0, 10);
    let updates = {};

    if (role === 'supt') {
      updates = {
        supt_approved_by: approved_by,
        supt_approved_date: today,
        supt_action: action === 'approve' ? 'approve' : 'reject',
        supt_comment: comment,
        status: action === 'approve' ? 'Supt Approved' : action === 'reject' ? 'Rejected' : 'On Hold'
      };
    } else if (role === 'drilling') {
      updates = {
        ops_approved_by: approved_by,
        ops_approved_date: today,
        ops_action: action === 'approve' ? 'approve' : 'reject',
        ops_comment: comment,
        status: action === 'approve' ? 'Drilling Approved' : action === 'reject' ? 'Rejected' : 'On Hold'
      };
    } else if (role === 'ops') {
      updates = {
        mgr_approved_by: approved_by,
        mgr_approved_date: today,
        mgr_action: action === 'approve' ? 'approve' : 'reject',
        mgr_comment: comment,
        status: action === 'approve' ? 'Completed' : action === 'reject' ? 'Rejected' : 'On Hold'
      };

      // If final approval, update asset location
      if (action === 'approve') {
        const [transfers] = await db.query('SELECT * FROM transfers WHERE id = ?', [id]);
        if (transfers && transfers.length > 0) {
          const transfer = transfers[0];
          await db.query(
            'UPDATE assets SET location = ?, rig_name = ? WHERE asset_id = ?',
            [transfer.destination, transfer.dest_rig, transfer.asset_id]
          );
        }
      }
    } else {
      return res.status(400).json({ success: false, error: 'role must be supt, drilling, or ops' });
    }

    const fields = Object.keys(updates);
    const values = [...Object.values(updates), id];
    const setClause = fields.map(f => `${f} = ?`).join(', ');

    await db.query(`UPDATE transfers SET ${setClause} WHERE id = ?`, values);

    const [updated] = await db.query('SELECT * FROM transfers WHERE id = ?', [id]);
    res.json({ success: true, data: updated[0] });
  } catch (err) {
    console.error('Transfer approval error:', err);
    res.status(500).json({ success: false, error: 'Failed to process transfer' });
  }
});

export default router;
