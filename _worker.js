/**
 * _worker.js ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Cloudflare Pages Worker
 * Calls Supabase REST API with explicit fetch() ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â no custom query builder.
 *
 * Cloudflare Pages ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Settings ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Environment Variables:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   RESEND_API_KEY            (required for /api/send-email)
 *   SUPABASE_ANON_KEY         (or SUPABASE_PUBLISHABLE_KEY for browser/RLS traffic)
 *   JWT_SECRET                (required for /api auth tokens)
 *   JWT_EXPIRES_SEC           (optional, defaults to 28800 = 8h)
 *   CORS_ALLOW_ORIGIN         (optional, defaults to '*')
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    _corsAllowOrigin = env.CORS_ALLOW_ORIGIN || '*';
    if (method === 'OPTIONS') return respond(null, 204);
    if (path === '/health') return respond({ status:'ok', service:'Asset Management (Cloudflare Worker)', ts:new Date().toISOString() });

    if (path.startsWith('/api')) {
      const isLoginRequest = path === '/api/auth/login' && method === 'POST';
      if (!env.JWT_SECRET)
        return respond({ success:false, error:'JWT_SECRET is not configured in Cloudflare Pages environment variables.' }, 500);
      if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY)
        return respond({ success:false, error:'Supabase secrets not configured in Cloudflare Pages environment variables.' }, 500);
      if (!isLoginRequest && !env.SUPABASE_ANON_KEY && !env.SUPABASE_PUBLISHABLE_KEY)
        return respond({ success:false, error:'SUPABASE_ANON_KEY (or SUPABASE_PUBLISHABLE_KEY) is not configured in Cloudflare Pages environment variables.' }, 500);
      try {
        return await router(path, method, url, request, env.SUPABASE_URL.replace(/\/$/,''), env.SUPABASE_SERVICE_ROLE_KEY, env);
      } catch(err) {
        console.error(err);
        return respond({ success:false, error: err.message||'Internal error' }, 500);
      }
    }

    const staticRes = await env.ASSETS.fetch(request);
    return withSecurityHeaders(staticRes);
  }
};

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Direct Supabase REST calls ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬

// Module-level role context ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â set per request in router()
let _corsAllowOrigin = '*';
const _allowedRoles = new Set(['Admin','Manager','Superintendent','Drilling Manager','Asset Manager','Maintenance Manager','Project Manager','Engineer','Assistant','Viewer']);
const BCRYPT_COST = 10;

function b64urlEncodeBytes(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
function b64urlEncodeText(text) {
  return b64urlEncodeBytes(new TextEncoder().encode(text));
}
function b64urlDecodeBytes(input) {
  const padded = input.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((input.length + 3) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}
function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
async function hmacSha256Base64Url(input, secret) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name:'HMAC', hash:'SHA-256' },
    false,
    ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(input));
  return b64urlEncodeBytes(new Uint8Array(sig));
}
async function signJwt(claims, secret, expiresSec=28800) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg:'HS256', typ:'JWT' };
  const payload = { ...claims, iat: now, exp: now + Math.max(60, Number(expiresSec) || 28800) };
  const encodedHeader = b64urlEncodeText(JSON.stringify(header));
  const encodedPayload = b64urlEncodeText(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await hmacSha256Base64Url(signingInput, secret);
  return `${signingInput}.${signature}`;
}
async function verifyJwt(token, secret) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) throw new Error('Malformed token');
  const [encodedHeader, encodedPayload, signature] = parts;
  const header = JSON.parse(new TextDecoder().decode(b64urlDecodeBytes(encodedHeader)));
  if (header.alg !== 'HS256') throw new Error('Unsupported token algorithm');
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const expectedSig = await hmacSha256Base64Url(signingInput, secret);
  if (!timingSafeEqual(signature, expectedSig)) throw new Error('Invalid token signature');
  const payload = JSON.parse(new TextDecoder().decode(b64urlDecodeBytes(encodedPayload)));
  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp <= now) throw new Error('Token expired');
  return payload;
}

function utf8Bytes(text) {
  return new TextEncoder().encode(String(text || ''));
}

function bytesToBase64(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

function base64ToBytes(input) {
  const binary = atob(String(input || ''));
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

function base64UrlToBase64(input) {
  const normalized = String(input || '').replace(/-/g, '+').replace(/_/g, '/');
  return normalized + '='.repeat((4 - normalized.length % 4) % 4);
}

function concatBytes(...parts) {
  const arrays = parts.filter(Boolean).map(part => part instanceof Uint8Array ? part : new Uint8Array(part));
  const total = arrays.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of arrays) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function uint32Bytes(value) {
  const out = new Uint8Array(4);
  new DataView(out.buffer).setUint32(0, value >>> 0);
  return out;
}

async function sha256(data) {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', data));
}

async function hmacSha256Bytes(keyBytes, dataBytes) {
  const key = await crypto.subtle.importKey('raw', keyBytes, { name:'HMAC', hash:'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, dataBytes));
}

async function hkdfExtract(saltBytes, ikmBytes) {
  return hmacSha256Bytes(saltBytes, ikmBytes);
}

async function hkdfExpand(prkBytes, infoBytes, length) {
  let prev = new Uint8Array(0);
  const chunks = [];
  let generated = 0;
  let counter = 1;
  while (generated < length) {
    prev = await hmacSha256Bytes(prkBytes, concatBytes(prev, infoBytes, Uint8Array.of(counter)));
    chunks.push(prev);
    generated += prev.length;
    counter += 1;
  }
  return concatBytes(...chunks).slice(0, length);
}

function parseVapidPublicKey(publicKey) {
  const raw = b64urlDecodeBytes(String(publicKey || ''));
  if (raw.length !== 65 || raw[0] !== 4) throw new Error('VAPID_PUBLIC_KEY must be an uncompressed P-256 public key');
  return {
    raw,
    x: b64urlEncodeBytes(raw.slice(1, 33)),
    y: b64urlEncodeBytes(raw.slice(33, 65))
  };
}

async function importVapidPrivateKey(privateKey, publicKey) {
  const pub = parseVapidPublicKey(publicKey);
  return crypto.subtle.importKey(
    'jwk',
    {
      kty: 'EC',
      crv: 'P-256',
      d: String(privateKey || ''),
      x: pub.x,
      y: pub.y,
      ext: true
    },
    { name:'ECDSA', namedCurve:'P-256' },
    false,
    ['sign']
  );
}

async function signVapidJwt(endpoint, subject, publicKey, privateKey) {
  const aud = new URL(endpoint).origin;
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 12 * 60 * 60;
  const header = b64urlEncodeText(JSON.stringify({ alg:'ES256', typ:'JWT' }));
  const payload = b64urlEncodeText(JSON.stringify({ aud, exp, sub: subject }));
  const signingInput = `${header}.${payload}`;
  const key = await importVapidPrivateKey(privateKey, publicKey);
  const sigDer = new Uint8Array(await crypto.subtle.sign({ name:'ECDSA', hash:'SHA-256' }, key, utf8Bytes(signingInput)));
  const joseSig = derToJose(sigDer, 64);
  return `${signingInput}.${b64urlEncodeBytes(joseSig)}`;
}

function derToJose(der, size) {
  const bytes = der instanceof Uint8Array ? der : new Uint8Array(der);
  if (bytes.length === size) return bytes;
  if (bytes[0] !== 0x30) throw new Error('Unexpected DER signature format');
  let offset = 2;
  if (bytes[1] & 0x80) offset = 2 + (bytes[1] & 0x7f);
  if (bytes[offset] !== 0x02) throw new Error('Unexpected DER signature format');
  const rLen = bytes[offset + 1];
  const r = bytes.slice(offset + 2, offset + 2 + rLen);
  offset = offset + 2 + rLen;
  if (bytes[offset] !== 0x02) throw new Error('Unexpected DER signature format');
  const sLen = bytes[offset + 1];
  const s = bytes.slice(offset + 2, offset + 2 + sLen);
  const out = new Uint8Array(size);
  out.set(r.slice(-size / 2), size / 2 - Math.min(r.length, size / 2));
  out.set(s.slice(-size / 2), size - Math.min(s.length, size / 2));
  return out;
}

async function encryptWebPushPayload(subscription, payload) {
  const userPublicRaw = b64urlDecodeBytes(String(subscription?.keys?.p256dh || ''));
  const authSecret = b64urlDecodeBytes(String(subscription?.keys?.auth || ''));
  if (userPublicRaw.length !== 65) throw new Error('Invalid subscription public key');
  if (!authSecret.length) throw new Error('Invalid subscription auth secret');

  const uaPublicKey = await crypto.subtle.importKey('raw', userPublicRaw, { name:'ECDH', namedCurve:'P-256' }, true, []);
  const asKeys = await crypto.subtle.generateKey({ name:'ECDH', namedCurve:'P-256' }, true, ['deriveBits']);
  const asPublicRaw = new Uint8Array(await crypto.subtle.exportKey('raw', asKeys.publicKey));
  const sharedSecret = new Uint8Array(await crypto.subtle.deriveBits({ name:'ECDH', public: uaPublicKey }, asKeys.privateKey, 256));

  const prkKey = await hkdfExtract(authSecret, sharedSecret);
  const keyInfo = concatBytes(utf8Bytes('WebPush: info'), Uint8Array.of(0), userPublicRaw, asPublicRaw);
  const ikm = await hkdfExpand(prkKey, keyInfo, 32);

  const salt = crypto.getRandomValues(new Uint8Array(16));
  const contentPrk = await hkdfExtract(salt, ikm);
  const cek = await hkdfExpand(contentPrk, utf8Bytes('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdfExpand(contentPrk, utf8Bytes('Content-Encoding: nonce\0'), 12);
  const plainBytes = concatBytes(utf8Bytes(JSON.stringify(payload || {})), Uint8Array.of(0x02));

  const cekKey = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const ciphertext = new Uint8Array(await crypto.subtle.encrypt({ name:'AES-GCM', iv: nonce, tagLength: 128 }, cekKey, plainBytes));

  const header = concatBytes(salt, uint32Bytes(4096), Uint8Array.of(asPublicRaw.length), asPublicRaw);
  return concatBytes(header, ciphertext);
}

function nowIso() {
  return new Date().toISOString();
}

function isMissingColumnError(error, column='password_changed_at') {
  const msg = String(error?.message || error || '');
  return msg.toLowerCase().includes(String(column).toLowerCase()) && /column|schema cache/i.test(msg);
}

function parseTimestampSeconds(value) {
  if (!value) return null;
  const ms = Date.parse(String(value));
  if (!Number.isFinite(ms)) return null;
  return Math.floor(ms / 1000);
}

function userHeaders(anonKey, userJwt, extra={}) {
  return {
    'apikey': anonKey,
    'Authorization': `Bearer ${userJwt}`,
    'Content-Type': 'application/json',
    ...extra
  };
}

function bypassHeaders(key, extra={}) {
  return {
    'apikey': key,
    'Authorization': `Bearer ${key}`,
    'Content-Type': 'application/json',
    ...extra
  };
}

function resolveHeaders(auth, extra={}, { bypass=false }={}, ctx=null) {
  if (bypass) {
    const serviceKey = typeof auth === 'string' ? auth : String(auth?.serviceKey || auth?.key || '');
    return bypassHeaders(serviceKey, extra);
  }
  const anonKey = typeof auth === 'string' ? auth : String(auth?.anonKey || auth?.key || '');
  const userJwt = typeof auth === 'object'
    ? String(typeof auth?.getJwt === 'function' ? auth.getJwt() : (auth?.jwt || ctx?.reqToken || ''))
    : String(ctx?.reqToken || '');
  return userHeaders(anonKey, userJwt, extra);
}

async function sbGetCore(base, auth, table, { select='*', filters={}, order=null, limit=null, single=false, bypass=false }={}, ctx=null) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', select);
  for (const [k,v] of Object.entries(filters)) u.searchParams.append(k, v);
  if (order) u.searchParams.set('order', order);
  if (limit) u.searchParams.set('limit', String(limit));
  const h = resolveHeaders(auth, {}, { bypass }, ctx);
  if (single) h['Accept'] = 'application/vnd.pgjson';
  const r = await fetch(u.toString(), { headers:h });
  return parseRes(r, single);
}

async function sbPostCore(base, auth, table, body, { bypass=false }={}, ctx=null) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', '*');
  const r = await fetch(u.toString(), { method:'POST', headers:resolveHeaders(auth, {'Prefer':'return=representation'}, { bypass }, ctx), body:JSON.stringify(body) });
  return parseRes(r, true);
}

async function sbPatchCore(base, auth, table, filters, body, { bypass=false }={}, ctx=null) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', '*');
  for (const [k,v] of Object.entries(filters)) u.searchParams.append(k, v);
  const r = await fetch(u.toString(), { method:'PATCH', headers:resolveHeaders(auth, {'Prefer':'return=representation'}, { bypass }, ctx), body:JSON.stringify(body) });
  return parseRes(r, true);
}

async function sbRpcCore(base, auth, fnName, args={}, { bypass=false }={}, ctx=null) {
  const u = new URL(`${base}/rest/v1/rpc/${fnName}`);
  const r = await fetch(u.toString(), {
    method:'POST',
    headers:resolveHeaders(auth, {'Prefer':'return=representation'}, { bypass }, ctx),
    body:JSON.stringify(args)
  });
  return parseRes(r, true);
}

async function sbDeleteCore(base, auth, table, filters, { bypass=false }={}, ctx=null) {
  const u = new URL(`${base}/rest/v1/${table}`);
  for (const [k,v] of Object.entries(filters)) u.searchParams.append(k, v);
  const r = await fetch(u.toString(), { method:'DELETE', headers:resolveHeaders(auth, {'Prefer':'return=minimal'}, { bypass }, ctx) });
  if (r.ok || r.status===204) return { error:null };
  const t = await r.text(); let m; try{m=JSON.parse(t)?.message}catch(_){m=t}
  return { error:{ message:`${r.status}: ${m}` } };
}

async function sbCountCore(base, auth, table, { bypass=false }={}, ctx=null) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select','*'); u.searchParams.set('limit','0');
  const r = await fetch(u.toString(), { headers:resolveHeaders(auth, {'Prefer':'count=exact'}, { bypass }, ctx) });
  return parseInt((r.headers.get('content-range')||'0/0').split('/')[1])||0;
}
async function parseRes(r, single) {
  const text = await r.text();
  let data; try{data=JSON.parse(text)}catch(_){data=null}
  if (!r.ok) return { data:null, error:{ message: data?.message||data?.error||`HTTP ${r.status}: ${text.slice(0,300)}` }};
  if (single) return { data: Array.isArray(data)?(data[0]??null):data, error:null };
  return { data: data??[], error:null };
}

async function hashPassword(base, auth, plain, cost=BCRYPT_COST, ctx=null) {
  const raw = String(plain || '');
  if (!raw) throw new Error('Password is required');
  const safeCost = Math.max(4, Math.min(12, Number(cost) || BCRYPT_COST));
  const { data, error } = await sbRpcCore(base, auth, 'app_hash_password', {
    plain_password: raw,
    cost_factor: safeCost
  }, { bypass:true }, ctx);
  if (error || !data) throw new Error(error?.message || 'Password hashing failed');
  return String(data);
}

async function verifyPassword(base, auth, plain, stored, ctx=null) {
  const input = String(plain || '');
  const hash  = String(stored || '').trim();
  if (!hash) return false;

  // Bcrypt hash - try via Supabase RPC (requires 032_auth_password_bcrypt.sql run)
  if (hash.startsWith('$2')) {
    try {
      const { data, error } = await sbRpcCore(base, auth, 'app_verify_password', {
        plain_password: input,
        stored_hash: hash
      }, { bypass:true }, ctx);
      if (error) {
        const msg = String(error.message || '');
        console.error('[verifyPassword] RPC error:', msg,
          '- run 032_auth_password_bcrypt.sql in Supabase to enable bcrypt verification');
        if (/app_verify_password|schema cache|function/i.test(msg)) {
          throw new Error('PASSWORD_VERIFICATION_NOT_CONFIGURED');
        }
        return false;
      }
      return data === true;
    } catch (e) {
      const msg = String(e?.message || e || '');
      console.error('[verifyPassword] RPC exception:', msg);
      if (msg === 'PASSWORD_VERIFICATION_NOT_CONFIGURED' || /app_verify_password|schema cache|function/i.test(msg)) {
        throw new Error('PASSWORD_VERIFICATION_NOT_CONFIGURED');
      }
      return false;
    }
  }

  return input === hash;
}
function forbidden(ctx, action) {
  return respond({ success:false, error:`Forbidden - your role (${ctx?.reqRole || 'Viewer'}) cannot ${action}` }, 403);
}

async function resolveRequestUserStatus(base, auth, ctx) {
  const rawEmail = String(ctx?.reqEmail || '').trim();
  const email = rawEmail.toLowerCase();
  const userId = String(ctx?.reqUserId || '').trim();
  const tables = ['app_users'];
  const selectWithPasswordChange = 'id,email,active,password_changed_at';
  const selectBasic = 'id,email,active';

  async function getStatus(opts) {
    const first = await sbGetCore(base, auth, opts.table, {
      ...opts,
      select: selectWithPasswordChange,
      bypass: true
    }, ctx);
    if (!first.error || !isMissingColumnError(first.error)) return first;
    return await sbGetCore(base, auth, opts.table, {
      ...opts,
      select: selectBasic,
      bypass: true
    }, ctx);
  }

  for (const table of tables) {
    if (userId) {
      const byId = await getStatus({ table, filters: { id: `eq.${userId}` }, single: true });
      if (!byId.error && byId.data) {
        return { user: byId.data, source: table, error: null };
      }
    }

    if (rawEmail) {
      const exactVariants = [...new Set([rawEmail, email].filter(Boolean))];
      for (const candidate of exactVariants) {
        const exact = await getStatus({ table, filters: { email: `eq.${candidate}` }, single: true });
        if (!exact.error && exact.data) {
          return { user: exact.data, source: table, error: null };
        }
      }

      const fuzzy = await getStatus({
        table,
        filters: { email: `ilike.*${email}*` },
        order: 'email.asc',
        limit: 25
      });
      if (fuzzy.error) {
        return { user: null, source: null, error: fuzzy.error };
      }
      const rows = Array.isArray(fuzzy.data) ? fuzzy.data : [];
      const match = rows.find(r => String(r?.email || '').trim().toLowerCase() === email);
      if (match) {
        return { user: match, source: table, error: null };
      }
    }
  }
  return { user: null, source: null, error: null };
}
async function router(path, method, url, request, SB, KEY, env={}) {
  const q    = url.searchParams;
  const seg  = path.replace(/^\/api\/?/,'').split('/');
  const res  = seg[0];
  const id   = seg[1];
  const act  = seg[2];
  const body = ['POST','PUT','PATCH'].includes(method) ? await request.json().catch(()=>({})) : {};

  const anonKey = env.SUPABASE_ANON_KEY || env.SUPABASE_PUBLISHABLE_KEY || '';
  const ctx = { reqRole:'Viewer', reqName:'', reqUserId:'', reqEmail:'', reqToken:'', reqActive:true, reqClientId:'', reqClientName:'' };
  const dbAuth = {
    anonKey,
    serviceKey: KEY,
    getJwt: () => String(ctx.reqToken || '')
  };
  const sbGet = (base, key, table, opts={}) => sbGetCore(base, dbAuth, table, opts, ctx);
  const sbPost = (base, key, table, payload) => sbPostCore(base, dbAuth, table, payload, {}, ctx);
  const sbPatch = (base, key, table, filters, payload) => sbPatchCore(base, dbAuth, table, filters, payload, {}, ctx);
  const sbRpc = (base, key, fnName, args={}) => sbRpcCore(base, dbAuth, fnName, args, {}, ctx);
  const sbDelete = (base, key, table, filters) => sbDeleteCore(base, dbAuth, table, filters, {}, ctx);
  const sbCount = (base, key, table) => sbCountCore(base, dbAuth, table, {}, ctx);
  const sbGetBypass = (base, key, table, opts={}) => sbGetCore(base, dbAuth, table, { ...opts, bypass:true }, ctx);
  const sbPostBypass = (base, key, table, payload) => sbPostCore(base, dbAuth, table, payload, { bypass:true }, ctx);
  const sbPatchBypass = (base, key, table, filters, payload) => sbPatchCore(base, dbAuth, table, filters, payload, { bypass:true }, ctx);
  const sbRpcBypass = (base, key, fnName, args={}) => sbRpcCore(base, dbAuth, fnName, args, { bypass:true }, ctx);
  const sbDeleteBypass = (base, key, table, filters) => sbDeleteCore(base, dbAuth, table, filters, { bypass:true }, ctx);
  const sbCountBypass = (base, key, table) => sbCountCore(base, dbAuth, table, { bypass:true }, ctx);

  const isClientAdmin = () => ctx.reqRole === 'Admin';
  const currentClientId = () => String(ctx.reqClientId || '').trim();
  const currentClientName = () => String(ctx.reqClientName || '').trim();
  const scopedFilters = (filters = {}, field = 'client_id') => {
    const next = { ...filters };
    if (isClientAdmin()) return next;
    const clientId = currentClientId();
    next[field] = clientId ? `eq.${clientId}` : 'eq.__missing_client__';
    return next;
  };
  const requireClientScope = () => {
    if (isClientAdmin()) return null;
    if (currentClientId()) return null;
    return respond({ success:false, error:'Your account is not linked to a client.' }, 403);
  };
  const applyClientPayload = (payload = {}, fallbackClientId = currentClientId()) => {
    const next = { ...payload };
    if (!isClientAdmin() && fallbackClientId) next.client_id = fallbackClientId;
    return next;
  };
  async function lookupAssetClientId(assetId) {
    if (!assetId) return '';
    const res = await sbGetBypass(SB, KEY, 'assets', { select: 'client_id', filters: { asset_id: `eq.${assetId}` }, single: true });
    return String(res?.data?.client_id || '');
  }
  async function lookupRigClientId(rigName) {
    if (!rigName) return '';
    const res = await sbGetBypass(SB, KEY, 'rigs', { select: 'client_id', filters: { name: `eq.${rigName}` }, single: true });
    if (!res?.error && res?.data?.client_id) return String(res.data.client_id || '');
    const alt = await sbGetBypass(SB, KEY, 'rigs', { select: 'client_id', filters: { rig_name: `eq.${rigName}` }, single: true });
    return String(alt?.data?.client_id || '');
  }
  async function enrichClientName(clientId) {
    if (!clientId) return '';
    const res = await sbGetBypass(SB, KEY, 'clients', { select: 'id,name', filters: { id: `eq.${clientId}` }, single: true });
    return String(res?.data?.name || '');
  }
  function notificationScopeFilters(userId) {
    const or = userId ? `(user_id.is.null,user_id.eq.${userId})` : '(user_id.is.null)';
    return { or };
  }
  async function findUserByIdentity(identifier, clientId='') {
    const raw = String(identifier || '').trim();
    if (!raw) return null;
    const normalized = raw.toLowerCase();
    const filters = clientId ? { client_id: `eq.${clientId}` } : {};
    if (normalized.includes('@')) {
      const exact = await sbGetBypass(SB, KEY, 'app_users', {
        select: 'id,email,name,role,active,client_id',
        filters: { ...filters, email: `eq.${normalized}` },
        single: true
      });
      if (!exact.error && exact.data) return exact.data;
      const fuzzy = await sbGetBypass(SB, KEY, 'app_users', {
        select: 'id,email,name,role,active,client_id',
        filters: { ...filters, email: `ilike.*${normalized}*` },
        limit: 5
      });
      if (!fuzzy.error && Array.isArray(fuzzy.data)) {
        const match = fuzzy.data.find(u => String(u.email || '').trim().toLowerCase() === normalized);
        if (match) return match;
      }
      return null;
    }
    const byName = await sbGetBypass(SB, KEY, 'app_users', {
      select: 'id,email,name,role,active,client_id',
      filters: { ...filters, name: `ilike.*${raw}*` },
      limit: 20
    });
    if (byName.error || !Array.isArray(byName.data)) return null;
    const exactName = byName.data.find(u => String(u.name || '').trim().toLowerCase() === normalized);
    return exactName || byName.data[0] || null;
  }
  function transferEventRoleTargets(eventType) {
    switch (eventType) {
      case 'transfer_request':
        return ['Admin', 'Manager', 'Superintendent'];
      case 'transfer_stage1':
        return ['Admin', 'Manager', 'Drilling Manager'];
      case 'transfer_stage2':
        return ['Admin', 'Manager', 'Asset Manager'];
      case 'transfer_stage3':
      case 'transfer_completed':
      case 'transfer_rejected':
      default:
        return ['Admin', 'Manager'];
    }
  }
  function transferNotificationContent(eventType, transfer, actorName='') {
    const assetLabel = String(transfer?.asset_name || transfer?.asset_id || 'Asset').trim();
    const transferId = String(transfer?.id || '').trim();
    const dest = String(transfer?.destination || transfer?.dest_rig || '').trim();
    const actor = actorName ? ` by ${actorName}` : '';
    switch (eventType) {
      case 'transfer_request':
        return {
          title: `Transfer Request ${transferId || ''}`.trim(),
          description: `${assetLabel} transfer requested${dest ? ` to ${dest}` : ''}.`,
          kind: 'blue'
        };
      case 'transfer_stage1':
        return {
          title: `Stage 1 ${String(transfer?.status || '').includes('Reject') ? 'Decision' : 'Approved'}`,
          description: `${assetLabel} transfer was reviewed${actor}. Current status: ${transfer?.status || 'Updated'}.`,
          kind: String(transfer?.status || '').toLowerCase().includes('reject') ? 'red' : 'orange'
        };
      case 'transfer_stage2':
        return {
          title: `Stage 2 Updated`,
          description: `${assetLabel} transfer moved to ${transfer?.status || 'the next stage'}${actor}.`,
          kind: String(transfer?.status || '').toLowerCase().includes('reject') ? 'red' : 'orange'
        };
      case 'transfer_stage3':
      case 'transfer_completed':
        return {
          title: `Transfer Completed`,
          description: `${assetLabel} transfer completed${dest ? ` to ${dest}` : ''}${actor}.`,
          kind: 'green'
        };
      case 'transfer_rejected':
      default:
        return {
          title: `Transfer Rejected`,
          description: `${assetLabel} transfer was rejected${actor}.`,
          kind: 'red'
        };
    }
  }
  async function listTransferRecipients(transfer, eventType) {
    const clientId = String(transfer?.client_id || await lookupAssetClientId(transfer?.asset_id) || await lookupRigClientId(transfer?.dest_rig) || currentClientId()).trim();
    const targetRoles = new Set(transferEventRoleTargets(eventType));
    const approvers = await sbGetBypass(SB, KEY, 'app_users', {
      select: 'id,name,email,role,client_id,active',
      filters: {
        client_id: clientId ? `eq.${clientId}` : 'eq.__missing_client__',
        active: 'eq.true'
      },
      limit: 200,
      order: 'name.asc'
    });
    const recipients = [];
    if (!approvers.error && Array.isArray(approvers.data)) {
      for (const user of approvers.data) {
        if (targetRoles.has(String(user.role || ''))) recipients.push(user);
      }
    }
    const requester = await findUserByIdentity(transfer?.requested_by, clientId);
    if (requester && requester.active !== false) recipients.push(requester);
    const seen = new Set();
    return recipients.filter(user => {
      const key = String(user.id || '');
      if (!key || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }
  async function createNotificationForUser(user, payload) {
    return sbPostBypass(SB, KEY, 'notifications', {
      title: payload.title,
      description: payload.description,
      icon: payload.icon || 'fas fa-exchange-alt',
      kind: payload.kind || 'blue',
      link: payload.link || '/?tab=transfers',
      user_id: user?.id || null,
      client_id: user?.client_id || payload.client_id || null,
      event_type: payload.event_type || null,
      is_read: false
    });
  }
  async function deactivatePushSubscriptionByEndpoint(endpoint) {
    if (!endpoint) return;
    await sbPatchBypass(SB, KEY, 'push_subscriptions', { endpoint: `eq.${endpoint}` }, { active: false, updated_at: nowIso() });
  }
  async function sendPushToSubscription(subscription, payload) {
    const publicKey = String(env.VAPID_PUBLIC_KEY || '').trim();
    const privateKey = String(env.VAPID_PRIVATE_KEY || '').trim();
    const subject = String(env.VAPID_SUBJECT || 'mailto:admin@example.com').trim();
    if (!publicKey || !privateKey) return { skipped: true, reason: 'VAPID keys are not configured' };
    const endpoint = String(subscription?.endpoint || '').trim();
    if (!endpoint) return { skipped: true, reason: 'Subscription endpoint missing' };
    try {
      const body = await encryptWebPushPayload(subscription, payload);
      const token = await signVapidJwt(endpoint, subject, publicKey, privateKey);
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'TTL': '60',
          'Urgency': 'high',
          'Content-Encoding': 'aes128gcm',
          'Content-Type': 'application/octet-stream',
          'Authorization': `vapid t=${token}, k=${publicKey}`
        },
        body
      });
      if (res.status === 404 || res.status === 410) {
        await deactivatePushSubscriptionByEndpoint(endpoint);
      }
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        return { error: { message: `Push failed (${res.status}): ${text.slice(0, 200)}` } };
      }
      return { data: true };
    } catch (error) {
      return { error: { message: error?.message || String(error) } };
    }
  }
  async function fanOutTransferNotification(transfer, eventType, actorName='') {
    const recipients = await listTransferRecipients(transfer, eventType);
    if (!recipients.length) return { data: [] };
    const clientId = String(transfer?.client_id || await lookupAssetClientId(transfer?.asset_id) || await lookupRigClientId(transfer?.dest_rig) || '').trim() || null;
    const content = transferNotificationContent(eventType, transfer, actorName);
    const payload = {
      title: content.title,
      description: content.description,
      icon: 'fas fa-exchange-alt',
      kind: content.kind,
      link: transfer?.id ? `/?tab=transfers&transfer=${encodeURIComponent(String(transfer.id))}` : '/?tab=transfers',
      event_type: eventType,
      client_id: clientId
    };
    const results = [];
    for (const user of recipients) {
      await createNotificationForUser(user, payload);
      const subs = await sbGetBypass(SB, KEY, 'push_subscriptions', {
        select: 'id,user_id,client_id,endpoint,p256dh,auth,platform,user_agent,active',
        filters: {
          user_id: `eq.${user.id}`,
          active: 'eq.true'
        },
        limit: 20,
        order: 'updated_at.desc'
      });
      if (!subs.error && Array.isArray(subs.data)) {
        for (const sub of subs.data) {
          const pushPayload = {
            title: payload.title,
            body: payload.description,
            url: payload.link,
            tag: `transfer-${transfer?.id || eventType}`,
            transfer_id: transfer?.id || null,
            event_type: eventType
          };
          results.push(await sendPushToSubscription({
            endpoint: sub.endpoint,
            keys: { p256dh: sub.p256dh, auth: sub.auth }
          }, pushPayload));
        }
      }
    }
    return { data: results };
  }

  // Never trust role headers from clients. Derive request identity from bearer token.
  const isAuthLogin = res === 'auth' && id === 'login' && method === 'POST';
  if (!isAuthLogin) {
    const authz = request.headers.get('authorization') || '';
    const m = authz.match(/^Bearer\s+(.+)$/i);
    if (!m) return respond({ success:false, error:'Missing bearer token' }, 401);
    let claims;
    try {
      claims = await verifyJwt(m[1], env.JWT_SECRET || '');
    } catch (_) {
      return respond({ success:false, error:'Invalid or expired token' }, 401);
    }
    const claimRole = String(claims.app_role || '');
    if (!_allowedRoles.has(claimRole)) return respond({ success:false, code:'INVALID_ROLE', error:'Invalid role in token' }, 403);
    ctx.reqRole = claimRole;
    ctx.reqName = String(claims.name || claims.user_metadata?.name || '');
    ctx.reqUserId = String(claims.sub || '');
    ctx.reqEmail = String(claims.email || '');
    ctx.reqClientId = String(claims.client_id || claims.app_metadata?.client_id || '');
    ctx.reqClientName = String(claims.client_name || claims.app_metadata?.client_name || '');
    ctx.reqToken = String(m[1] || '');

    // Enforce active status on every authenticated request (immediate revoke).
    const status = await resolveRequestUserStatus(SB, dbAuth, ctx);
    if (status.error) {
      return respond({ success:false, error:'Unable to validate account status.' }, 500);
    }
    if (!status.user) {
      return respond({ success:false, error:'Account not found.' }, 401);
    }
    if (status.user.active === false) {
      return respond({ success:false, code:'ACCOUNT_DISABLED', error:'Account is deactivated' }, 403);
    }
    const passwordChangedAtSec = parseTimestampSeconds(status.user.password_changed_at);
    if (passwordChangedAtSec && typeof claims.iat === 'number' && claims.iat < passwordChangedAtSec) {
      return respond({ success:false, code:'PASSWORD_CHANGED', error:'Session expired because your password was changed' }, 401);
    }
    ctx.reqActive = status.user.active !== false;
  } else {
    ctx.reqRole = 'Viewer';
    ctx.reqName = '';
    ctx.reqUserId = '';
    ctx.reqEmail = '';
    ctx.reqClientId = '';
    ctx.reqClientName = '';
    ctx.reqToken = '';
    ctx.reqActive = true;
  }

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Per-request permission flags ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  // Admin              ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ full access
  // Manager tier       ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ view + approve (no add/edit/delete)
  //   Manager          ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ approve all 3 stages
  //   Superintendent   ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ approve stage 1 only
  //   Drilling Manager ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ approve stage 2 only
  //   Asset Manager    ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ approve stage 3 only
  //   Maintenance/Project Manager ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ view only
  // Engineer           ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ edit + view (no add/delete)
  // Assistant          ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ edit + delete + view (delete flagged)
  const R = ctx.reqRole;
  const MANAGER_TIER = ['Manager','Superintendent','Drilling Manager','Asset Manager','Maintenance Manager','Project Manager'];
  const perm = {
    canView:    true,
    canAdd:     R === 'Admin',
    canAddProjects: R === 'Admin' || MANAGER_TIER.includes(R),
    canAddTransfers: R === 'Admin' || MANAGER_TIER.includes(R),
    canEdit:    R === 'Admin',
    canDelete:  R === 'Admin',
    canApproveStage1: ['Admin','Manager','Superintendent'].includes(R),
    canApproveStage2: ['Admin','Manager','Drilling Manager'].includes(R),
    canApproveStage3: ['Admin','Manager','Asset Manager'].includes(R),
    canImport:  R === 'Admin',
    isAdmin:    R === 'Admin',
  };
  perm.canApprove = perm.canApproveStage1 || perm.canApproveStage2 || perm.canApproveStage3;
  perm.canReviewDeleteRequests = R === 'Admin' || MANAGER_TIER.includes(R);

  const DELETE_REQUEST_RESOURCES = {
    assets: { table: 'assets', idColumn: 'asset_id', labelFields: ['name', 'asset_id'] },
    contracts: { table: 'contracts', idColumn: 'id', labelFields: ['id'] },
    rigs: { table: 'rigs', idColumn: 'id', labelFields: ['name', 'id'] },
    projects: { table: 'projects', idColumn: 'project_id', labelFields: ['description', 'project_id'] },
    inspections: { table: 'inspections', idColumn: 'id', labelFields: ['inspection_type', 'id'] },
    workshops: { table: 'workshops', idColumn: 'workshop_id', labelFields: ['name', 'workshop_id'] },
    bom: { table: 'bom_items', idColumn: 'id', labelFields: ['name', 'part_no', 'id'] },
    maintenance: { table: 'maintenance_schedules', idColumn: 'id', labelFields: ['task', 'asset_id', 'id'] },
    certificates: { table: 'certificates', idColumn: 'cert_id', labelFields: ['name', 'cert_id'] },
  };

  function firstMeaningful(row, fields, fallback) {
    for (const field of fields) {
      const value = String(row?.[field] ?? '').trim();
      if (value) return value;
    }
    return fallback;
  }

  function buildDeleteRequestLabel(resource, row, recordId) {
    const fallback = `${resource}:${recordId}`;
    const cfg = DELETE_REQUEST_RESOURCES[resource];
    if (!cfg || !row) return fallback;
    const primary = firstMeaningful(row, cfg.labelFields, recordId);
    if (resource === 'assets') return `${primary} (${recordId})`;
    if (resource === 'projects' && row?.project_id) return `${primary} (${row.project_id})`;
    if (resource === 'workshops' && row?.workshop_id) return `${primary} (${row.workshop_id})`;
    if (resource === 'certificates' && row?.cert_id) return `${primary} (${row.cert_id})`;
    return primary;
  }

  async function createDeleteRequest(resource, recordId, reason='') {
    const cfg = DELETE_REQUEST_RESOURCES[resource];
    if (!cfg) return { error: { message: `Delete approval is not configured for ${resource}.` } };

    const target = await sbGetBypass(SB, KEY, cfg.table, {
      filters: { [cfg.idColumn]: `eq.${recordId}` },
      single: true,
      bypass: true
    }, ctx);
    if (target.error || !target.data) {
      return { error: { message: `Record not found for ${resource}:${recordId}` } };
    }

    const existing = await sbGetBypass(SB, KEY, 'delete_requests', {
      filters: {
        resource: `eq.${resource}`,
        record_id: `eq.${recordId}`,
        status: 'eq.Pending'
      },
      order: 'created_at.desc',
      limit: 1,
      bypass: true
    }, ctx);
    if (!existing.error && Array.isArray(existing.data) && existing.data.length) {
      return { data: existing.data[0], existing: true };
    }

    const requesterName = ctx.reqName || ctx.reqEmail || ctx.reqUserId || 'Unknown';
    const payload = {
      resource,
      record_id: recordId,
      record_label: buildDeleteRequestLabel(resource, target.data, recordId),
      requested_by_user_id: ctx.reqUserId || null,
      requested_by_name: requesterName,
      requested_by_role: ctx.reqRole || 'Assistant',
      reason: String(reason || '').trim() || null,
      status: 'Pending'
    };
    const created = await sbPostBypass(SB, KEY, 'delete_requests', payload);
    if (created.error) return created;
    return { data: created.data };
  }

  async function reviewDeleteRequest(requestId, action, comment='') {
    const reqRow = await sbGetBypass(SB, KEY, 'delete_requests', {
      filters: { id: `eq.${requestId}` },
      single: true,
      bypass: true
    }, ctx);
    if (reqRow.error || !reqRow.data) {
      return { error: { message: 'Delete request not found.' } };
    }
    if (reqRow.data.status !== 'Pending') {
      return { error: { message: `Delete request is already ${String(reqRow.data.status || '').toLowerCase()}.` } };
    }

    const decision = String(action || '').toLowerCase();
    if (!['approve', 'reject'].includes(decision)) {
      return { error: { message: 'Invalid delete review action.' } };
    }

    if (decision == 'approve') {
      const cfg = DELETE_REQUEST_RESOURCES[reqRow.data.resource];
      if (!cfg) return { error: { message: 'Delete request resource is not supported.' } };
      if (reqRow.data.resource === 'bom') {
        const tree = await sbGetBypass(SB, KEY, cfg.table, { order: 'created_at.desc', limit: 5000, bypass: true }, ctx);
        if (tree.error) return tree;
        const rows = Array.isArray(tree.data) ? tree.data : [];
        const collectIds = (parentId) => [
          parentId,
          ...rows
            .filter(item => String(item?.parent_id || '') === String(parentId))
            .flatMap(item => collectIds(item.id))
        ];
        const ids = [...new Set(collectIds(reqRow.data.record_id))].reverse();
        for (const bomId of ids) {
          const del = await sbDeleteBypass(SB, KEY, cfg.table, { [cfg.idColumn]: `eq.${bomId}` });
          if (del.error) return del;
        }
      } else {
        const del = await sbDeleteBypass(SB, KEY, cfg.table, { [cfg.idColumn]: `eq.${reqRow.data.record_id}` });
        if (del.error) return del;
      }
    }

    const patch = {
      status: decision === 'approve' ? 'Approved' : 'Rejected',
      reviewed_by_user_id: ctx.reqUserId || null,
      reviewed_by_name: ctx.reqName || ctx.reqEmail || 'Unknown',
      reviewed_at: new Date().toISOString(),
      review_comment: String(comment || '').trim() || null,
    };
    const updated = await sbPatchBypass(SB, KEY, 'delete_requests', { id: `eq.${requestId}` }, patch);
    if (updated.error) return updated;
    return { data: updated.data };
  }

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Global method-level permission guards ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  // Must run after perm is built and after res/id/act are declared.
  if (res !== 'auth' && method !== 'GET' && method !== 'OPTIONS') {
    if (method === 'POST') {
      const canCreateThisRoute =
        perm.canAdd ||
        (res === 'projects' && !id && perm.canAddProjects) ||
        (res === 'transfers' && !id && perm.canAddTransfers) ||
        (res === 'delete-requests' && id && act === 'review' && perm.canReviewDeleteRequests);
      if (!canCreateThisRoute) return forbidden(ctx, 'create records');
    }
    if (method === 'DELETE' && !perm.canDelete) return forbidden(ctx, 'delete records');
    if ((method === 'PUT' || method === 'PATCH') && !perm.canEdit) {
      const isSelfUserEdit = res === 'users' && id && String(id) === String(ctx.reqUserId);
      if (!isSelfUserEdit) return forbidden(ctx, 'edit records');
    }
  }
  // Transfer approve endpoint requires canApprove (stage check is inside the handler)
  if (res === 'transfers' && act === 'approve' && !perm.canApprove) return forbidden(ctx, 'approve transfers');

  if (res === 'delete-requests') {
    if (method === 'GET' && !id) {
      if (perm.canReviewDeleteRequests) {
        return ok(await sbGetBypass(SB, KEY, 'delete_requests', { order: 'created_at.desc', limit: +(q.get('limit') || 200), bypass: true }, ctx));
      }
      if (R === 'Assistant') {
        return ok(await sbGetBypass(SB, KEY, 'delete_requests', {
          filters: { requested_by_user_id: `eq.${ctx.reqUserId}` },
          order: 'created_at.desc',
          limit: +(q.get('limit') || 100),
          bypass: true
        }, ctx));
      }
      return respond({ success:true, data:[] }, 200);
    }
    if (method === 'POST' && !id) {
      const requested = await createDeleteRequest(String(body.resource || ''), String(body.record_id || ''), body.reason || '');
      if (requested.error) return err500(requested.error);
      return respond({ success:true, data:{ delete_request:true, request: requested.data, existing: !!requested.existing } }, 202);
    }
    if (method === 'POST' && id && act === 'review') {
      if (!perm.canReviewDeleteRequests) return forbidden(ctx, 'review delete requests');
      const reviewed = await reviewDeleteRequest(id, body.action, body.comment || '');
      if (reviewed.error) return err500(reviewed.error);
      return ok(reviewed);
    }
  }

  // AUTH (server-side password check; never expose password field to client)
  if (res === 'auth' && id === 'login' && method === 'POST') {
    const identifierRaw = String(body.email || body.identifier || '').trim();
    const email = identifierRaw.toLowerCase();
    const password = String(body.password || '');
    if (!identifierRaw || !password) return respond({ success:false, error:'email and password required' }, 400);

    let user = null;
    let userSource = 'app_users';
    const userSelect = 'id,name,role,dept,email,color,initials,password,active,client_id';

    for (const table of ['app_users']) {
      const exact = await sbGetBypass(SB, KEY, table, {
        select: userSelect,
        filters: { email: 'eq.' + email },
        single: true,
        bypass: true
      }, ctx);
      if (!exact.error && exact.data) {
        user = exact.data;
        userSource = table;
        break;
      }

      // Legacy compatibility: mixed-case or padded emails.
      const fuzzy = await sbGetBypass(SB, KEY, table, {
        select: userSelect,
        filters: { email: 'ilike.*' + email + '*' },
        order: 'email.asc',
        limit: 50,
        bypass: true
      }, ctx);
      if (fuzzy.error) {
        continue;
      }

      const rows = Array.isArray(fuzzy.data) ? fuzzy.data : [];
      const match = rows.find(r => String(r?.email || '').trim().toLowerCase() === email);
      if (match) {
        user = match;
        userSource = table;
        break;
      }
    }

    if (!user) {
      for (const table of ['app_users']) {
        const byName = await sbGetBypass(SB, KEY, table, {
          select: userSelect,
          filters: { name: 'ilike.*' + identifierRaw + '*' },
          order: 'name.asc',
          limit: 50,
          bypass: true
        }, ctx);
        if (byName.error) continue;
        const rows = Array.isArray(byName.data) ? byName.data : [];
        const match = rows.find(r => String(r?.name || '').trim().toLowerCase() === identifierRaw.toLowerCase());
        if (match) {
          user = match;
          userSource = table;
          break;
        }
      }
    }

    if (!user) return respond({ success:false, error:'Invalid credentials' }, 401);
    if (user.active === false) return respond({ success:false, code:'ACCOUNT_DISABLED', error:'Account is deactivated' }, 403);

    const stored = String(user.password || '').trim();
    if (stored) {
      // Has a stored password ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â verify it
      let valid = false;
      try { valid = await verifyPassword(SB, dbAuth, password, stored, ctx); }
      catch (e) {
        const msg = String(e?.message || e || '');
        console.error('[login] verifyPassword threw:', msg);
        if (msg === 'PASSWORD_VERIFICATION_NOT_CONFIGURED') {
          return respond({
            success:false,
            code:'PASSWORD_VERIFICATION_NOT_CONFIGURED',
            error:'Password verification is not configured in Supabase. Run the bcrypt password SQL fix.'
          }, 500);
        }
      }
      if (!valid) {
        const isHash = stored.startsWith('$2');
        const hint = isHash ? ' (bcrypt ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ensure 032_auth_password_bcrypt.sql is deployed)' : '';
        console.warn('[login] Password mismatch for user:', user?.email, hint);
        return respond({ success:false, error:'Invalid credentials' }, 401);
      }
      // Lazy-upgrade plaintext ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ bcrypt on first successful login
      if (!stored.startsWith('$2')) {
        try {
          const upgradedHash = await hashPassword(SB, dbAuth, password, BCRYPT_COST, ctx);
          await sbPatchBypass(SB, KEY, userSource, { id: `eq.${user.id}` }, { password: upgradedHash });
        } catch (e) {
          console.warn('Password lazy-upgrade failed for user', user?.id, e?.message || e);
        }
      }
    } else {
      // No password stored ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â open login (emergency recovery mode, patch 026)
      console.warn('[login] User', user?.email, 'has no password set ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â open login allowed');
    }

    const normalizedRole = String(user.role || '');
    if (!_allowedRoles.has(normalizedRole)) return respond({ success:false, code:'INVALID_ROLE', error:'User role is not allowed' }, 403);
    const safeUser = { ...user, role: normalizedRole };
    delete safeUser.password;
    const clientId = String(safeUser.client_id || '');
    const clientName = await enrichClientName(clientId);
    if (clientName) safeUser.client_name = clientName;
    const token = await signJwt(
      {
        sub: String(safeUser.id || ''),
        email: safeUser.email || '',
        name: safeUser.name || '',
        client_id: clientId,
        client_name: clientName,
        aud: 'authenticated',
        role: 'authenticated',
        app_role: safeUser.role || 'Viewer',
        app_metadata: { app_role: safeUser.role || 'Viewer', client_id: clientId, client_name: clientName },
        user_metadata: { name: safeUser.name || '' }
      },
      env.JWT_SECRET || '',
      Number(env.JWT_EXPIRES_SEC || 28800)
    );
    return respond({ success:true, data: { token, user: safeUser } });
  }

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ AUTH DEBUG (remove after fixing login) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  if (res === 'auth' && id === 'debug' && method === 'POST') {
    if (ctx.reqRole !== 'Admin') return respond({ success:false, error:'Forbidden' }, 403);
    const identifierRaw = String(body.email || body.identifier || '').trim();
    const email = identifierRaw.toLowerCase();
    const password = String(body.password || '');
    if (!identifierRaw) return respond({ success:false, error:'email required' }, 400);

    const userSelect = 'id,name,role,email,active,password';
    let user = null, userSource = null;

    for (const table of ['app_users']) {
      const r = await sbGetBypass(SB, KEY, table, { select: userSelect, filters: { email: 'eq.' + email }, single: true });
      if (!r.error && r.data) { user = r.data; userSource = table; break; }
      // try name
      const r2 = await sbGetBypass(SB, KEY, table, { select: userSelect, filters: { name: 'ilike.*' + identifierRaw + '*' }, limit: 5 });
      if (!r2.error && Array.isArray(r2.data) && r2.data.length) { user = r2.data[0]; userSource = table; break; }
    }

    if (!user) return respond({ success:true, debug: { found: false, table: null, note: 'No user matched email or name' } });

    const stored = String(user.password || '').trim();
    const isBcrypt = stored.startsWith('$2');
    const hasPassword = stored.length > 0;

    let verifyResult = null;
    if (password && hasPassword) {
      if (isBcrypt) {
        const { data, error } = await sbRpcBypass(SB, KEY, 'app_verify_password', { plain_password: password, stored_hash: stored });
        verifyResult = error ? { rpcError: error.message } : { matches: data === true };
      } else {
        verifyResult = { matches: password === stored, mode: 'plaintext' };
      }
    }

    const roleValid = _allowedRoles.has(String(user.role || ''));

    return respond({ success: true, debug: {
      found: true,
      table: userSource,
      email: user.email,
      name: user.name,
      role: user.role,
      roleValid,
      active: user.active,
      hasPassword,
      isBcrypt,
      passwordLength: stored.length,
      passwordPreview: stored ? stored.slice(0,7) + '...' : '(empty)',
      verifyResult,
    }});
  }

  if (res === 'auth' && id === 'me' && method === 'GET') {
    return respond({
      success:true,
      data: { id: ctx.reqUserId || null, email: ctx.reqEmail || null, name: ctx.reqName || null, role: ctx.reqRole || 'Viewer', active: ctx.reqActive !== false, client_id: ctx.reqClientId || null, client_name: ctx.reqClientName || null }
    });
  }

  if (res === 'clients') {
    if (method === 'GET' && !id) {
      if (isClientAdmin()) return ok(await sbGetBypass(SB, KEY, 'clients', { order: 'name.asc', bypass: true }));
      if (!currentClientId()) return respond({ success:true, data:[] }, 200);
      return ok(await sbGetBypass(SB, KEY, 'clients', { filters: { id: `eq.${currentClientId()}` }, single: false, order: 'name.asc', bypass: true }));
    }
    if (method === 'GET' && id) {
      if (!isClientAdmin() && id !== currentClientId()) return forbidden(ctx, 'view other clients');
      return ok(await sbGetBypass(SB, KEY, 'clients', { filters: { id: `eq.${id}` }, single: true, bypass: true }));
    }
    if (!isClientAdmin()) return forbidden(ctx, 'manage clients');
    if (method === 'POST') return ok(await sbPostBypass(SB, KEY, 'clients', body));
    if (method === 'PUT' || method === 'PATCH') {
      const { id: _id, created_at, updated_at, ...u } = body;
      return ok(await sbPatchBypass(SB, KEY, 'clients', { id: `eq.${id}` }, u));
    }
    if (method === 'DELETE') {
      const r = await sbDeleteBypass(SB, KEY, 'clients', { id: `eq.${id}` });
      if (r.error) return err500(r.error);
      return ok({ deleted: id });
    }
  }

  // ASSETS
  if (res==='assets') {
    if (method==='GET'&&!id) {
      const f={};
      if(q.get('status'))   f.status  =`eq.${q.get('status')}`;
      if(q.get('category')) f.category=`eq.${q.get('category')}`;
      if(q.get('rig_name')) f.rig_name=`eq.${q.get('rig_name')}`;
      if(q.get('search'))   f.name    =`ilike.%${q.get('search')}%`;
      return ok(await sbGet(SB,KEY,'assets',{filters:scopedFilters(f),order:'name.asc',limit:+(q.get('limit')||500)}));
    }
    if(method==='GET')    return ok(await sbGet(SB,KEY,'assets',{filters:scopedFilters({asset_id:`eq.${id}`}),single:true}));
    if(method==='POST')   {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      const payload = applyClientPayload(body, body.client_id || await lookupRigClientId(body.rig_name));
      return ok(await sbPost(SB,KEY,'assets',payload));
    }
    if(method==='PUT')  {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      const {asset_id,created_at,updated_at,...u}=body;
      const payload = applyClientPayload(u, u.client_id || await lookupRigClientId(u.rig_name));
      return ok(await sbPatch(SB,KEY,'assets',scopedFilters({asset_id:`eq.${id}`}),payload));
    }
    if(method==='PATCH')  {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      const payload = applyClientPayload(body, body.client_id || await lookupRigClientId(body.rig_name));
      return ok(await sbPatch(SB,KEY,'assets',scopedFilters({asset_id:`eq.${id}`}),payload));
    }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'assets',scopedFilters({asset_id:`eq.${id}`}));if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // RIGS
  if (res==='rigs') {
    if(method==='GET'&&!id) return ok(await sbGet(SB,KEY,'rigs',{filters:scopedFilters({}),order:'name.asc'}));
    if(method==='GET')    return ok(await sbGet(SB,KEY,'rigs',{filters:scopedFilters({id:`eq.${id}`}),single:true}));
    if(method==='POST') {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      if(!body.id) { const s=(body.name||'RIG').toUpperCase().replace(/[^A-Z0-9]/g,'-').slice(0,12); body.id=s+'-'+Date.now().toString().slice(-5); }
      const payload = applyClientPayload(body, body.client_id || currentClientId());
      return ok(await sbPost(SB,KEY,'rigs',payload));
    }
    if(method==='PUT')  {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      const {id:_,created_at,updated_at,...u}=body;
      const payload = applyClientPayload(u, u.client_id || currentClientId());
      return ok(await sbPatch(SB,KEY,'rigs',scopedFilters({id:`eq.${id}`}),payload));
    }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'rigs',scopedFilters({id:`eq.${id}`}));if(r.error)return err500(r.error);return ok({deleted:id});}
  }



  // CONTRACTS
  if (res==='contracts') {
    if(method==='GET'){
      const {data,error}=await sbGet(SB,KEY,'contracts',{select:'*, contract_assets(asset_id)',order:'id.asc',limit:+(q.get('limit')||200)});
      if(error) return err500(error);
      return ok((data||[]).map(c=>({...c,asset_count:(c.contract_assets||[]).length,contract_assets:undefined})));
    }
    if(method==='POST') return ok(await sbPost(SB,KEY,'contracts',body));
    if(method==='PUT'){ const {id:_,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'contracts',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){ const r=await sbDelete(SB,KEY,'contracts',{id:`eq.${id}`}); if(r.error)return err500(r.error); return ok({deleted:id}); }
  }

  // BOM
  if (res==='bom') {
    if(method==='GET'&&!id){
      const f={};
      if(q.get('asset_id')) f.asset_id=`eq.${q.get('asset_id')}`;
      if(q.get('type'))     f.type    =`eq.${q.get('type')}`;
      return ok(await sbGet(SB,KEY,'bom_items',{filters:f,order:'id.asc',limit:+(q.get('limit')||1000)}));
    }
    if(method==='GET')    return ok(await sbGet(SB,KEY,'bom_items',{filters:{id:`eq.${id}`},single:true}));
    if(method==='POST') { if(!body.id) body.id='BOM-'+Date.now().toString().slice(-8); return ok(await sbPost(SB,KEY,'bom_items',body)); }
    if(method==='PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'bom_items',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'bom_items',{id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // CERTIFICATES
  if (res==='certificates') {
    if(method==='GET'&&!id){
      const {data,error}=await sbGet(SB,KEY,'certificates',{select:'*, assets(name,serial,rig_name,category)',filters:scopedFilters({}),order:'cert_id.asc',limit:+(q.get('limit')||500)});
      if(error) return err500(error);
      return ok((data||[]).map(c=>({...c,asset_name:c.assets?.name,asset_serial:c.assets?.serial,rig_name:c.assets?.rig_name,category:c.assets?.category,assets:undefined})));
    }
    if(method==='GET')    return ok(await sbGet(SB,KEY,'certificates',{filters:scopedFilters({cert_id:`eq.${id}`}),single:true}));
    if(method==='POST') {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      if(!body.cert_id) body.cert_id='CERT-'+String((await sbCount(SB,KEY,'certificates'))+1).padStart(3,'0');
      const inferredClientId = body.client_id || await lookupAssetClientId(body.asset_id);
      return ok(await sbPost(SB,KEY,'certificates',applyClientPayload(body, inferredClientId)));
    }
    if(method==='PUT')  {
      const scopeErr = requireClientScope(); if (scopeErr) return scopeErr;
      const {cert_id,created_at,updated_at,...u}=body;
      const inferredClientId = u.client_id || await lookupAssetClientId(u.asset_id);
      return ok(await sbPatch(SB,KEY,'certificates',scopedFilters({cert_id:`eq.${id}`}),applyClientPayload(u, inferredClientId)));
    }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'certificates',scopedFilters({cert_id:`eq.${id}`}));if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // MAINTENANCE
  if (res==='maintenance') {
    if(method==='POST'&&id&&act==='complete'){
      const {completion_date,performed_by,hours,cost,parts_used,notes,next_due_override}=body;
      if(!completion_date||!performed_by) return respond({success:false,error:'completion_date and performed_by required'},400);
      const {data:sc,error:se}=await sbGet(SB,KEY,'maintenance_schedules',{filters:{id:`eq.${id}`},single:true});
      if(se||!sc) return respond({success:false,error:'Schedule not found'},404);
      const nextDue=next_due_override||(()=>{const d=new Date(completion_date);d.setDate(d.getDate()+(sc.freq||90));return d.toISOString().slice(0,10)})();
      await sbPost(SB,KEY,'maintenance_logs',{schedule_id:id,completion_date,performed_by,hours,cost,parts_used,notes});
      const {data:upd,error:ue}=await sbPatch(SB,KEY,'maintenance_schedules',{id:`eq.${id}`},{status:'Scheduled',last_done:completion_date,next_due:nextDue});
      if(ue) return err500(ue);
      return ok({schedule:{...upd,live_status:liveStatus(upd)}});
    }
    if(method==='GET'&&!id){
      const {data,error}=await sbGet(SB,KEY,'maintenance_schedules',{select:'*, assets(name,rig_name)',order:'next_due.asc',limit:+(q.get('limit')||500)});
      if(error) return err500(error);
      let rows=(data||[]).map(m=>({...m,asset_name:m.assets?.name,rig_name:m.assets?.rig_name,assets:undefined,live_status:liveStatus(m)}));
      if(q.get('asset_id')) rows=rows.filter(r=>r.asset_id===q.get('asset_id'));
      if(q.get('priority')) rows=rows.filter(r=>r.priority===q.get('priority'));
      if(q.get('status'))   rows=rows.filter(r=>r.live_status===q.get('status')||r.status===q.get('status'));
      return ok(rows);
    }
    if(method==='GET')    return ok(await sbGet(SB,KEY,'maintenance_schedules',{filters:{id:`eq.${id}`},single:true}));
    if(method==='POST') {
      if(!body.id) body.id='PM-'+String((await sbCount(SB,KEY,'maintenance_schedules'))+1).padStart(3,'0');
      if(['Overdue','Due Soon'].includes(body.status)) body.status='Scheduled';
      return ok(await sbPost(SB,KEY,'maintenance_schedules',body));
    }
    if(method==='PUT'){ const {id:_,created_at,updated_at,live_status,asset_name,rig_name,assets,...u}=body; if(['Overdue','Due Soon'].includes(u.status)) u.status='Scheduled'; return ok(await sbPatch(SB,KEY,'maintenance_schedules',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'maintenance_schedules',{id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // TRANSFERS
  if (res==='transfers') {
    if(method==='POST'&&id&&act==='approve'){
      const {role,action:decision,comment,approved_by}=body;
      if(!role||!decision||!comment) return respond({success:false,error:'role, action and comment required'},400);
      // Enforce per-stage role: only the correct roles can approve each stage
      if(role==='supt'     && !perm.canApproveStage1) return forbidden(ctx, 'approve Stage 1 (requires Superintendent, Manager, or Admin)');
      if(role==='drilling' && !perm.canApproveStage2) return forbidden(ctx, 'approve Stage 2 (requires Drilling Manager, Manager, or Admin)');
      if(role==='ops'      && !perm.canApproveStage3) return forbidden(ctx, 'approve Stage 3 (requires Asset Manager, Manager, or Admin)');
      const today=new Date().toISOString().slice(0,10);
      let patch={};
      if(role==='supt'){
        patch={supt_approved_by:approved_by,supt_approved_date:today,supt_action:decision,supt_comment:comment,
          status:decision==='approve'?'Supt Approved':decision==='reject'?'Rejected':'On Hold'};
      } else if(role==='drilling'){
        patch={ops_approved_by:approved_by,ops_approved_date:today,ops_action:decision,ops_comment:comment,
          status:decision==='approve'?'Drilling Approved':decision==='reject'?'Rejected':'On Hold'};
      } else if(role==='ops'){
        patch={mgr_approved_by:approved_by,mgr_approved_date:today,mgr_action:decision,mgr_comment:comment,
          status:decision==='approve'?'Completed':decision==='reject'?'Rejected':'On Hold'};
        if(decision==='approve'){
          const {data:tr}=await sbGet(SB,KEY,'transfers',{filters:{id:`eq.${id}`},single:true});
          if(tr){ const au={location:tr.destination}; if(tr.dest_rig) au.rig_name=tr.dest_rig; await sbPatch(SB,KEY,'assets',{asset_id:`eq.${tr.asset_id}`},au); }
        }
      } else return respond({success:false,error:'role must be supt, drilling or ops'},400);
      const updated = await sbPatch(SB,KEY,'transfers',{id:`eq.${id}`},patch);
      if (updated.error) return err500(updated.error);
      const eventType =
        decision === 'reject' ? 'transfer_rejected' :
        role === 'supt' ? 'transfer_stage1' :
        role === 'drilling' ? 'transfer_stage2' :
        decision === 'approve' ? 'transfer_completed' : 'transfer_stage3';
      await fanOutTransferNotification(updated.data || { ...patch, id }, eventType, approved_by || ctx.reqName || ctx.reqEmail || '');
      return ok(updated);
    }
    if(method==='GET'){
      const f={};
      if(q.get('status'))   f.status  =`eq.${q.get('status')}`;
      if(q.get('priority')) f.priority=`eq.${q.get('priority')}`;
      return ok(await sbGet(SB,KEY,'transfers',{filters:f,order:'created_at.desc',limit:+(q.get('limit')||200)}));
    }
    if(method==='POST'){
      if(!body.id) body.id='TR-'+String((await sbCount(SB,KEY,'transfers'))+1).padStart(3,'0');
      if(!body.request_date) body.request_date=new Date().toISOString().slice(0,10);
      if(!body.asset_name&&body.asset_id){ const {data:a}=await sbGet(SB,KEY,'assets',{select:'name,location',filters:{asset_id:`eq.${body.asset_id}`},single:true}); if(a){body.asset_name=a.name;if(!body.current_loc)body.current_loc=a.location;} }
      const created = await sbPost(SB,KEY,'transfers',body);
      if (created.error) return err500(created.error);
      await fanOutTransferNotification(created.data || body, 'transfer_request', body.requested_by || ctx.reqName || ctx.reqEmail || '');
      return ok(created);
    }
  }
  // USERS
  if (res==='users') {
    if (method==='GET' && !id) {
      if (ctx.reqRole === 'Admin') {
        return ok(await sbGetBypass(SB,KEY,'app_users',{select:'id,name,role,dept,email,color,initials,active,client_id',order:'name.asc',bypass:true}));
      }
      return ok(await sbGetBypass(SB,KEY,'app_users',{select:'id,name,role,dept,email,color,initials,active,client_id',filters:{id:`eq.${ctx.reqUserId}`},single:false,bypass:true}));
    }
    if (method==='GET' && id) {
      if (ctx.reqRole !== 'Admin' && String(id) !== String(ctx.reqUserId)) return forbidden(ctx, 'view other user accounts');
      return ok(await sbGetBypass(SB,KEY,'app_users',{select:'id,name,role,dept,email,color,initials,active,client_id',filters:{id:`eq.${id}`},single:true,bypass:true}));
    }
    if(method==='POST'&&id&&act==='reset-password') {
      if (ctx.reqRole !== 'Admin') return respond({ success:false, error:'Forbidden' }, 403);
      const newPassword = String(body.new_password || '').trim();
      if (newPassword.length < 4) return respond({ success:false, error:'new_password must be at least 4 characters' }, 400);
      const hashed = await hashPassword(SB, dbAuth, newPassword, BCRYPT_COST, ctx);
      let r = await sbPatch(SB, KEY, 'app_users', { id:`eq.${id}` }, { password: hashed, password_changed_at: nowIso() });
      if (r?.error && isMissingColumnError(r.error)) {
        r = await sbPatch(SB, KEY, 'app_users', { id:`eq.${id}` }, { password: hashed });
      }
      if (r?.error) return err500(r.error);
      return respond({ success:true, data:{ id, password_updated:true, session_revoked:true } });
    }
    if(method==='POST') {
      if (ctx.reqRole !== 'Admin') return forbidden(ctx, 'create user accounts');
      const payload = applyClientPayload({ ...body }, body.client_id || currentClientId());
      const hadPassword = typeof payload.password === 'string' && payload.password.trim();
      if (hadPassword) {
        payload.password = await hashPassword(SB, dbAuth, payload.password, BCRYPT_COST, ctx);
        payload.password_changed_at = nowIso();
      } else {
        delete payload.password;
      }
      let r = await sbPost(SB, KEY, 'app_users', payload);
      if (r?.error && hadPassword && isMissingColumnError(r.error)) {
        delete payload.password_changed_at;
        r = await sbPost(SB, KEY, 'app_users', payload);
      }
      if (r?.data) delete r.data.password;
      return ok(r);
    }
    if(method==='PUT' || method==='PATCH')  {
      const isSelf = String(id) === String(ctx.reqUserId);
      if (ctx.reqRole !== 'Admin' && !isSelf) return forbidden(ctx, 'edit other user accounts');
      const {id:_,created_at,updated_at,...raw}=body;
      const u = { ...raw };
      if (ctx.reqRole !== 'Admin') {
        delete u.role;
        delete u.active;
        delete u.client_id;
      }
      const payload = applyClientPayload(u, u.client_id || currentClientId());
      const hadPassword = typeof payload.password === 'string' && payload.password.trim();
      if (typeof payload.password === 'string') {
        if (hadPassword) {
          payload.password = await hashPassword(SB, dbAuth, payload.password, BCRYPT_COST, ctx);
          payload.password_changed_at = nowIso();
        } else {
          delete payload.password;
        }
      }
      let r = await sbPatch(SB,KEY,'app_users',{id:`eq.${id}`},payload);
      if (r?.error && hadPassword && isMissingColumnError(r.error)) {
        delete payload.password_changed_at;
        r = await sbPatch(SB,KEY,'app_users',{id:`eq.${id}`},payload);
      }
      if (r?.data) delete r.data.password;
      return ok(r);
    }
    if(method==='DELETE'){
      if (ctx.reqRole !== 'Admin') return forbidden(ctx, 'delete user accounts');
      if (String(id) === String(ctx.reqUserId)) return respond({ success:false, error:'Admin cannot delete the currently signed-in account.' }, 400);
      const r=await sbDelete(SB,KEY,'app_users',{id:`eq.${id}`});
      if(r.error)return err500(r.error);
      return ok({deleted:id});
    }
  }



  // INSPECTIONS
  if (res==='inspections') {
    if(method==='GET'&&!id){
      const f={};

      if(q.get('inspection_type')) f.inspection_type =`eq.${q.get('inspection_type')}`;
      if(q.get('rig_name'))        f.rig_name        =`eq.${q.get('rig_name')}`;
      return ok(await sbGet(SB,KEY,'inspections',{filters:f,order:'start_date.desc',limit:+(q.get('limit')||1000)}));
    }
    if(method==='GET')   return ok(await sbGet(SB,KEY,'inspections',{filters:{id:`eq.${id}`},single:true}));
    if(method==='POST')  return ok(await sbPost(SB,KEY,'inspections',body));
    if(method==='PUT')   { const {id:_i,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'inspections',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){ const r=await sbDelete(SB,KEY,'inspections',{id:`eq.${id}`}); if(r.error)return err500(r.error); return ok({deleted:id}); }
  }

  // PROJECTS
  if (res==='projects') {
    if(method==='GET'&&!id){
      const f={};
      if(q.get('status'))   f.status  =`eq.${q.get('status')}`;
      if(q.get('rig_name')) f.rig_name=`eq.${q.get('rig_name')}`;

      if(q.get('priority')) f.priority=`eq.${q.get('priority')}`;
      return ok(await sbGet(SB,KEY,'projects',{filters:f,order:'created_at.desc',limit:+(q.get('limit')||500)}));
    }
    if(method==='GET')   return ok(await sbGet(SB,KEY,'projects',{filters:{project_id:`eq.${id}`},single:true}));
    if(method==='POST')  { if(!body.project_id) body.project_id='PRJ-'+Date.now().toString().slice(-8); return ok(await sbPost(SB,KEY,'projects',body)); }
    if(method==='PUT')   { const {id:_i,project_id:_p,created_at,updated_at,budget,spent,...u}=body; return ok(await sbPatch(SB,KEY,'projects',{project_id:`eq.${id}`},u)); }
    if(method==='DELETE'){ const r=await sbDelete(SB,KEY,'projects',{project_id:`eq.${id}`}); if(r.error)return err500(r.error); return ok({deleted:id}); }
  }


  // WORKSHOPS
  if (res==='workshops') {
    if (method==='GET' && !id) {
      const f = {};
      if (q.get('status'))       f.status       = `eq.${q.get('status')}`;
      if (q.get('assigned_rig')) f.assigned_rig = `eq.${q.get('assigned_rig')}`;
      if (q.get('asset_id'))     f.asset_id     = `eq.${q.get('asset_id')}`;
      if (q.get('location'))     f.location     = `eq.${q.get('location')}`;
      return ok(await sbGet(SB, KEY, 'workshops', {
        filters: f,
        order: 'created_at.desc',
        limit: +(q.get('limit') || 500),
      }));
    }
    if (method==='GET')
      return ok(await sbGet(SB, KEY, 'workshops', { filters: { workshop_id: `eq.${id}` }, single: true }));
    if (method==='POST') {
      if (!body.workshop_id) body.workshop_id = 'WS-' + Date.now().toString().slice(-6);
      return ok(await sbPost(SB, KEY, 'workshops', body));
    }
    if (method==='PUT') {
      const { id: _i, created_at, updated_at, ...u } = body;
      return ok(await sbPatch(SB, KEY, 'workshops', { workshop_id: `eq.${id}` }, u));
    }
    if (method==='PATCH') {
      const { id: _i, created_at, updated_at, ...u } = body;
      return ok(await sbPatch(SB, KEY, 'workshops', { workshop_id: `eq.${id}` }, u));
    }
    if (method==='DELETE') {
      const r = await sbDelete(SB, KEY, 'workshops', { workshop_id: `eq.${id}` });
      if (r.error) return err500(r.error);
      return ok({ deleted: id });
    }
  }

  if (res === 'push-subscriptions') {
    if (method === 'GET' && id === 'public-key') {
      if (!env.VAPID_PUBLIC_KEY) return respond({ success:false, error:'Push notifications are not configured.' }, 500);
      return respond({ success:true, data:{ publicKey: String(env.VAPID_PUBLIC_KEY || '') } });
    }
    if (method === 'POST' && id === 'test') {
      const subs = await sbGetBypass(SB, KEY, 'push_subscriptions', {
        select: 'id,user_id,client_id,endpoint,p256dh,auth,platform,user_agent,active',
        filters: {
          user_id: `eq.${ctx.reqUserId}`,
          active: 'eq.true'
        },
        limit: 20,
        order: 'updated_at.desc'
      });
      if (subs.error) return err500(subs.error);
      const rows = Array.isArray(subs.data) ? subs.data : [];
      if (!rows.length) return respond({ success:false, error:'No active push subscription found for this account.' }, 404);
      const payload = {
        title: 'Push notifications enabled',
        body: 'Transfer alerts will now appear on this device.',
        url: '/?tab=transfers',
        tag: `push-test-${Date.now()}`,
        event_type: 'push_test'
      };
      const results = [];
      for (const sub of rows) {
        results.push(await sendPushToSubscription({
          endpoint: sub.endpoint,
          keys: { p256dh: sub.p256dh, auth: sub.auth }
        }, payload));
      }
      const failures = results.filter(r => r?.error);
      if (failures.length === results.length) {
        return respond({ success:false, error: failures[0]?.error?.message || 'Push test failed.' }, 502);
      }
      return respond({ success:true, data:{ sent: results.length, failures: failures.length } });
    }
    if (method === 'GET' && !id) {
      return ok(await sbGetBypass(SB, KEY, 'push_subscriptions', {
        select: 'id,endpoint,platform,user_agent,active,created_at,updated_at',
        filters: { user_id: `eq.${ctx.reqUserId}`, active: 'eq.true' },
        order: 'updated_at.desc',
        limit: 20
      }));
    }
    if (method === 'POST') {
      const endpoint = String(body?.endpoint || '').trim();
      const p256dh = String(body?.keys?.p256dh || body?.p256dh || '').trim();
      const auth = String(body?.keys?.auth || body?.auth || '').trim();
      if (!endpoint || !p256dh || !auth) return respond({ success:false, error:'Push subscription endpoint and keys are required.' }, 400);
      const existing = await sbGetBypass(SB, KEY, 'push_subscriptions', {
        select: 'id',
        filters: { user_id: `eq.${ctx.reqUserId}`, endpoint: `eq.${endpoint}` },
        single: true
      });
      const payload = {
        user_id: ctx.reqUserId || null,
        client_id: currentClientId() || null,
        endpoint,
        p256dh,
        auth,
        platform: String(body?.platform || request.headers.get('sec-ch-ua-platform') || '').slice(0, 200) || null,
        user_agent: String(body?.user_agent || request.headers.get('user-agent') || '').slice(0, 500) || null,
        is_standalone: body?.is_standalone === true,
        active: true,
        updated_at: nowIso(),
        last_used_at: nowIso()
      };
      if (!existing.error && existing.data?.id) {
        return ok(await sbPatchBypass(SB, KEY, 'push_subscriptions', { id: `eq.${existing.data.id}` }, payload));
      }
      payload.created_at = nowIso();
      return ok(await sbPostBypass(SB, KEY, 'push_subscriptions', payload));
    }
    if (method === 'DELETE') {
      if (id && id !== 'current') {
        return ok(await sbPatchBypass(SB, KEY, 'push_subscriptions', { id: `eq.${id}`, user_id: `eq.${ctx.reqUserId}` }, { active: false, updated_at: nowIso() }));
      }
      const endpoint = String(body?.endpoint || '').trim();
      if (!endpoint) return respond({ success:false, error:'Subscription endpoint is required.' }, 400);
      return ok(await sbPatchBypass(SB, KEY, 'push_subscriptions', { endpoint: `eq.${endpoint}`, user_id: `eq.${ctx.reqUserId}` }, { active: false, updated_at: nowIso() }));
    }
  }

  // SEND EMAIL (via Resend)
  if (res === 'send-email') {
    if (method !== 'POST') return respond({ success:false, error:'POST only' }, 405);
    const RESEND_KEY = env.RESEND_API_KEY;
    if (!RESEND_KEY) return respond({ success:false, error:'RESEND_API_KEY not configured' }, 500);
    const { to, subject, html, text, from_name } = body;
    if (!to || !subject || (!html && !text)) return respond({ success:false, error:'Missing to/subject/html' }, 400);
    const recipients = Array.isArray(to) ? to : to.split(/[;,]/).map(s=>s.trim()).filter(Boolean);
    if (!recipients.length) return respond({ success:false, error:'No valid recipients' }, 400);
    const payload = {
      from: `${from_name || 'Asset Management System'} <alerts@resend.dev>`,
      to: recipients,
      subject,
      ...(html ? { html } : {}),
      ...(text ? { text } : {}),
    };
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${RESEND_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await r.json();
    if (!r.ok) return respond({ success:false, error: data.message || data.name || 'Resend error', detail: data }, r.status);
    return respond({ success:true, id: data.id, recipients: recipients.length });
  }


  // NOTIFICATIONS
  if (res==='notifications') {
    if(method==='PATCH'&&id==='mark-all-read') return ok(await sbPatch(SB,KEY,'notifications',{...notificationScopeFilters(ctx.reqUserId),is_read:`eq.false`},{is_read:true}));
    if(method==='PATCH'&&id) return ok(await sbPatch(SB,KEY,'notifications',{...notificationScopeFilters(ctx.reqUserId),id:`eq.${id}`},{is_read:true}));
    if(method==='GET')   return ok(await sbGet(SB,KEY,'notifications',{filters:notificationScopeFilters(ctx.reqUserId),order:'created_at.desc',limit:50}));
    if(method==='POST')  return ok(await sbPost(SB,KEY,'notifications',body));
  }

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ GENERIC REGISTER TABLE HELPER ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  // Handles: reg-bop, reg-well-head, reg-well-control, reg-fire-extinguishers, reg-scba
  const REG_TABLE_MAP = {
    'reg-bop':                'reg_bop',
    'reg-well-head':          'reg_well_head',
    'reg-well-control':       'reg_well_control',
    'reg-fire-extinguishers': 'reg_fire_extinguishers',
    'reg-scba':               'reg_scba',
  };

  if (REG_TABLE_MAP[res]) {
    const tbl = REG_TABLE_MAP[res];

    // GET all records
    if (method === 'GET' && !id) {
      const f = {};
      if (q.get('rig')) f.rig = `eq.${q.get('rig')}`;
      return ok(await sbGet(SB, KEY, tbl, {
        filters: f,
        order: 'created_at.desc',
        limit: +(q.get('limit') || 500),
      }));
    }

    // GET single record by UUID id
    if (method === 'GET' && id) {
      return ok(await sbGet(SB, KEY, tbl, { filters: { id: `eq.${id}` }, single: true }));
    }

    // POST ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â create new entry
    if (method === 'POST') {
      // Remove any client-generated id ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â let Supabase uuid_generate_v4() handle it
      const { id: _cid, reg_id: _rid, created_at: _ca, updated_at: _ua, inspection_status: _is, ...insert } = body;
      return ok(await sbPost(SB, KEY, tbl, insert));
    }

    // PUT ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â full update by UUID id
    if (method === 'PUT') {
      const { id: _i, reg_id: _r, created_at: _ca, updated_at: _ua, inspection_status: _is, ...update } = body;
      return ok(await sbPatch(SB, KEY, tbl, { id: `eq.${id}` }, update));
    }

    // PATCH ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â partial update by UUID id
    if (method === 'PATCH') {
      const { id: _i, reg_id: _r, created_at: _ca, updated_at: _ua, inspection_status: _is, ...update } = body;
      return ok(await sbPatch(SB, KEY, tbl, { id: `eq.${id}` }, update));
    }

    // DELETE ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â remove by UUID id
    if (method === 'DELETE') {
      const r = await sbDelete(SB, KEY, tbl, { id: `eq.${id}` });
      if (r.error) return err500(r.error);
      return ok({ deleted: id });
    }
  }

  return respond({ success:false, error:`Route not found: ${method} ${path}` }, 404);
}

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Helpers ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
function liveStatus(m) {
  if(['Completed','Cancelled','In Progress'].includes(m.status)) return m.status;
  const today=new Date(); today.setHours(0,0,0,0);
  const due=new Date(m.next_due);
  if(due<today) return 'Overdue';
  if(due-today<=(m.alert_days||14)*86400000) return 'Due Soon';
  return 'Scheduled';
}
function ok(r)     { if(r?.error) return err500(r.error); return respond({success:true, data:r?.data??r}); }
function err500(e) { return respond({success:false, error:e?.message||String(e)}, 500); }
function respond(body, status=200) {
  return new Response(JSON.stringify(body), { status, headers:{
    'Content-Type':'application/json',
    'Access-Control-Allow-Origin': _corsAllowOrigin,
    'Access-Control-Allow-Methods':'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers':'Content-Type,Authorization,x-api-key',
    'X-Content-Type-Options':'nosniff',
    'X-Frame-Options':'DENY',
    'Referrer-Policy':'strict-origin-when-cross-origin',
    'Permissions-Policy':'camera=(), microphone=(), geolocation=()',
  }});
}


function withSecurityHeaders(response) {
  const h = new Headers(response.headers);
  h.set('X-Content-Type-Options', 'nosniff');
  h.set('X-Frame-Options', 'DENY');
  h.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  h.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  h.set('Cross-Origin-Opener-Policy', 'same-origin');
  h.set('Cross-Origin-Resource-Policy', 'same-origin');
  h.set('Content-Security-Policy',
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " +
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com; " +
    "font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com data:; " +
    "img-src 'self' data: blob:; " +
    "connect-src 'self' https://api.anthropic.com https://generativelanguage.googleapis.com https://api.openai.com https://openrouter.ai; " +
    "object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self';");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers: h });
}












