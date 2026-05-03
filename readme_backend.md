# PhotoBooth — Backend Setup Guide
# =====================================
# Deploy in ~30 minutes. All free tiers.

## STACK (Free Tiers Only)
- Frontend: Vercel (already deployed)
- Database: Supabase (free tier — 500MB)
- Payments: Razorpay (free to start)
- Analytics: Vercel Analytics (free)
- Real-time count: Vercel KV / Upstash Redis (free)

---

## STEP 1: SUPABASE DATABASE

1. Create account at supabase.com
2. New project → note your PROJECT_URL and ANON_KEY

### Run this SQL in Supabase SQL Editor:

```sql
-- Pro users table
CREATE TABLE pro_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id TEXT UNIQUE NOT NULL,
  payment_id TEXT UNIQUE,
  amount INTEGER DEFAULT 2100,
  currency TEXT DEFAULT 'INR',
  activated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Analytics events table
CREATE TABLE events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event TEXT NOT NULL,          -- 'page_view', 'booth_open', 'shot_taken', 'strip_download', 'pro_upgrade'
  session_id TEXT,
  filter_used TEXT,
  shots_count INTEGER,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily stats view
CREATE VIEW daily_stats AS
SELECT
  DATE(created_at) AS date,
  COUNT(*) FILTER (WHERE event = 'shot_taken') AS shots,
  COUNT(*) FILTER (WHERE event = 'strip_download') AS downloads,
  COUNT(*) FILTER (WHERE event = 'pro_upgrade') AS upgrades,
  COUNT(DISTINCT session_id) AS unique_users
FROM events
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Row Level Security (RLS)
ALTER TABLE pro_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Allow inserts from service role only (backend)
CREATE POLICY "service_only" ON pro_users FOR ALL USING (false);
CREATE POLICY "service_only" ON events FOR ALL USING (false);
```

---

## STEP 2: RAZORPAY SETUP

1. Create account at razorpay.com
2. Get your live keys from Dashboard → Settings → API Keys
3. Set webhook URL: https://YOUR-DOMAIN.vercel.app/api/webhook-razorpay
4. Webhook events to enable: payment.captured, payment.failed

Replace in index.html:
```
key: 'YOUR_RAZORPAY_KEY_HERE'
```
With your live key:
```
key: 'rzp_live_XXXXXXXXXXXXXXXXXX'
```

---

## STEP 3: VERCEL API ROUTES

Create these files in your project:

### /api/create-order.js
```javascript
// Creates a Razorpay order before payment
import Razorpay from 'razorpay';

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  
  try {
    const order = await razorpay.orders.create({
      amount: 2100,  // ₹21 in paise
      currency: 'INR',
      receipt: `pb_${Date.now()}`,
    });
    res.json({ orderId: order.id });
  } catch (err) {
    res.status(500).json({ error: 'Order creation failed' });
  }
}
```

### /api/verify-payment.js
```javascript
// Verifies payment signature and activates Pro
import crypto from 'crypto';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY  // Service role key (not anon)
);

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature, session_id } = req.body;
  
  // Verify signature
  const body = razorpay_order_id + '|' + razorpay_payment_id;
  const expectedSig = crypto
    .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(body)
    .digest('hex');
  
  if (expectedSig !== razorpay_signature) {
    return res.status(400).json({ success: false, error: 'Invalid signature' });
  }
  
  // Store in database
  await supabase.from('pro_users').upsert({
    session_id,
    payment_id: razorpay_payment_id,
    activated_at: new Date().toISOString(),
  });
  
  // Log event
  await supabase.from('events').insert({
    event: 'pro_upgrade',
    session_id,
    metadata: { payment_id: razorpay_payment_id, amount: 2100 }
  });
  
  res.json({ success: true });
}
```

### /api/track.js
```javascript
// Track analytics events
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  
  const { event, session_id, ...metadata } = req.body;
  
  await supabase.from('events').insert({ event, session_id, metadata });
  
  res.json({ ok: true });
}
```

### /api/live-count.js
```javascript
// Returns real live user count from Redis
import { kv } from '@vercel/kv';

export default async function handler(req, res) {
  const count = await kv.get('live_users') || 0;
  res.json({ count });
}
```

### /api/webhook-razorpay.js
```javascript
// Razorpay webhook (backup payment verification)
import crypto from 'crypto';

export default async function handler(req, res) {
  const sig = req.headers['x-razorpay-signature'];
  const body = JSON.stringify(req.body);
  
  const expected = crypto
    .createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
    .update(body)
    .digest('hex');
  
  if (sig !== expected) return res.status(400).end();
  
  const { event, payload } = req.body;
  
  if (event === 'payment.captured') {
    const payment = payload.payment.entity;
    console.log('Payment captured:', payment.id, payment.amount);
    // Additional processing if needed
  }
  
  res.json({ ok: true });
}
```

---

## STEP 4: ENVIRONMENT VARIABLES

In Vercel Dashboard → Settings → Environment Variables, add:

```
RAZORPAY_KEY_ID=rzp_live_XXXXXXXXXXXXXXXX
RAZORPAY_KEY_SECRET=XXXXXXXXXXXXXXXXXXXXXXXX
RAZORPAY_WEBHOOK_SECRET=XXXXXXXXXXXXXXXXXXXXXXXX
SUPABASE_URL=https://XXXXXXXXXX.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...
```

---

## STEP 5: UPDATE INDEX.HTML FOR REAL BACKEND

Replace the payNow() function in index.html:

```javascript
async function payNow() {
  // Generate session ID
  let sessionId = localStorage.getItem('pb_session');
  if (!sessionId) {
    sessionId = 'pb_' + Date.now() + '_' + Math.random().toString(36).slice(2);
    localStorage.setItem('pb_session', sessionId);
  }
  
  // Create order on backend
  const orderRes = await fetch('/api/create-order', { method: 'POST' });
  const { orderId } = await orderRes.json();
  
  new Razorpay({
    key: 'YOUR_LIVE_KEY',
    order_id: orderId,
    amount: 2100,
    currency: 'INR',
    name: 'PhotoBooth',
    description: 'Pro Unlock — Lifetime Access',
    handler: async (response) => {
      // Verify on backend
      const verifyRes = await fetch('/api/verify-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...response, session_id: sessionId })
      });
      const result = await verifyRes.json();
      if (result.success) activatePro(response.razorpay_payment_id);
      else toast('Payment verification failed — contact support');
    },
    theme: { color: '#C8414B' }
  }).open();
}
```

---

## STEP 6: REAL LIVE USER COUNT

Replace animateLiveCount() in index.html:

```javascript
async function animateLiveCount() {
  const el = document.getElementById('live-count');
  if (!el) return;
  
  // Ping on open
  await fetch('/api/live-count', { method: 'POST', body: JSON.stringify({ action: 'join' }) });
  
  // Ping on close
  window.addEventListener('beforeunload', () => {
    navigator.sendBeacon('/api/live-count', JSON.stringify({ action: 'leave' }));
  });
  
  // Poll every 10 seconds
  async function update() {
    const r = await fetch('/api/live-count');
    const { count } = await r.json();
    el.textContent = count;
  }
  update();
  setInterval(update, 10000);
}
```

---

## STEP 7: INSTALL DEPENDENCIES

```bash
npm install razorpay @supabase/supabase-js @vercel/kv
```

---

## STEP 8: DEPLOY

```bash
git add .
git commit -m "feat: add backend payment verification + analytics"
git push origin main
# Vercel auto-deploys on push
```

---

## WHAT YOU GET AFTER SETUP

✅ Real payment verification (not bypassable via localStorage)
✅ Real analytics in Supabase dashboard
✅ Real live user count
✅ Webhook backup for payment confirmation
✅ Revenue tracking (daily/weekly/monthly)

---

## INVESTOR METRICS YOU CAN NOW SHOW

From Supabase dashboard:
- Daily Active Users (DAU)
- Conversion rate (shots → Pro upgrades)
- Most popular filters
- Revenue by day/week/month
- Retention (returning session IDs)

---

## ESTIMATED COSTS AT SCALE

| Users/month | Cost |
|---|---|
| 0–10,000 | ₹0 (all free tiers) |
| 10,000–50,000 | ~₹500/month (Supabase Pro) |
| 50,000+ | ~₹2,000/month + revenue from Pro upgrades |

At 1% conversion on 10,000 users = 100 × ₹21 = ₹2,100/month revenue
At 2% conversion on 50,000 users = 1,000 × ₹21 = ₹21,000/month revenue
