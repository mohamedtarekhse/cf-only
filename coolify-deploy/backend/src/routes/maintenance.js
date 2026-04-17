import express from 'express';
import db from '../config/database.js';
import { authenticate, authorize } from '../middleware/auth.js';

const router = express.Router();

// Get all maintenance schedules
router.get('/schedules', authenticate, async (req, res) => {
  try {
    const { asset_id, priority, status } = req.query;
    let query = `
      SELECT ms.*, a.name as asset_name, a.rig_name 
      FROM maintenance_schedules ms
      LEFT JOIN assets a ON ms.asset_id = a.asset_id
      WHERE 1=1
    `;
    const params = [];

    if (asset_id) {
      query += ' AND ms.asset_id = ?';
      params.push(asset_id);
    }
    if (priority) {
      query += ' AND ms.priority = ?';
      params.push(priority);
    }
    if (status) {
      query += ' AND ms.status = ?';
      params.push(status);
    }

    query += ' ORDER BY ms.next_due ASC';
    const [schedules] = await db.query(query, params);
    res.json({ success: true, data: schedules });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch maintenance schedules' });
  }
});

// Create maintenance schedule
router.post('/schedules', authenticate, authorize('Admin', 'Manager', 'Maintenance Manager'), async (req, res) => {
  try {
    const { id, asset_id, task, type, freq, last_done, next_due, tech, hours, cost, priority, status, alert_days, notes } = req.body;

    if (!id || !asset_id || !task) {
      return res.status(400).json({ success: false, error: 'id, asset_id, and task required' });
    }

    await db.query(
      `INSERT INTO maintenance_schedules (id, asset_id, task, type, freq, last_done, next_due, tech, hours, cost, priority, status, alert_days, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, asset_id, task, type || 'Preventive', freq || 90, last_done, next_due, tech, hours, cost, priority || 'Medium', status || 'Scheduled', alert_days || 7, notes]
    );

    res.status(201).json({ success: true, data: { id, ...req.body } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to create maintenance schedule' });
  }
});

// Complete maintenance task
router.post('/schedules/:id/complete', authenticate, async (req, res) => {
  try {
    const { completion_date, performed_by, hours, cost, parts_used, notes, next_due_override } = req.body;

    if (!completion_date || !performed_by) {
      return res.status(400).json({ success: false, error: 'completion_date and performed_by required' });
    }

    // Get schedule details
    const [schedules] = await db.query('SELECT * FROM maintenance_schedules WHERE id = ?', [req.params.id]);
    if (!schedules || schedules.length === 0) {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }

    const schedule = schedules[0];
    const nextDue = next_due_override || (() => {
      const d = new Date(completion_date);
      d.setDate(d.getDate() + (schedule.freq || 90));
      return d.toISOString().slice(0, 10);
    })();

    // Create log entry
    await db.query(
      `INSERT INTO maintenance_logs (schedule_id, completion_date, performed_by, hours, cost, parts_used, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [req.params.id, completion_date, performed_by, hours, cost, parts_used, notes]
    );

    // Update schedule
    await db.query(
      `UPDATE maintenance_schedules SET status = 'Scheduled', last_done = ?, next_due = ? WHERE id = ?`,
      [completion_date, nextDue, req.params.id]
    );

    const [updated] = await db.query('SELECT * FROM maintenance_schedules WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: updated[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to complete maintenance' });
  }
});

// Get maintenance logs
router.get('/logs', authenticate, async (req, res) => {
  try {
    const { schedule_id } = req.query;
    let query = 'SELECT * FROM maintenance_logs WHERE 1=1';
    const params = [];

    if (schedule_id) {
      query += ' AND schedule_id = ?';
      params.push(schedule_id);
    }

    query += ' ORDER BY completion_date DESC';
    const [logs] = await db.query(query, params);
    res.json({ success: true, data: logs });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch maintenance logs' });
  }
});

export default router;
