import express from 'express';
import db from '../config/database.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

// Get all projects
router.get('/', authenticate, async (req, res) => {
  try {
    const { status, rig_name, priority } = req.query;
    let query = 'SELECT * FROM projects WHERE 1=1';
    const params = [];

    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }
    if (rig_name) {
      query += ' AND rig_name = ?';
      params.push(rig_name);
    }
    if (priority) {
      query += ' AND priority = ?';
      params.push(priority);
    }

    query += ' ORDER BY created_at DESC';
    const [projects] = await db.query(query, params);
    res.json({ success: true, data: projects });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch projects' });
  }
});

// Create project
router.post('/', authenticate, async (req, res) => {
  try {
    const { project_id, name, rig_name, status, priority, budget, spent, start_date, end_date, manager, notes } = req.body;

    if (!project_id || !name) {
      return res.status(400).json({ success: false, error: 'project_id and name required' });
    }

    await db.query(
      `INSERT INTO projects (project_id, name, rig_name, status, priority, budget, spent, start_date, end_date, manager, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [project_id, name, rig_name, status || 'Active', priority || 'Medium', budget, spent || 0, start_date, end_date, manager, notes]
    );

    res.status(201).json({ success: true, data: { project_id, ...req.body } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to create project' });
  }
});

export default router;
