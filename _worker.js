/**
 * _worker.js — Cloudflare Pages Worker
 * Calls Supabase REST API with explicit fetch() — no custom query builder.
 *
 * Cloudflare Pages → Settings → Environment Variables:
 *   SUPABASE_URL              = https://tetbgjfltggmejqwntez.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY = sb_publishable_uSHDoMEafLUF1FzAQCVn0Q_JBKTd1Br
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method === 'OPTIONS') return respond(null, 204);
    if (path === '/health') return respond({ status:'ok', service:'Asset Management (Cloudflare Worker)', ts:new Date().toISOString() });

    if (path.startsWith('/api')) {
      if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY)
        return respond({ success:false, error:'Supabase secrets not configured in Cloudflare Pages environment variables.' }, 500);
      try {
        return await router(path, method, url, request, env.SUPABASE_URL.replace(/\/$/,''), env.SUPABASE_SERVICE_ROLE_KEY);
      } catch(err) {
        console.error(err);
        return respond({ success:false, error: err.message||'Internal error' }, 500);
      }
    }

    return env.ASSETS.fetch(request);
  }
};

// ── Direct Supabase REST calls ────────────────────────────────────────────────

function authHeaders(key, extra={}) {
  return { 'apikey':key, 'Authorization':`Bearer ${key}`, 'Content-Type':'application/json', ...extra };
}

async function sbGet(base, key, table, { select='*', filters={}, order=null, limit=null, single=false }={}) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', select);
  for (const [k,v] of Object.entries(filters)) u.searchParams.append(k, v);
  if (order) u.searchParams.set('order', order);
  if (limit) u.searchParams.set('limit', String(limit));
  const h = authHeaders(key);
  if (single) h['Accept'] = 'application/vnd.pgjson';
  const r = await fetch(u.toString(), { headers:h });
  return parseRes(r, single);
}

async function sbPost(base, key, table, body) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', '*');
  const r = await fetch(u.toString(), { method:'POST', headers:authHeaders(key,{'Prefer':'return=representation'}), body:JSON.stringify(body) });
  return parseRes(r, true);
}

async function sbPatch(base, key, table, filters, body) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select', '*');
  for (const [k,v] of Object.entries(filters)) u.searchParams.append(k, v);
  const r = await fetch(u.toString(), { method:'PATCH', headers:authHeaders(key,{'Prefer':'return=representation'}), body:JSON.stringify(body) });
  return parseRes(r, true);
}

async function sbDelete(base, key, table, filters) {
  const u = new URL(`${base}/rest/v1/${table}`);
  for (const [k,v] of Object.entries(filters)) u.searchParams.append(k, v);
  const r = await fetch(u.toString(), { method:'DELETE', headers:authHeaders(key,{'Prefer':'return=minimal'}) });
  if (r.ok || r.status===204) return { error:null };
  const t = await r.text(); let m; try{m=JSON.parse(t)?.message}catch(_){m=t}
  return { error:{ message:`${r.status}: ${m}` } };
}

async function sbCount(base, key, table) {
  const u = new URL(`${base}/rest/v1/${table}`);
  u.searchParams.set('select','*'); u.searchParams.set('limit','0');
  const r = await fetch(u.toString(), { headers:authHeaders(key,{'Prefer':'count=exact'}) });
  return parseInt((r.headers.get('content-range')||'0/0').split('/')[1])||0;
}

async function parseRes(r, single) {
  const text = await r.text();
  let data; try{data=JSON.parse(text)}catch(_){data=null}
  if (!r.ok) return { data:null, error:{ message: data?.message||data?.error||`HTTP ${r.status}: ${text.slice(0,300)}` }};
  if (single) return { data: Array.isArray(data)?(data[0]??null):data, error:null };
  return { data: data??[], error:null };
}

// ── Router ────────────────────────────────────────────────────────────────────

async function router(path, method, url, request, SB, KEY) {
  const q    = url.searchParams;
  const seg  = path.replace(/^\/api\/?/,'').split('/');
  const res  = seg[0];
  const id   = seg[1];
  const act  = seg[2];
  const body = ['POST','PUT','PATCH'].includes(method) ? await request.json().catch(()=>({})) : {};

  // ASSETS
  if (res==='assets') {
    if (method==='GET'&&!id) {
      const f={};
      if(q.get('status'))   f.status  =`eq.${q.get('status')}`;
      if(q.get('category')) f.category=`eq.${q.get('category')}`;
      if(q.get('company'))  f.company =`eq.${q.get('company')}`;
      if(q.get('rig_name')) f.rig_name=`eq.${q.get('rig_name')}`;
      if(q.get('search'))   f.name    =`ilike.%${q.get('search')}%`;
      return ok(await sbGet(SB,KEY,'assets',{filters:f,order:'name.asc',limit:+(q.get('limit')||500)}));
    }
    if(method==='GET')    return ok(await sbGet(SB,KEY,'assets',{filters:{asset_id:`eq.${id}`},single:true}));
    if(method==='POST')   return ok(await sbPost(SB,KEY,'assets',body));
    if(method==='PUT')  { const {asset_id,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'assets',{asset_id:`eq.${id}`},u)); }
    if(method==='PATCH')  return ok(await sbPatch(SB,KEY,'assets',{asset_id:`eq.${id}`},body));
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'assets',{asset_id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // RIGS
  if (res==='rigs') {
    if(method==='GET'&&!id) return ok(await sbGet(SB,KEY,'rigs',{order:'name.asc'}));
    if(method==='GET')    return ok(await sbGet(SB,KEY,'rigs',{filters:{id:`eq.${id}`},single:true}));
    if(method==='POST')   return ok(await sbPost(SB,KEY,'rigs',body));
    if(method==='PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'rigs',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'rigs',{id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // COMPANIES
  if (res==='companies') {
    if(method==='GET')    return ok(await sbGet(SB,KEY,'companies',{order:'name.asc'}));
    if(method==='POST')   return ok(await sbPost(SB,KEY,'companies',body));
    if(method==='PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'companies',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'companies',{id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
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
      const {data,error}=await sbGet(SB,KEY,'certificates',{select:'*, assets(name,serial,rig_name,category)',order:'cert_id.asc',limit:+(q.get('limit')||500)});
      if(error) return err500(error);
      return ok((data||[]).map(c=>({...c,asset_name:c.assets?.name,asset_serial:c.assets?.serial,rig_name:c.assets?.rig_name,category:c.assets?.category,assets:undefined})));
    }
    if(method==='GET')    return ok(await sbGet(SB,KEY,'certificates',{filters:{cert_id:`eq.${id}`},single:true}));
    if(method==='POST') { if(!body.cert_id) body.cert_id='CERT-'+String((await sbCount(SB,KEY,'certificates'))+1).padStart(3,'0'); return ok(await sbPost(SB,KEY,'certificates',body)); }
    if(method==='PUT')  { const {cert_id,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'certificates',{cert_id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'certificates',{cert_id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
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
      const {data,error}=await sbGet(SB,KEY,'maintenance_schedules',{select:'*, assets(name,rig_name,company)',order:'next_due.asc',limit:+(q.get('limit')||500)});
      if(error) return err500(error);
      let rows=(data||[]).map(m=>({...m,asset_name:m.assets?.name,rig_name:m.assets?.rig_name,company:m.assets?.company,assets:undefined,live_status:liveStatus(m)}));
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
    if(method==='PUT'){ const {id:_,created_at,updated_at,live_status,asset_name,rig_name,company,assets,...u}=body; if(['Overdue','Due Soon'].includes(u.status)) u.status='Scheduled'; return ok(await sbPatch(SB,KEY,'maintenance_schedules',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'maintenance_schedules',{id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // TRANSFERS
  if (res==='transfers') {
    if(method==='POST'&&id&&act==='approve'){
      const {role,action:decision,comment,approved_by}=body;
      if(!role||!decision||!comment) return respond({success:false,error:'role, action and comment required'},400);
      const today=new Date().toISOString().slice(0,10);
      let patch={};
      if(role==='ops'){
        patch={ops_approved_by:approved_by,ops_approved_date:today,ops_action:decision,ops_comment:comment,
          status:decision==='approve'?'Ops Approved':decision==='reject'?'Rejected':'On Hold'};
      } else if(role==='mgr'){
        patch={mgr_approved_by:approved_by,mgr_approved_date:today,mgr_action:decision,mgr_comment:comment,
          status:decision==='approve'?'Completed':decision==='reject'?'Rejected':'On Hold'};
        if(decision==='approve'){
          const {data:tr}=await sbGet(SB,KEY,'transfers',{filters:{id:`eq.${id}`},single:true});
          if(tr){ const au={location:tr.destination}; if(tr.dest_rig) au.rig_name=tr.dest_rig; if(tr.dest_company) au.company=tr.dest_company; await sbPatch(SB,KEY,'assets',{asset_id:`eq.${tr.asset_id}`},au); }
        }
      } else return respond({success:false,error:'role must be ops or mgr'},400);
      return ok(await sbPatch(SB,KEY,'transfers',{id:`eq.${id}`},patch));
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
      return ok(await sbPost(SB,KEY,'transfers',body));
    }
  }

  // USERS
  if (res==='users') {
    if(method==='GET')    return ok(await sbGet(SB,KEY,'app_users',{select:'id,name,role,dept,email,color,initials,password,active',order:'name.asc'}));
    if(method==='POST')   return ok(await sbPost(SB,KEY,'app_users',body));
    if(method==='PUT')  { const {id:_,created_at,updated_at,...u}=body; return ok(await sbPatch(SB,KEY,'app_users',{id:`eq.${id}`},u)); }
    if(method==='DELETE'){const r=await sbDelete(SB,KEY,'app_users',{id:`eq.${id}`});if(r.error)return err500(r.error);return ok({deleted:id});}
  }

  // NOTIFICATIONS
  if (res==='notifications') {
    if(method==='PATCH'&&id==='mark-all-read') return ok(await sbPatch(SB,KEY,'notifications',{is_read:`eq.false`},{is_read:true}));
    if(method==='PATCH'&&id) return ok(await sbPatch(SB,KEY,'notifications',{id:`eq.${id}`},{is_read:true}));
    if(method==='GET')   return ok(await sbGet(SB,KEY,'notifications',{order:'created_at.desc',limit:50}));
    if(method==='POST')  return ok(await sbPost(SB,KEY,'notifications',body));
  }

  return respond({ success:false, error:`Route not found: ${method} ${path}` }, 404);
}

// ── Helpers ───────────────────────────────────────────────────────────────────
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
    'Access-Control-Allow-Origin':'*',
    'Access-Control-Allow-Methods':'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers':'Content-Type,x-api-key,x-user-role,x-user-name',
  }});
}
