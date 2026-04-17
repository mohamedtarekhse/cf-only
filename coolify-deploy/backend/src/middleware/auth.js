import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import db from '../config/database.js';

const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret-change-in-production';
const JWT_EXPIRES_SEC = parseInt(process.env.JWT_EXPIRES_SEC) || 28800;

// Middleware to verify JWT token
export const authenticate = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Authorization required' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Check if user exists and is active
    const [users] = await db.query(
      'SELECT id, email, name, role, active FROM app_users WHERE id = ? AND active = TRUE',
      [decoded.userId]
    );

    if (!users || users.length === 0) {
      return res.status(401).json({ success: false, error: 'User not found or inactive' });
    }

    req.user = users[0];
    req.token = token;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid or expired token' });
  }
};

// Optional authentication - doesn't fail if no token
export const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const [users] = await db.query(
      'SELECT id, email, name, role, active FROM app_users WHERE id = ? AND active = TRUE',
      [decoded.userId]
    );

    if (users && users.length > 0) {
      req.user = users[0];
      req.token = token;
    }
  } catch (err) {
    // Token invalid, but continue without auth
  }

  next();
};

// Role-based authorization
export const authorize = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'Authentication required' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ 
        success: false, 
        error: `Access denied. Required roles: ${allowedRoles.join(', ')}` 
      });
    }

    next();
  };
};

// Generate JWT token
export const generateToken = (user) => {
  return jwt.sign(
    { userId: user.id, email: user.email, role: user.role },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_SEC }
  );
};

// Hash password
export const hashPassword = async (password) => {
  return bcrypt.hash(password, 10);
};

// Verify password
export const verifyPassword = async (password, hash) => {
  return bcrypt.compare(password, hash);
};

export default { authenticate, optionalAuth, authorize, generateToken, hashPassword, verifyPassword };
