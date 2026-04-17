import express from 'express';
import db from '../config/database.js';
import { generateToken, hashPassword, verifyPassword } from '../middleware/auth.js';

const router = express.Router();

// Login endpoint
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Email and password required' });
    }

    // Find user by email
    const [users] = await db.query(
      'SELECT id, email, name, role, password, active FROM app_users WHERE email = ?',
      [email.toLowerCase()]
    );

    if (!users || users.length === 0) {
      // Log failed attempt
      await db.query(
        'INSERT INTO auth_login_events (email, ip_address, user_agent, status) VALUES (?, ?, ?, ?)',
        [email, req.ip, req.get('user-agent'), 'failed']
      );
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const user = users[0];

    // Check if user is active
    if (!user.active) {
      return res.status(403).json({ success: false, error: 'Account is deactivated' });
    }

    // Verify password
    if (!user.password) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const isValid = await verifyPassword(password, user.password);
    if (!isValid) {
      await db.query(
        'INSERT INTO auth_login_events (email, ip_address, user_agent, status) VALUES (?, ?, ?, ?)',
        [email, req.ip, req.get('user-agent'), 'failed']
      );
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    // Generate token
    const token = generateToken(user);

    // Log successful login
    await db.query(
      'INSERT INTO auth_login_events (user_id, email, ip_address, user_agent, status) VALUES (?, ?, ?, ?, ?)',
      [user.id, email, req.ip, req.get('user-agent'), 'success']
    );

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        }
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, error: 'Login failed' });
  }
});

// Get current user info
router.get('/me', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, error: 'Authorization required' });
    }

    const token = authHeader.split(' ')[1];
    const jwt = await import('jsonwebtoken');
    const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret-change-in-production';
    
    const decoded = jwt.default.verify(token, JWT_SECRET);
    
    const [users] = await db.query(
      'SELECT id, email, name, role, dept, color, initials, active FROM app_users WHERE id = ?',
      [decoded.userId]
    );

    if (!users || users.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.json({ success: true, data: users[0] });
  } catch (err) {
    res.status(401).json({ success: false, error: 'Invalid token' });
  }
});

// Get login history
router.get('/login-history', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, error: 'Authorization required' });
    }

    const token = authHeader.split(' ')[1];
    const jwt = await import('jsonwebtoken');
    const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret-change-in-production';
    
    const decoded = jwt.default.verify(token, JWT_SECRET);
    
    const [events] = await db.query(
      'SELECT * FROM auth_login_events WHERE user_id = ? ORDER BY logged_in_at DESC LIMIT 50',
      [decoded.userId]
    );

    res.json({ success: true, data: events });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to fetch login history' });
  }
});

export default router;
