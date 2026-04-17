import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import db from './config/database.js';
import authRoutes from './routes/auth.js';
import assetsRoutes from './routes/assets.js';
import rigsRoutes from './routes/rigs.js';
import contractsRoutes from './routes/contracts.js';
import transfersRoutes from './routes/transfers.js';
import usersRoutes from './routes/users.js';
import maintenanceRoutes from './routes/maintenance.js';
import inspectionsRoutes from './routes/inspections.js';
import projectsRoutes from './routes/projects.js';
import workshopsRoutes from './routes/workshops.js';
import notificationsRoutes from './routes/notifications.js';
import pushRoutes from './routes/push.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'Asset Management API',
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/assets', assetsRoutes);
app.use('/api/rigs', rigsRoutes);
app.use('/api/contracts', contractsRoutes);
app.use('/api/transfers', transfersRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/maintenance', maintenanceRoutes);
app.use('/api/inspections', inspectionsRoutes);
app.use('/api/projects', projectsRoutes);
app.use('/api/workshops', workshopsRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/push', pushRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server only if MySQL is connected
db.getConnection((err, connection) => {
  if (err) {
    console.error('Failed to connect to MySQL:', err.message);
    console.log('Server will retry connection on each request...');
  } else {
    console.log('MySQL connected successfully');
    connection.release();
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  });
});

export default app;
