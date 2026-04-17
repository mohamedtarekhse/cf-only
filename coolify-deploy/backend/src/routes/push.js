import express from 'express';
import db from '../config/database.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

// Get public key for push notifications
router.get('/public-key', (req, res) => {
  const vapidPublicKey = process.env.VAPID_PUBLIC_KEY;
  if (!vapidPublicKey) {
    return res.status(500).json({ success: false, error: 'VAPID_PUBLIC_KEY not configured' });
  }
  res.json({ success: true, data: { publicKey: vapidPublicKey } });
});

// Save push subscription
router.post('/subscriptions', authenticate, async (req, res) => {
  try {
    const { endpoint, keys } = req.body;
    
    if (!endpoint || !keys?.p256dh || !keys?.auth) {
      return res.status(400).json({ success: false, error: 'Invalid subscription data' });
    }

    // Check if subscription already exists
    const [existing] = await db.query(
      'SELECT id FROM push_subscriptions WHERE endpoint = ?',
      [endpoint]
    );

    if (existing && existing.length > 0) {
      // Update existing subscription
      await db.query(
        'UPDATE push_subscriptions SET p256dh = ?, auth = ?, active = TRUE, updated_at = NOW() WHERE endpoint = ?',
        [keys.p256dh, keys.auth, endpoint]
      );
    } else {
      // Create new subscription
      await db.query(
        `INSERT INTO push_subscriptions (user_id, client_id, endpoint, p256dh, auth, active)
         VALUES (?, NULL, ?, ?, ?, TRUE)`,
        [req.user.id, endpoint, keys.p256dh, keys.auth]
      );
    }

    res.json({ success: true });
  } catch (err) {
    console.error('Error saving push subscription:', err);
    res.status(500).json({ success: false, error: 'Failed to save subscription' });
  }
});

export default router;
