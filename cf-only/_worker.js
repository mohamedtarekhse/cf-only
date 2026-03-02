/**
 * _worker.js — Cloudflare Pages Worker
 * Full backend: handles every /api/* route by calling Supabase REST directly.
 * No Railway. No Express. No API key check — this runs server-side only.
 *
 * Set these in Cloudflare Pages → Settings → Environment Variables:
 *   SUPABASE_URL              = https://tetbgjfltggmejqwntez.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY = sb_publishable_uSHDoMEafLUF1FzAQCVn0Q_JBKTd1Br
 */

export default {
  async fetch(request, env) {
    const url    = new URL(request.url);
    const path   = url.pathname;
    const method = request.method;

    if (method === 'OPTIONS') return cors(null, 204);

    if (path === '/health') {
      return json({ status: 'ok', service: 'Asset Management (Cloudflare Worker)', ts: new Date().toISOString() });
    }

    if (path.startsWith('/api/')) {
      if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
        return json({ success: false, error: 'Supabase secrets not set. Add SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in Cloudflare Pages → Settings → Environment Variables, then redeploy.' }, 500);
      }
      const sb = supabase(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
      try {
        return await router(path, method, url, request, sb);
      } catch (err) {
        console.error('Worker error:', err);
        return json({ success: false, error: err.message || 'Internal error' }, 500);
      }
    }

    return env.ASSETS.fetch(request);
  },
};

async function router(path, method, url, request, sb) {
  const q        = url.searchParams;
  const seg      = path.replace(/^\/api\//, '').split('/');
  const resource = seg[0];
  const id       = seg[1];
  const action   = seg[2];
  const body     = ['POST','PUT','PATCH'].includes(method) ? await request.json().catch(()=>({})) : {};

  // ASSETS
  if (resource === 'assets') {
    if (method === 'GET' && !id) {
      let r = sb.from('assets').select('*').order('name').limit(+(q.get('limit')||500));
      if (q.get('search'))   r = r.ilike('name', `%${q.get('search')}%`);
      if (q.get('status'))   r = r.eq('status',   q.get('status'));
      if (q.get('category')) r = r.eq('category', q.get('category'));
      if (q.get('company'))  r = r.eq('company',  q.get('company'));
      if (q.get('rig_name')) r = r.eq('rig_name', q.get('rig_name'));
      return ok(await r.run());
    }
    if (method === 'GET')    return ok(await sb.from('assets').select('*').eq('asset_id',id).single().run());
    if (method === 'POST')   return ok(await sb.from('assets').insert(body).select().single().run());
    if (method === 'PUT')  { const {asset_id,created_at,updated_at,...u}=body; return ok(await sb.from('assets').update(u).eq('asset_id',id).select().single().run()); }
    if (method === 'PATCH')  return ok(await sb.from('assets').update(body).eq('asset_id',id).select().single().run());
    if (method === 'DELETE') { await sb.from('assets').delete().eq('asset_id',id).run(); return ok({deleted:id}); }
  }

  // RIGS
  if (resource === 'rigs') {
    if (method === 'GET' && !id) return ok(await sb.from('rigs').select('*').order('name').run());
    if (method === 'GET')    return ok(await sb.from('rigs').select('*').eq('id',id).single().run());
    if (method === 'POST')   return ok(await sb.from('rigs').insert(body).select().single().run());
    if (method === 'PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sb.from('rigs').update(u).eq('id',id).select().single().run()); }
    if (method === 'DELETE') { await sb.from('rigs').delete().eq('id',id).run(); return ok({deleted:id}); }
  }

  // COMPANIES
  if (resource === 'companies') {
    if (method === 'GET')    return ok(await sb.from('companies').select('*').order('name').run());
    if (method === 'POST')   return ok(await sb.from('companies').insert(body).select().single().run());
    if (method === 'PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sb.from('companies').update(u).eq('id',id).select().single().run()); }
    if (method === 'DELETE') { await sb.from('companies').delete().eq('id',id).run(); return ok({deleted:id}); }
  }

  // CONTRACTS
  if (resource === 'contracts') {
    if (method === 'GET') {
      const {data,error} = await sb.from('contracts').select('*, contract_assets(asset_id)').order('id').limit(+(q.get('limit')||200)).run();
      if (error) return err500(error);
      return ok((data||[]).map(c=>({...c, asset_count:(c.contract_assets||[]).length, contract_assets:undefined})));
    }
    if (method === 'POST') return ok(await sb.from('contracts').insert(body).select().single().run());
    if (method === 'PUT') { const {id:_,created_at,updated_at,...u}=body; return ok(await sb.from('contracts').update(u).eq('id',id).select().single().run()); }
  }

  // BOM
  if (resource === 'bom') {
    if (method === 'GET' && !id) {
      let r = sb.from('bom_items').select('*').order('id').limit(+(q.get('limit')||1000));
      if (q.get('asset_id')) r = r.eq('asset_id', q.get('asset_id'));
      if (q.get('type'))     r = r.eq('type',     q.get('type'));
      return ok(await r.run());
    }
    if (method === 'GET')    return ok(await sb.from('bom_items').select('*').eq('id',id).single().run());
    if (method === 'POST') { if (!body.id) body.id='BOM-'+Date.now().toString().slice(-8); return ok(await sb.from('bom_items').insert(body).select().single().run()); }
    if (method === 'PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sb.from('bom_items').update(u).eq('id',id).select().single().run()); }
    if (method === 'DELETE') { await sb.from('bom_items').delete().eq('id',id).run(); return ok({deleted:id}); }
  }

  // CERTIFICATES
  if (resource === 'certificates') {
    if (method === 'GET' && !id) {
      const {data,error} = await sb.from('certificates').select('*, assets(name,serial,rig_name,category)').order('cert_id').limit(+(q.get('limit')||500)).run();
      if (error) return err500(error);
      return ok((data||[]).map(c=>({...c, asset_name:c.assets?.name, asset_serial:c.assets?.serial, rig_name:c.assets?.rig_name, category:c.assets?.category, assets:undefined})));
    }
    if (method === 'GET')    return ok(await sb.from('certificates').select('*').eq('cert_id',id).single().run());
    if (method === 'POST') {
      if (!body.cert_id) { const {count}=await sb.from('certificates').count().run(); body.cert_id='CERT-'+String((count||0)+1).padStart(3,'0'); }
      return ok(await sb.from('certificates').insert(body).select().single().run());
    }
    if (method === 'PUT')  { const {cert_id,created_at,updated_at,...u}=body; return ok(await sb.from('certificates').update(u).eq('cert_id',id).select().single().run()); }
    if (method === 'DELETE') { await sb.from('certificates').delete().eq('cert_id',id).run(); return ok({deleted:id}); }
  }

  // MAINTENANCE
  if (resource === 'maintenance') {
    if (method === 'POST' && id && action === 'complete') {
      const {completion_date,performed_by,hours,cost,parts_used,notes,next_due_override} = body;
      if (!completion_date||!performed_by) return json({success:false,error:'completion_date and performed_by required'},400);
      const {data:s,error:se} = await sb.from('maintenance_schedules').select('*').eq('id',id).single().run();
      if (se) return json({success:false,error:'Schedule not found'},404);
      const nextDue = next_due_override||(()=>{ const d=new Date(completion_date); d.setDate(d.getDate()+(s.freq||90)); return d.toISOString().slice(0,10); })();
      await sb.from('maintenance_logs').insert({schedule_id:id,completion_date,performed_by,hours,cost,parts_used,notes}).run();
      const {data:upd,error:ue} = await sb.from('maintenance_schedules').update({status:'Scheduled',last_done:completion_date,next_due:nextDue}).eq('id',id).select().single().run();
      if (ue) return err500(ue);
      return ok({schedule:{...upd,live_status:liveStatus(upd)}});
    }
    if (method === 'GET' && !id) {
      const {data,error} = await sb.from('maintenance_schedules').select('*, assets(name,rig_name,company)').order('next_due').limit(+(q.get('limit')||500)).run();
      if (error) return err500(error);
      let rows = (data||[]).map(m=>({...m, asset_name:m.assets?.name, rig_name:m.assets?.rig_name, company:m.assets?.company, assets:undefined, live_status:liveStatus(m)}));
      if (q.get('asset_id')) rows=rows.filter(r=>r.asset_id===q.get('asset_id'));
      if (q.get('priority')) rows=rows.filter(r=>r.priority===q.get('priority'));
      if (q.get('status'))   rows=rows.filter(r=>r.live_status===q.get('status')||r.status===q.get('status'));
      return ok(rows);
    }
    if (method === 'GET')    return ok(await sb.from('maintenance_schedules').select('*').eq('id',id).single().run());
    if (method === 'POST') {
      if (!body.id) { const {count}=await sb.from('maintenance_schedules').count().run(); body.id='PM-'+String((count||0)+1).padStart(3,'0'); }
      if (['Overdue','Due Soon'].includes(body.status)) body.status='Scheduled';
      return ok(await sb.from('maintenance_schedules').insert(body).select().single().run());
    }
    if (method === 'PUT') {
      const {id:_,created_at,updated_at,live_status,asset_name,rig_name,company,assets,...u}=body;
      if (['Overdue','Due Soon'].includes(u.status)) u.status='Scheduled';
      return ok(await sb.from('maintenance_schedules').update(u).eq('id',id).select().single().run());
    }
    if (method === 'DELETE') { await sb.from('maintenance_schedules').delete().eq('id',id).run(); return ok({deleted:id}); }
  }

  // TRANSFERS
  if (resource === 'transfers') {
    if (method === 'POST' && id && action === 'approve') {
      const {role,action:decision,comment,approved_by} = body;
      if (!role||!decision||!comment) return json({success:false,error:'role, action and comment required'},400);
      const today = new Date().toISOString().slice(0,10);
      let upd={};
      if (role==='ops') {
        upd={ops_approved_by:approved_by,ops_approved_date:today,ops_action:decision,ops_comment:comment,
          status:decision==='approve'?'Ops Approved':decision==='reject'?'Rejected':'On Hold'};
      } else if (role==='mgr') {
        upd={mgr_approved_by:approved_by,mgr_approved_date:today,mgr_action:decision,mgr_comment:comment,
          status:decision==='approve'?'Completed':decision==='reject'?'Rejected':'On Hold'};
        if (decision==='approve') {
          const {data:tr}=await sb.from('transfers').select('*').eq('id',id).single().run();
          if (tr) { const au={location:tr.destination}; if(tr.dest_rig) au.rig_name=tr.dest_rig; if(tr.dest_company) au.company=tr.dest_company; await sb.from('assets').update(au).eq('asset_id',tr.asset_id).run(); }
        }
      } else return json({success:false,error:'role must be ops or mgr'},400);
      return ok(await sb.from('transfers').update(upd).eq('id',id).select().single().run());
    }
    if (method === 'GET') {
      let r = sb.from('transfers').select('*').order('created_at',false).limit(+(q.get('limit')||200));
      if (q.get('status'))   r=r.eq('status',   q.get('status'));
      if (q.get('priority')) r=r.eq('priority', q.get('priority'));
      return ok(await r.run());
    }
    if (method === 'POST') {
      if (!body.id) { const {count}=await sb.from('transfers').count().run(); body.id='TR-'+String((count||0)+1).padStart(3,'0'); }
      if (!body.request_date) body.request_date=new Date().toISOString().slice(0,10);
      if (!body.asset_name&&body.asset_id) { const {data:a}=await sb.from('assets').select('name,location').eq('asset_id',body.asset_id).single().run(); if(a){body.asset_name=a.name;if(!body.current_loc)body.current_loc=a.location;} }
      return ok(await sb.from('transfers').insert(body).select().single().run());
    }
  }

  // USERS
  if (resource === 'users') {
    if (method === 'GET')    return ok(await sb.from('app_users').select('*').order('name').run());
    if (method === 'POST')   return ok(await sb.from('app_users').insert(body).select().single().run());
    if (method === 'PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sb.from('app_users').update(u).eq('id',id).select().single().run()); }
    if (method === 'DELETE') { await sb.from('app_users').delete().eq('id',id).run(); return ok({deleted:id}); }
  }

  // NOTIFICATIONS
  if (resource === 'notifications') {
    if (method==='PATCH'&&id==='mark-all-read') return ok(await sb.from('notifications').update({is_read:true}).eq('is_read',false).select().run());
    if (method==='PATCH'&&id) return ok(await sb.from('notifications').update({is_read:true}).eq('id',id).select().single().run());
    if (method==='GET')    return ok(await sb.from('notifications').select('*').order('created_at',false).limit(50).run());
    if (method==='POST')   return ok(await sb.from('notifications').insert(body).select().single().run());
  }

  return json({success:false, error:`Route not found: ${method} ${path}`}, 404);
}

// ── Supabase REST client (pure fetch, no npm) ─────────────────────────────────
function supabase(supabaseUrl, serviceKey) {
  const base = supabaseUrl.replace(/\/$/, '') + '/rest/v1';
  const h = { 'apikey':serviceKey, 'Authorization':`Bearer ${serviceKey}`, 'Content-Type':'application/json', 'Prefer':'return=representation' };

  function q(table) {
    const s = { method:'GET', filters:[], select:'*', orderCol:null, orderAsc:true, lim:null, body:null, isSingle:false, isCount:false };
    const qb = {
      select:  (v)        => { s.select=v; return qb; },
      eq:      (c,v)      => { s.filters.push([c,`eq.${v}`]);    return qb; },
      ilike:   (c,v)      => { s.filters.push([c,`ilike.${v}`]); return qb; },
      order:   (c,asc=true)=>{ s.orderCol=c; s.orderAsc=asc; return qb; },
      limit:   (n)        => { s.lim=n; return qb; },
      single:  ()         => { s.isSingle=true; return qb; },
      count:   ()         => { s.isCount=true;  return qb; },
      insert:  (d)        => { s.method='POST';  s.body=d; return qb; },
      update:  (d)        => { s.method='PATCH'; s.body=d; return qb; },
      delete:  ()         => { s.method='DELETE'; return qb; },
      run: async () => {
        const u = new URL(`${base}/${table}`);
        u.searchParams.set('select', s.select);
        s.filters.forEach(([c,v]) => u.searchParams.append(c, v));
        if (s.orderCol) u.searchParams.set('order', `${s.orderCol}.${s.orderAsc?'asc':'desc'}`);
        if (s.isCount) u.searchParams.set('limit','0'); else if (s.lim) u.searchParams.set('limit',String(s.lim));
        const hh = {...h};
        if (s.isSingle) hh['Accept']='application/vnd.pgjson';
        if (s.isCount)  hh['Prefer']='count=exact';
        const resp = await fetch(u.toString(), { method:s.method, headers:hh, body:s.body?JSON.stringify(s.body):undefined });
        if (s.isCount) { const r=resp.headers.get('content-range')||'0/0'; return {count:parseInt(r.split('/')[1])||0,error:null}; }
        const text = await resp.text();
        let data; try { data=JSON.parse(text); } catch(_){ data=null; }
        if (!resp.ok) return { data:null, error:{ message: data?.message||data?.error||`HTTP ${resp.status}: ${text.slice(0,200)}` } };
        if (s.isSingle) return { data: Array.isArray(data) ? (data[0]??null) : data, error:null };
        return { data: data??[], error:null };
      },
    };
    return qb;
  }
  return { from: (table) => q(table) };
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function liveStatus(m) {
  if (['Completed','Cancelled','In Progress'].includes(m.status)) return m.status;
  const today=new Date(); today.setHours(0,0,0,0);
  const due=new Date(m.next_due);
  if (due<today) return 'Overdue';
  if (due-today<=(m.alert_days||14)*86400000) return 'Due Soon';
  return 'Scheduled';
}
function ok(r)        { if (r?.error) return err500(r.error); return json({success:true, data:r?.data??r}); }
function err500(e)    { return json({success:false, error:e?.message||String(e)}, 500); }
function json(b,s=200){ return cors(JSON.stringify(b),s); }
function cors(b,s=200){ return new Response(b,{status:s,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'GET,POST,PUT,PATCH,DELETE,OPTIONS','Access-Control-Allow-Headers':'Content-Type,x-api-key,x-user-role,x-user-name'}}); }
