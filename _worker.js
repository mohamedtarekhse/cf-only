/**
 * _worker.js — Cloudflare Pages Worker
 * Asset Integrity & Certification Tracking System
 * Oil & Gas — Land Drilling Operations
 *
 * SECRETS (set via wrangler or Cloudflare Dashboard):
 *   SUPABASE_URL              = https://xxxx.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY = your-service-role-key
 *   API_SECRET_KEY            = your-internal-api-key
 *   RESEND_API_KEY            = your-resend-api-key  (for email alerts)
 *   ALERT_FROM_EMAIL          = alerts@yourdomain.com
 *   ALERT_TO_EMAILS           = eng@co.com,mgr@co.com  (comma-separated)
 *
 * ROUTES:
 *   GET    /health
 *   ── Auth ──
 *   POST   /api/auth/login
 *   POST   /api/auth/logout
 *   GET    /api/auth/me
 *   ── Dashboard ──
 *   GET    /api/dashboard/kpis
 *   GET    /api/dashboard/equipment-by-location
 *   GET    /api/dashboard/cert-expiry
 *   GET    /api/dashboard/inspection-due
 *   ── Locations ──
 *   GET    /api/locations
 *   GET    /api/locations/:id
 *   POST   /api/locations
 *   PUT    /api/locations/:id
 *   ── Companies ──
 *   GET    /api/companies
 *   ── Categories ──
 *   GET    /api/categories
 *   ── Assets ──
 *   GET    /api/assets
 *   GET    /api/assets/:id
 *   POST   /api/assets
 *   PUT    /api/assets/:id
 *   DELETE /api/assets/:id
 *   ── Certificates ──
 *   GET    /api/certificates
 *   GET    /api/certificates/:id
 *   GET    /api/assets/:id/certificates
 *   POST   /api/certificates
 *   PUT    /api/certificates/:id
 *   ── Inspections ──
 *   GET    /api/inspections
 *   GET    /api/inspections/:id
 *   POST   /api/inspections
 *   PUT    /api/inspections/:id
 *   ── Transfers ──
 *   GET    /api/transfers
 *   GET    /api/transfers/:id
 *   POST   /api/transfers
 *   PUT    /api/transfers/:id
 *   ── Alerts ──
 *   GET    /api/alerts
 *   POST   /api/alerts/run          (manual trigger — also runs on cron)
 *   PUT    /api/alerts/:id/ack
 *   ── Maintenance ──
 *   GET    /api/maintenance
 *   GET    /api/maintenance/:id
 *   POST   /api/maintenance
 *   PUT    /api/maintenance/:id
 *   ── Audit ──
 *   GET    /api/audit
 *   ── Users ──
 *   GET    /api/users
 *   POST   /api/users
 *   PUT    /api/users/:id
 */

// ─────────────────────────────────────────────────────────────
//  CORS & RESPONSE HELPERS
// ─────────────────────────────────────────────────────────────
const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-API-Key',
};

function respond(body, status = 200) {
  return new Response(
    body === null ? null : JSON.stringify(body),
    { status, headers: { 'Content-Type': 'application/json', ...CORS } }
  );
}

function err(msg, status = 400) {
  return respond({ success: false, error: msg }, status);
}

// ─────────────────────────────────────────────────────────────
//  SUPABASE REST HELPERS
// ─────────────────────────────────────────────────────────────
function sbHeaders(key, extra = {}) {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation',
    ...extra,
  };
}

async function sbSelect(base, key, table, {
  select = '*', filters = {}, order = null,
  limit = null, offset = null, single = false
} = {}) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', select);
  for (const [k, v] of Object.entries(filters)) u.searchParams.append(k, v);
  if (order)  u.searchParams.set('order', order);
  if (limit)  u.searchParams.set('limit', String(limit));
  if (offset) u.searchParams.set('offset', String(offset));
  const h = sbHeaders(key);
  if (single) h['Accept'] = 'application/vnd.pgjson';
  const r = await fetch(u.toString(), { headers: h });
  if (!r.ok) return { error: await r.text() };
  return single ? r.json() : r.json();
}

async function sbRPC(base, key, fn, params = {}) {
  const r = await fetch(`${base}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: sbHeaders(key),
    body: JSON.stringify(params),
  });
  if (!r.ok) return { error: await r.text() };
  return r.json();
}

async function sbInsert(base, key, table, body) {
  const r = await fetch(`${base}/rest/v1/${table}`, {
    method: 'POST',
    headers: sbHeaders(key),
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok) return { error: data };
  return Array.isArray(data) ? data[0] : data;
}

async function sbUpdate(base, key, table, id, body) {
  const r = await fetch(`${base}/rest/v1/${table}?id=eq.${id}`, {
    method: 'PATCH',
    headers: sbHeaders(key),
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok) return { error: data };
  return Array.isArray(data) ? data[0] : data;
}

async function sbDelete(base, key, table, id) {
  const r = await fetch(`${base}/rest/v1/${table}?id=eq.${id}`, {
    method: 'DELETE',
    headers: sbHeaders(key),
  });
  if (!r.ok) return { error: await r.text() };
  return { deleted: true };
}

// Query a Supabase VIEW directly
async function sbView(base, key, view, params = {}) {
  return sbSelect(base, key, view, params);
}

// ─────────────────────────────────────────────────────────────
//  MAIN EXPORT
// ─────────────────────────────────────────────────────────────
export default {
  // HTTP requests
  async fetch(request, env) {
    const url    = new URL(request.url);
    const path   = url.pathname;
    const method = request.method.toUpperCase();

    if (method === 'OPTIONS') return respond(null, 204);
    if (path === '/health')   return respond({ status: 'ok', service: 'Asset Integrity & Cert Tracking', ts: new Date().toISOString() });

    if (!path.startsWith('/api')) return env.ASSETS.fetch(request);

    const SB  = (env.SUPABASE_URL || '').replace(/\/$/, '');
    const KEY = env.SUPABASE_SERVICE_ROLE_KEY || '';

    if (!SB || !KEY)
      return err('Supabase secrets not configured', 500);

    try {
      return await router(path, method, url, request, SB, KEY, env);
    } catch (e) {
      console.error(e);
      return err(e.message || 'Internal error', 500);
    }
  },

  // Cron trigger — runs alert check every day at 06:00 UTC
  async scheduled(event, env) {
    const SB  = (env.SUPABASE_URL || '').replace(/\/$/, '');
    const KEY = env.SUPABASE_SERVICE_ROLE_KEY || '';
    if (SB && KEY) await runAlertCheck(SB, KEY, env);
  },
};

// ─────────────────────────────────────────────────────────────
//  ROUTER
// ─────────────────────────────────────────────────────────────
async function router(path, method, url, request, SB, KEY, env) {
  const seg   = path.split('/').filter(Boolean); // ['api','assets','uuid']
  const p1    = seg[1] || '';   // e.g. 'assets'
  const p2    = seg[2] || '';   // e.g. uuid or sub-route
  const p3    = seg[3] || '';   // e.g. 'certificates'

  const body  = ['POST','PUT','PATCH'].includes(method)
    ? await request.json().catch(() => ({}))
    : {};

  // ── /api/auth ───────────────────────────────────────────────
  if (p1 === 'auth') {
    if (p2 === 'login'  && method === 'POST')  return authLogin(body, SB, KEY);
    if (p2 === 'logout' && method === 'POST')  return respond({ success: true });
    if (p2 === 'me'     && method === 'GET')   return authMe(request, SB, KEY);
  }

  // ── /api/dashboard ──────────────────────────────────────────
  if (p1 === 'dashboard') {
    if (p2 === 'kpis')                  return dashKpis(SB, KEY);
    if (p2 === 'equipment-by-location') return dashByLocation(SB, KEY);
    if (p2 === 'cert-expiry')           return dashCertExpiry(SB, KEY, url);
    if (p2 === 'inspection-due')        return dashInspectionDue(SB, KEY);
  }

  // ── /api/locations ──────────────────────────────────────────
  if (p1 === 'locations') {
    if (method === 'GET'  && !p2) return listLocations(url, SB, KEY);
    if (method === 'GET'  &&  p2) return getLocation(p2, SB, KEY);
    if (method === 'POST')        return createLocation(body, SB, KEY);
    if (method === 'PUT'  &&  p2) return updateLocation(p2, body, SB, KEY);
  }

  // ── /api/companies ──────────────────────────────────────────
  if (p1 === 'companies' && method === 'GET') return listCompanies(SB, KEY);

  // ── /api/categories ─────────────────────────────────────────
  if (p1 === 'categories' && method === 'GET') return listCategories(SB, KEY);

  // ── /api/assets ─────────────────────────────────────────────
  if (p1 === 'assets') {
    if (method === 'GET'    && !p2)              return listAssets(url, SB, KEY);
    if (method === 'GET'    &&  p2 && !p3)       return getAsset(p2, SB, KEY);
    if (method === 'POST')                       return createAsset(body, SB, KEY);
    if (method === 'PUT'    &&  p2)              return updateAsset(p2, body, SB, KEY);
    if (method === 'DELETE' &&  p2)              return deleteAsset(p2, SB, KEY);
    // /api/assets/:id/certificates
    if (method === 'GET'    &&  p2 && p3 === 'certificates') return getAssetCerts(p2, SB, KEY);
  }

  // ── /api/certificates ───────────────────────────────────────
  if (p1 === 'certificates') {
    if (method === 'GET'  && !p2) return listCertificates(url, SB, KEY);
    if (method === 'GET'  &&  p2) return getCertificate(p2, SB, KEY);
    if (method === 'POST')        return createCertificate(body, SB, KEY);
    if (method === 'PUT'  &&  p2) return updateCertificate(p2, body, SB, KEY);
  }

  // ── /api/inspections ────────────────────────────────────────
  if (p1 === 'inspections') {
    if (method === 'GET'  && !p2) return listInspections(url, SB, KEY);
    if (method === 'GET'  &&  p2) return getInspection(p2, SB, KEY);
    if (method === 'POST')        return createInspection(body, SB, KEY);
    if (method === 'PUT'  &&  p2) return updateInspection(p2, body, SB, KEY, env);
  }

  // ── /api/transfers ──────────────────────────────────────────
  if (p1 === 'transfers') {
    if (method === 'GET'  && !p2) return listTransfers(url, SB, KEY);
    if (method === 'GET'  &&  p2) return getTransfer(p2, SB, KEY);
    if (method === 'POST')        return createTransfer(body, SB, KEY);
    if (method === 'PUT'  &&  p2) return updateTransfer(p2, body, SB, KEY, env);
  }

  // ── /api/alerts ─────────────────────────────────────────────
  if (p1 === 'alerts') {
    if (method === 'GET'  && !p2)              return listAlerts(url, SB, KEY);
    if (method === 'POST' && p2 === 'run')     return triggerAlerts(SB, KEY, env);
    if (method === 'PUT'  && p3 === 'ack')     return ackAlert(p2, SB, KEY);
  }

  // ── /api/maintenance ────────────────────────────────────────
  if (p1 === 'maintenance') {
    if (method === 'GET'  && !p2) return listMaintenance(url, SB, KEY);
    if (method === 'GET'  &&  p2) return getMaintenance(p2, SB, KEY);
    if (method === 'POST')        return createMaintenance(body, SB, KEY);
    if (method === 'PUT'  &&  p2) return updateMaintenance(p2, body, SB, KEY);
  }

  // ── /api/audit ──────────────────────────────────────────────
  if (p1 === 'audit' && method === 'GET') return listAudit(url, SB, KEY);

  // ── /api/users ──────────────────────────────────────────────
  if (p1 === 'users') {
    if (method === 'GET')         return listUsers(SB, KEY);
    if (method === 'POST')        return createUser(body, SB, KEY);
    if (method === 'PUT' && p2)   return updateUser(p2, body, SB, KEY);
  }

  return err('Not found', 404);
}

// ─────────────────────────────────────────────────────────────
//  AUTH
// ─────────────────────────────────────────────────────────────
async function authLogin({ email, password }, SB, KEY) {
  if (!email || !password) return err('email and password required');
  const r = await fetch(`${SB}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await r.json();
  if (!r.ok) return err(data.error_description || data.msg || 'Login failed', 401);

  // Fetch profile
  const profile = await sbSelect(SB, KEY, 'user_profiles', {
    filters: { email: `eq.${email}` }, single: false
  });

  return respond({
    success: true,
    access_token: data.access_token,
    user: {
      id:    data.user?.id,
      email: data.user?.email,
      profile: Array.isArray(profile) ? profile[0] : profile,
    },
  });
}

async function authMe(request, SB, KEY) {
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '');
  if (!token) return err('No token', 401);
  const r = await fetch(`${SB}/auth/v1/user`, {
    headers: { apikey: KEY, Authorization: `Bearer ${token}` },
  });
  if (!r.ok) return err('Invalid token', 401);
  const user = await r.json();
  const profile = await sbSelect(SB, KEY, 'user_profiles', {
    filters: { email: `eq.${user.email}` }, single: false
  });
  return respond({ success: true, user: { ...user, profile: Array.isArray(profile) ? profile[0] : profile } });
}

// ─────────────────────────────────────────────────────────────
//  DASHBOARD
// ─────────────────────────────────────────────────────────────
async function dashKpis(SB, KEY) {
  const data = await sbView(SB, KEY, 'vw_dashboard_kpis');
  return respond({ success: true, data: Array.isArray(data) ? data[0] : data });
}

async function dashByLocation(SB, KEY) {
  const data = await sbView(SB, KEY, 'vw_equipment_by_location');
  return respond({ success: true, data });
}

async function dashCertExpiry(SB, KEY, url) {
  const days = parseInt(url.searchParams.get('days') || '90');
  const data = await sbView(SB, KEY, 'vw_cert_expiry_report', {
    filters: { days_remaining: `lte.${days}` },
    order: 'days_remaining.asc',
  });
  return respond({ success: true, data });
}

async function dashInspectionDue(SB, KEY) {
  const data = await sbView(SB, KEY, 'vw_inspection_due');
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  LOCATIONS
// ─────────────────────────────────────────────────────────────
async function listLocations(url, SB, KEY) {
  const filters = {};
  const type   = url.searchParams.get('type');
  const status = url.searchParams.get('status');
  if (type)   filters.type   = `eq.${type}`;
  if (status) filters.status = `eq.${status}`;
  const data = await sbSelect(SB, KEY, 'locations', {
    filters,
    order: 'type.asc,name.asc',
  });
  return respond({ success: true, data });
}

async function getLocation(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'locations', {
    filters: { id: `eq.${id}` }, single: false
  });
  const loc = Array.isArray(data) ? data[0] : data;
  if (!loc) return err('Location not found', 404);
  return respond({ success: true, data: loc });
}

async function createLocation(body, SB, KEY) {
  const { code, name, type } = body;
  if (!code || !name || !type) return err('code, name, type required');
  const data = await sbInsert(SB, KEY, 'locations', body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data }, 201);
}

async function updateLocation(id, body, SB, KEY) {
  delete body.id; delete body.created_at;
  const data = await sbUpdate(SB, KEY, 'locations', id, body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  COMPANIES
// ─────────────────────────────────────────────────────────────
async function listCompanies(SB, KEY) {
  const data = await sbSelect(SB, KEY, 'companies', {
    filters: { active: 'eq.true' },
    order: 'name.asc',
  });
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  CATEGORIES
// ─────────────────────────────────────────────────────────────
async function listCategories(SB, KEY) {
  const data = await sbSelect(SB, KEY, 'categories', {
    filters: { active: 'eq.true' },
    order: 'name.asc',
  });
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  ASSETS
// ─────────────────────────────────────────────────────────────
async function listAssets(url, SB, KEY) {
  const filters = {};
  const status      = url.searchParams.get('status');
  const location_id = url.searchParams.get('location_id');
  const category_id = url.searchParams.get('category_id');
  const cert_status = url.searchParams.get('cert_status');
  const search      = url.searchParams.get('search');
  const limit       = url.searchParams.get('limit')  || '200';
  const offset      = url.searchParams.get('offset') || '0';

  if (status)      filters.status      = `eq.${status}`;
  if (location_id) filters.location_id = `eq.${location_id}`;
  if (category_id) filters.category_id = `eq.${category_id}`;
  if (cert_status) filters.cert_status = `eq.${cert_status}`;
  if (search)      filters.name        = `ilike.*${search}*`;

  // Exclude retired/scrapped by default
  if (!status) filters.status = 'not.in.(Retired,Scrapped)';

  const data = await sbSelect(SB, KEY, 'assets', {
    select: `id,asset_id,name,category_name,manufacturer,serial_number,
             status,cert_status,cert_expiry_date,
             location_id,location_code,location_name,
             company_id,acquisition_date,notes`,
    filters,
    order: 'cert_expiry_date.asc.nullslast',
    limit,
    offset,
  });
  return respond({ success: true, data, count: Array.isArray(data) ? data.length : 0 });
}

async function getAsset(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'assets', {
    filters: { id: `eq.${id}` }, single: false
  });
  const asset = Array.isArray(data) ? data[0] : data;
  if (!asset) return err('Asset not found', 404);
  return respond({ success: true, data: asset });
}

async function createAsset(body, SB, KEY) {
  if (!body.name)     return err('name is required');
  if (!body.category_id && !body.category_name) return err('category_id is required');

  // Denormalize category_name if only id given
  if (body.category_id && !body.category_name) {
    const cats = await sbSelect(SB, KEY, 'categories', {
      filters: { id: `eq.${body.category_id}` }, single: false
    });
    body.category_name = Array.isArray(cats) ? cats[0]?.name : null;
  }
  // Denormalize location
  if (body.location_id && !body.location_name) {
    const locs = await sbSelect(SB, KEY, 'locations', {
      filters: { id: `eq.${body.location_id}` }, single: false
    });
    const loc = Array.isArray(locs) ? locs[0] : null;
    if (loc) { body.location_code = loc.code; body.location_name = loc.name; }
  }

  body.asset_id = ''; // let trigger generate it
  const data = await sbInsert(SB, KEY, 'assets', body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data }, 201);
}

async function updateAsset(id, body, SB, KEY) {
  delete body.id; delete body.created_at; delete body.asset_id;

  // Sync location denormalization if location changed
  if (body.location_id) {
    const locs = await sbSelect(SB, KEY, 'locations', {
      filters: { id: `eq.${body.location_id}` }, single: false
    });
    const loc = Array.isArray(locs) ? locs[0] : null;
    if (loc) { body.location_code = loc.code; body.location_name = loc.name; }
  }

  const data = await sbUpdate(SB, KEY, 'assets', id, body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data });
}

async function deleteAsset(id, SB, KEY) {
  // Soft delete — just retire
  const data = await sbUpdate(SB, KEY, 'assets', id, { status: 'Retired' });
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, message: 'Asset retired' });
}

async function getAssetCerts(assetId, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'certificates', {
    filters: { asset_id: `eq.${assetId}` },
    order: 'expiry_date.desc',
  });
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  CERTIFICATES
// ─────────────────────────────────────────────────────────────
async function listCertificates(url, SB, KEY) {
  const filters = {};
  const status      = url.searchParams.get('status');
  const asset_id    = url.searchParams.get('asset_id');
  const is_current  = url.searchParams.get('is_current');
  const expiring    = url.searchParams.get('expiring_days');

  if (status)     filters.status     = `eq.${status}`;
  if (asset_id)   filters.asset_id   = `eq.${asset_id}`;
  if (is_current !== null) filters.is_current = `eq.${is_current || 'true'}`;
  else filters.is_current = 'eq.true';

  const data = await sbSelect(SB, KEY, 'certificates', {
    select: `id,cert_id,asset_id,asset_asset_id,asset_name,
             inspection_type,issued_by,issue_date,expiry_date,
             validity_days,cert_link,cert_number,
             alert_days,alert_sent,status,is_current,notes`,
    filters,
    order: 'expiry_date.asc',
    limit: url.searchParams.get('limit') || '500',
  });
  return respond({ success: true, data });
}

async function getCertificate(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'certificates', {
    filters: { id: `eq.${id}` }, single: false
  });
  const cert = Array.isArray(data) ? data[0] : data;
  if (!cert) return err('Certificate not found', 404);
  return respond({ success: true, data: cert });
}

async function createCertificate(body, SB, KEY) {
  const { asset_id, inspection_type, issue_date, expiry_date } = body;
  if (!asset_id)        return err('asset_id is required');
  if (!inspection_type) return err('inspection_type is required');
  if (!issue_date)      return err('issue_date is required');
  if (!expiry_date)     return err('expiry_date is required');

  // Mark previous certs for this asset+type as superseded
  await sbUpdate(SB, KEY, 'certificates',
    null,  // we use raw filter below
    { is_current: false, status: 'Superseded' }
  );
  // Actually filter by asset_id + inspection_type
  await fetch(
    `${SB}/rest/v1/certificates?asset_id=eq.${asset_id}&inspection_type=eq.${encodeURIComponent(inspection_type)}&is_current=eq.true`,
    {
      method: 'PATCH',
      headers: sbHeaders(KEY),
      body: JSON.stringify({ is_current: false, status: 'Superseded' }),
    }
  );

  body.cert_id    = '';  // trigger generates
  body.is_current = true;
  const data = await sbInsert(SB, KEY, 'certificates', body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data }, 201);
}

async function updateCertificate(id, body, SB, KEY) {
  delete body.id; delete body.created_at; delete body.cert_id;
  const data = await sbUpdate(SB, KEY, 'certificates', id, body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  INSPECTIONS
// ─────────────────────────────────────────────────────────────
async function listInspections(url, SB, KEY) {
  const filters = {};
  const status   = url.searchParams.get('status');
  const asset_id = url.searchParams.get('asset_id');
  if (status)   filters.status   = `eq.${status}`;
  if (asset_id) filters.asset_id = `eq.${asset_id}`;
  const data = await sbSelect(SB, KEY, 'inspections', {
    filters,
    order: 'scheduled_date.asc',
    limit: url.searchParams.get('limit') || '200',
  });
  return respond({ success: true, data });
}

async function getInspection(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'inspections', {
    filters: { id: `eq.${id}` }, single: false
  });
  const insp = Array.isArray(data) ? data[0] : data;
  if (!insp) return err('Inspection not found', 404);
  return respond({ success: true, data: insp });
}

async function createInspection(body, SB, KEY) {
  if (!body.asset_id)        return err('asset_id is required');
  if (!body.inspection_type) return err('inspection_type is required');
  if (!body.scheduled_date)  return err('scheduled_date is required');

  // Set asset status to In Inspection
  await sbUpdate(SB, KEY, 'assets', body.asset_id, { status: 'In Inspection' });

  body.inspection_id = ''; // trigger generates
  const data = await sbInsert(SB, KEY, 'inspections', body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data }, 201);
}

async function updateInspection(id, body, SB, KEY, env) {
  delete body.id; delete body.created_at; delete body.inspection_id;

  // If completing, check overdue
  if (body.status === 'Completed' && !body.performed_date) {
    body.performed_date = new Date().toISOString().split('T')[0];
  }

  const data = await sbUpdate(SB, KEY, 'inspections', id, body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  TRANSFERS
// ─────────────────────────────────────────────────────────────
async function listTransfers(url, SB, KEY) {
  const filters = {};
  const status   = url.searchParams.get('status');
  const asset_id = url.searchParams.get('asset_id');
  if (status)   filters.status   = `eq.${status}`;
  if (asset_id) filters.asset_id = `eq.${asset_id}`;
  const data = await sbSelect(SB, KEY, 'transfers', {
    filters,
    order: 'requested_at.desc',
    limit: url.searchParams.get('limit') || '200',
  });
  return respond({ success: true, data });
}

async function getTransfer(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'transfers', {
    filters: { id: `eq.${id}` }, single: false
  });
  const trf = Array.isArray(data) ? data[0] : data;
  if (!trf) return err('Transfer not found', 404);
  return respond({ success: true, data: trf });
}

async function createTransfer(body, SB, KEY) {
  if (!body.asset_id)        return err('asset_id is required');
  if (!body.to_location_id)  return err('to_location_id is required');

  // Validate asset exists and is not already in transit
  const assets = await sbSelect(SB, KEY, 'assets', {
    filters: { id: `eq.${body.asset_id}` }, single: false
  });
  const asset = Array.isArray(assets) ? assets[0] : null;
  if (!asset) return err('Asset not found', 404);
  if (asset.status === 'In Transit') return err('Asset is already in transit');

  // Capture destination name
  const locs = await sbSelect(SB, KEY, 'locations', {
    filters: { id: `eq.${body.to_location_id}` }, single: false
  });
  const toLoc = Array.isArray(locs) ? locs[0] : null;
  body.to_location    = toLoc?.name || '';
  body.transfer_id    = ''; // trigger generates
  body.status         = 'Pending';

  const data = await sbInsert(SB, KEY, 'transfers', body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data }, 201);
}

async function updateTransfer(id, body, SB, KEY, env) {
  delete body.id; delete body.created_at; delete body.transfer_id;

  // Set timestamps on status changes
  if (body.status === 'Approved'    && !body.approved_at)   body.approved_at   = new Date().toISOString();
  if (body.status === 'In Transit'  && !body.dispatched_at) body.dispatched_at = new Date().toISOString();
  if (body.status === 'Completed'   && !body.received_at)   body.received_at   = new Date().toISOString();

  const data = await sbUpdate(SB, KEY, 'transfers', id, body);
  if (data?.error) return err(JSON.stringify(data.error));

  // Send email on approval
  if (body.status === 'Approved' && env?.RESEND_API_KEY) {
    const trf = Array.isArray(data) ? data[0] : data;
    await sendEmail(env, {
      subject: `Transfer Approved: ${trf?.asset_name} → ${trf?.to_location}`,
      html: `<p>Transfer <strong>${trf?.transfer_id}</strong> has been approved.</p>
             <p>Asset: ${trf?.asset_name}<br>
             From: ${trf?.from_location}<br>
             To: ${trf?.to_location}</p>`
    });
  }

  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  ALERTS
// ─────────────────────────────────────────────────────────────
async function listAlerts(url, SB, KEY) {
  const filters = {};
  const acked   = url.searchParams.get('acknowledged');
  const type    = url.searchParams.get('alert_type');
  if (acked !== null) filters.acknowledged = `eq.${acked || 'false'}`;
  if (type)           filters.alert_type   = `eq.${type}`;
  const data = await sbSelect(SB, KEY, 'alert_log', {
    filters,
    order: 'sent_at.desc',
    limit: url.searchParams.get('limit') || '100',
  });
  return respond({ success: true, data });
}

async function triggerAlerts(SB, KEY, env) {
  const result = await runAlertCheck(SB, KEY, env);
  return respond({ success: true, ...result });
}

async function ackAlert(id, SB, KEY) {
  const data = await sbUpdate(SB, KEY, 'alert_log', id, {
    acknowledged: true, ack_at: new Date().toISOString()
  });
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  ALERT ENGINE (cron + manual trigger)
//
//  Rules:
//  Rule 1 — Cert expiry ≤ 90 days → send email, log alert
//  Rule 2 — Cert expiry ≤ 30 days → send urgent email
//  Rule 3 — Cert expired           → log + mark asset cert_status
//  Rule 4 — Inspection overdue     → log alert
// ─────────────────────────────────────────────────────────────
async function runAlertCheck(SB, KEY, env) {
  const today = new Date().toISOString().split('T')[0];
  let alertsSent = 0;
  let alertsLogged = 0;

  // ── Fetch all current certificates ──────────────────────────
  const certs = await sbSelect(SB, KEY, 'vw_cert_expiry_report', {
    order: 'days_remaining.asc',
  });

  if (!Array.isArray(certs)) return { error: 'Failed to fetch certificates' };

  for (const cert of certs) {
    const days = cert.days_remaining;

    // Rule 1 & 2 — Expiring
    if (days !== null && days >= 0 && days <= 90) {
      const alertType = days <= 30
        ? 'Cert Expiring 30 Days'
        : 'Cert Expiring 90 Days';

      // Check if we already sent this alert today
      const existing = await sbSelect(SB, KEY, 'alert_log', {
        filters: {
          cert_id:    `eq.${cert.cert_id_pk}`,
          alert_type: `eq.${alertType}`,
          sent_at:    `gte.${today}T00:00:00Z`,
        },
      });
      if (Array.isArray(existing) && existing.length > 0) continue;

      // Log alert
      await sbInsert(SB, KEY, 'alert_log', {
        alert_type:     alertType,
        asset_id:       cert.asset_id,    // wait — this is uuid from assets
        asset_name:     cert.asset_name,
        cert_id:        cert.cert_id_pk,
        expiry_date:    cert.expiry_date,
        days_remaining: days,
        channel:        'Both',
      });
      alertsLogged++;

      // Send email
      if (env?.RESEND_API_KEY) {
        const urgency = days <= 30 ? '🚨 URGENT' : '⚠️ WARNING';
        await sendEmail(env, {
          subject: `${urgency}: Certificate Expiring in ${days} Days — ${cert.asset_name}`,
          html: buildCertAlertEmail(cert, days),
        });
        alertsSent++;

        // Mark cert alert_sent
        await fetch(
          `${SB}/rest/v1/certificates?id=eq.${cert.cert_id_pk}`,
          {
            method: 'PATCH',
            headers: sbHeaders(KEY),
            body: JSON.stringify({ alert_sent: true, alert_sent_at: new Date().toISOString() }),
          }
        );
      }
    }

    // Rule 3 — Expired
    if (days !== null && days < 0) {
      const existing = await sbSelect(SB, KEY, 'alert_log', {
        filters: {
          cert_id:    `eq.${cert.cert_id_pk}`,
          alert_type: `eq.Cert Expired`,
          sent_at:    `gte.${today}T00:00:00Z`,
        },
      });
      if (Array.isArray(existing) && existing.length > 0) continue;

      await sbInsert(SB, KEY, 'alert_log', {
        alert_type:     'Cert Expired',
        asset_name:     cert.asset_name,
        cert_id:        cert.cert_id_pk,
        expiry_date:    cert.expiry_date,
        days_remaining: days,
        channel:        'Both',
      });
      alertsLogged++;

      if (env?.RESEND_API_KEY) {
        await sendEmail(env, {
          subject: `❌ EXPIRED: Certificate Expired — ${cert.asset_name}`,
          html: buildCertAlertEmail(cert, days),
        });
        alertsSent++;
      }
    }
  }

  // Rule 4 — Overdue inspections
  const overdueInsp = await sbSelect(SB, KEY, 'inspections', {
    filters: {
      status:         'eq.Scheduled',
      scheduled_date: `lt.${today}`,
    },
  });

  if (Array.isArray(overdueInsp)) {
    for (const insp of overdueInsp) {
      // Mark as overdue
      await sbUpdate(SB, KEY, 'inspections', insp.id, { status: 'Overdue' });
      await sbInsert(SB, KEY, 'alert_log', {
        alert_type: 'Inspection Overdue',
        asset_name: insp.asset_name,
        channel:    'Dashboard',
      });
      alertsLogged++;
    }
  }

  return { alerts_logged: alertsLogged, emails_sent: alertsSent, checked_at: new Date().toISOString() };
}

// ─────────────────────────────────────────────────────────────
//  EMAIL (Resend API)
// ─────────────────────────────────────────────────────────────
async function sendEmail(env, { subject, html }) {
  if (!env?.RESEND_API_KEY) return;
  const toList = (env.ALERT_TO_EMAILS || '').split(',').map(e => e.trim()).filter(Boolean);
  if (!toList.length) return;

  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from:    env.ALERT_FROM_EMAIL || 'alerts@assettracking.com',
      to:      toList,
      subject,
      html,
    }),
  });
}

function buildCertAlertEmail(cert, days) {
  const color  = days < 0 ? '#dc2626' : days <= 30 ? '#d97706' : '#ca8a04';
  const status = days < 0 ? 'EXPIRED' : days <= 30 ? 'EXPIRING SOON (URGENT)' : 'EXPIRING SOON';
  return `
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">
      <div style="background:${color};color:white;padding:20px;border-radius:8px 8px 0 0">
        <h2 style="margin:0">Certificate ${status}</h2>
      </div>
      <div style="border:1px solid #e5e7eb;padding:24px;border-radius:0 0 8px 8px">
        <table style="width:100%;border-collapse:collapse">
          <tr><td style="padding:8px;color:#6b7280;width:160px">Equipment</td>
              <td style="padding:8px;font-weight:bold">${cert.asset_name}</td></tr>
          <tr style="background:#f9fafb">
              <td style="padding:8px;color:#6b7280">Asset ID</td>
              <td style="padding:8px">${cert.asset_id || '—'}</td></tr>
          <tr><td style="padding:8px;color:#6b7280">Category</td>
              <td style="padding:8px">${cert.category_name || '—'}</td></tr>
          <tr style="background:#f9fafb">
              <td style="padding:8px;color:#6b7280">Location</td>
              <td style="padding:8px">${cert.location_name || '—'}</td></tr>
          <tr><td style="padding:8px;color:#6b7280">Certificate No.</td>
              <td style="padding:8px">${cert.cert_number || '—'}</td></tr>
          <tr style="background:#f9fafb">
              <td style="padding:8px;color:#6b7280">Inspection Type</td>
              <td style="padding:8px">${cert.inspection_type}</td></tr>
          <tr><td style="padding:8px;color:#6b7280">Expiry Date</td>
              <td style="padding:8px;color:${color};font-weight:bold">${cert.expiry_date}</td></tr>
          <tr style="background:#f9fafb">
              <td style="padding:8px;color:#6b7280">Days Remaining</td>
              <td style="padding:8px;color:${color};font-weight:bold">${days < 0 ? Math.abs(days) + ' days OVERDUE' : days + ' days'}</td></tr>
        </table>
        ${cert.cert_link ? `<div style="margin-top:16px"><a href="${cert.cert_link}" style="background:#1d4ed8;color:white;padding:10px 20px;border-radius:6px;text-decoration:none">View Certificate</a></div>` : ''}
        <p style="color:#6b7280;font-size:12px;margin-top:24px">
          This is an automated alert from the Asset Integrity & Certification Tracking System.<br>
          Please schedule recertification immediately.
        </p>
      </div>
    </div>`;
}

// ─────────────────────────────────────────────────────────────
//  MAINTENANCE ORDERS
// ─────────────────────────────────────────────────────────────
async function listMaintenance(url, SB, KEY) {
  const filters = {};
  const status   = url.searchParams.get('status');
  const asset_id = url.searchParams.get('asset_id');
  if (status)   filters.status   = `eq.${status}`;
  if (asset_id) filters.asset_id = `eq.${asset_id}`;
  const data = await sbSelect(SB, KEY, 'maintenance_orders', {
    filters,
    order: 'created_at.desc',
    limit: url.searchParams.get('limit') || '200',
  });
  return respond({ success: true, data });
}

async function getMaintenance(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'maintenance_orders', {
    filters: { id: `eq.${id}` }, single: false
  });
  const mo = Array.isArray(data) ? data[0] : data;
  if (!mo) return err('Maintenance order not found', 404);
  return respond({ success: true, data: mo });
}

async function createMaintenance(body, SB, KEY) {
  if (!body.asset_id)    return err('asset_id is required');
  if (!body.description) return err('description is required');
  body.order_id = '';
  const data = await sbInsert(SB, KEY, 'maintenance_orders', body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data }, 201);
}

async function updateMaintenance(id, body, SB, KEY) {
  delete body.id; delete body.created_at; delete body.order_id;
  if (body.status === 'In Progress' && !body.actual_start) {
    body.actual_start = new Date().toISOString();
  }
  if (body.status === 'Completed' && !body.actual_end) {
    body.actual_end = new Date().toISOString();
    // Release asset back to Active
    const mo = await getMOById(id, SB, KEY);
    if (mo?.asset_id) await sbUpdate(SB, KEY, 'assets', mo.asset_id, { status: 'Active' });
  }
  const data = await sbUpdate(SB, KEY, 'maintenance_orders', id, body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data });
}

async function getMOById(id, SB, KEY) {
  const data = await sbSelect(SB, KEY, 'maintenance_orders', {
    filters: { id: `eq.${id}` }, single: false
  });
  return Array.isArray(data) ? data[0] : null;
}

// ─────────────────────────────────────────────────────────────
//  AUDIT LOG
// ─────────────────────────────────────────────────────────────
async function listAudit(url, SB, KEY) {
  const filters = {};
  const table     = url.searchParams.get('table');
  const record_id = url.searchParams.get('record_id');
  if (table)     filters.table_name = `eq.${table}`;
  if (record_id) filters.record_id  = `eq.${record_id}`;
  const data = await sbSelect(SB, KEY, 'audit_log', {
    filters,
    order: 'changed_at.desc',
    limit: url.searchParams.get('limit') || '100',
  });
  return respond({ success: true, data });
}

// ─────────────────────────────────────────────────────────────
//  USERS
// ─────────────────────────────────────────────────────────────
async function listUsers(SB, KEY) {
  const data = await sbSelect(SB, KEY, 'user_profiles', {
    filters: { active: 'eq.true' },
    order:   'full_name.asc',
  });
  return respond({ success: true, data });
}

async function createUser(body, SB, KEY) {
  const { email, password, full_name, role } = body;
  if (!email || !password || !full_name) return err('email, password, full_name required');

  // Create Supabase Auth user
  const r = await fetch(`${SB}/auth/v1/admin/users`, {
    method: 'POST',
    headers: sbHeaders(KEY),
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  const authUser = await r.json();
  if (!r.ok) return err(authUser.msg || 'Failed to create auth user');

  // Create profile
  const profile = await sbInsert(SB, KEY, 'user_profiles', {
    id:        authUser.id,
    email,
    full_name,
    role:      role || 'Viewer',
    department: body.department || null,
    phone:      body.phone || null,
  });
  if (profile?.error) return err(JSON.stringify(profile.error));

  return respond({ success: true, data: profile }, 201);
}

async function updateUser(id, body, SB, KEY) {
  delete body.id; delete body.created_at; delete body.email;
  const data = await sbUpdate(SB, KEY, 'user_profiles', id, body);
  if (data?.error) return err(JSON.stringify(data.error));
  return respond({ success: true, data });
}

// ============================================================
//  END OF _worker.js
//  Next file: index.html (Equipment Registry UI)
// ============================================================
