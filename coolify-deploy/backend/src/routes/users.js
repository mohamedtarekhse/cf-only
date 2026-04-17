import express from 'express';
import db from '../config/database.js';
import { authenticate, authorize, hashPassword } from '../middleware/auth.js';

const router = express.Router();

// Get all users (Admin sees all, others see only themselves)
router.get('/', authenticate, async (req, res) => {
  try {
    let query;
    let params = [];

    if (req.user.role === 'Admin') {
      query = 'SELECT id, name, role, dept, email, color, initials, active, client_id FROM app_users ORDER BY name ASC';
    } else {
      query = 'SELECT id, name, role, dept, email, color, initials, active, client_id FROM app_users WHERE id = ?';
      params = [req.user.id];
    }

    const [users] = await db.query(query, params);
    res.json({ success: true, data: users });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch users' });
  }
});

// Get single user
router.get('/:id', authenticate, async (req, res) => {
  try {
    // Non-admin can only view their own profile
    if (req.user.role !== 'Admin' && parseInt(req.params.id) !== req.user.id) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const [users] = await db.query(
      'SELECT id, name, role, dept, email, color, initials, active, client_id FROM app_users WHERE id = ?',
      [req.params.id]
    );

    if (!users || users.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.json({ success: true, data: users[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch user' });
  }
});

// Create user (Admin only)
router.post('/', authenticate, authorize('Admin'), async (req, res) => {
  try {
    const { name, role, dept, email, password, color, initials, active, client_id } = req.body;

    if (!name || !email) {
      return res.status(400).json({ success: false, error: 'name and email required' });
    }

    // Check if email already exists
    const [existing] = await db.query('SELECT id FROM app_users WHERE email = ?', [email]);
    if (existing && existing.length > 0) {
      return res.status(400).json({ success: false, error: 'Email already exists' });
    }

    // Hash password if provided
    let hashedPassword = null;
    if (password) {
      hashedPassword = await hashPassword(password);
    }

    await db.query(
      `INSERT INTO app_users (name, role, dept, email, password, color, initials, active, client_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [name, role || 'Viewer', dept, email.toLowerCase(), hashedPassword, color || '#0070F2', initials, active !== false, client_id]
    );

    res.status(201).json({ success: true, data: { name, role, dept, email, color, initials, active: active !== false, client_id } });
  } catch (err) {
    console.error('Error creating user:', err);
    res.status(500).json({ success: false, error: 'Failed to create user' });
  }
});

// Update user
router.put('/:id', authenticate, async (req, res) => {
  try {
    // Non-admin can only update their own profile (except role/active)
    if (req.user.role !== 'Admin' && parseInt(req.params.id) !== req.user.id) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const { name, role, dept, password, color, initials, active, client_id } = req.body;
    let updates = { name, dept, color, initials, client_id };

    // Admin can update role and active status
    if (req.user.role === 'Admin') {
      if (role) updates.role = role;
      if (typeof active !== 'undefined') updates.active = active;
    }

    // Hash password if provided
    if (password) {
      updates.password = await hashPassword(password);
    }

    // Remove undefined values
    Object.keys(updates).forEach(key => updates[key] === undefined && delete updates[key]);

    const fields = Object.keys(updates);
    if (fields.length === 0) {
      return res.status(400).json({ success: false, error: 'No fields to update' });
    }

    const values = [...Object.values(updates), req.params.id];
    const setClause = fields.map(f => `${f} = ?`).join(', ');

    await db.query(`UPDATE app_users SET ${setClause} WHERE id = ?`, values);

    const [updated] = await db.query(
      'SELECT id, name, role, dept, email, color, initials, active, client_id FROM app_users WHERE id = ?',
      [req.params.id]
    );

    res.json({ success: true, data: updated[0] });
  } catch (err) {
    console.error('Error updating user:', err);
    res.status(500).json({ success: false, error: 'Failed to update user' });
  }
});

// Delete user (Admin only)
router.delete('/:id', authenticate, authorize('Admin'), async (req, res) => {
  try {
    // Prevent deleting own account
    if (parseInt(req.params.id) === req.user.id) {
      return res.status(400).json({ success: false, error: 'Cannot delete your own account' });
    }

    await db.query('DELETE FROM app_users WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: { deleted: req.params.id } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to delete user' });
  }
});

// Reset user password (Admin only)
router.post('/:id/reset-password', authenticate, authorize('Admin'), async (req, res) => {
  try {
    const { new_password } = req.body;

    if (!new_password || new_password.length < 4) {
      return res.status(400).json({ success: false, error: 'Password must be at least 4 characters' });
    }

    const hashedPassword = await hashPassword(new_password);
    
    await db.query(
      'UPDATE app_users SET password = ?, password_changed_at = NOW() WHERE id = ?',
      [hashedPassword, req.params.id]
    );

    res.json({ success: true, data: { id: req.params.id, password_updated: true } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to reset password' });
  }
});

export default router;
