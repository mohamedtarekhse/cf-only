// Asset Management Frontend - Main Application
const API_BASE = import.meta.env.VITE_API_URL || '/api';

let currentUser = null;
let token = null;

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
  checkAuth();
  setupEventListeners();
});

// Check authentication on load
async function checkAuth() {
  token = localStorage.getItem('token');
  if (token) {
    try {
      const res = await fetch(`${API_BASE}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        currentUser = data.data;
        showApp();
      } else {
        showLogin();
      }
    } catch (err) {
      showLogin();
    }
  } else {
    showLogin();
  }
}

// Setup event listeners
function setupEventListeners() {
  // Login form
  document.getElementById('loginForm').addEventListener('submit', handleLogin);
  
  // Logout
  document.getElementById('logoutBtn').addEventListener('click', handleLogout);
  
  // Navigation tabs
  document.querySelectorAll('.nav-tab').forEach(tab => {
    tab.addEventListener('click', (e) => {
      const section = e.target.dataset.section;
      switchSection(section);
    });
  });
  
  // Asset filters
  document.getElementById('assetSearch').addEventListener('input', loadAssets);
  document.getElementById('assetStatusFilter').addEventListener('change', loadAssets);
}

// Handle login
async function handleLogin(e) {
  e.preventDefault();
  const email = document.getElementById('email').value;
  const password = document.getElementById('password').value;
  const errorEl = document.getElementById('loginError');
  
  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    
    const data = await res.json();
    
    if (data.success) {
      token = data.data.token;
      currentUser = data.data.user;
      localStorage.setItem('token', token);
      errorEl.classList.add('hidden');
      showApp();
      loadDashboard();
    } else {
      errorEl.textContent = data.error || 'Login failed';
      errorEl.classList.remove('hidden');
    }
  } catch (err) {
    errorEl.textContent = 'Network error. Please try again.';
    errorEl.classList.remove('hidden');
  }
}

// Handle logout
function handleLogout() {
  token = null;
  currentUser = null;
  localStorage.removeItem('token');
  showLogin();
}

// Show login view
function showLogin() {
  document.getElementById('loginView').classList.remove('hidden');
  document.getElementById('appView').classList.add('hidden');
}

// Show app view
function showApp() {
  document.getElementById('loginView').classList.add('hidden');
  document.getElementById('appView').classList.remove('hidden');
  
  if (currentUser) {
    document.getElementById('userName').textContent = currentUser.name;
    document.getElementById('userAvatar').textContent = currentUser.initials || currentUser.name.charAt(0);
    document.getElementById('userAvatar').style.background = currentUser.color || '#0070F2';
  }
  
  loadDashboard();
}

// Switch section
function switchSection(section) {
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
  
  document.getElementById(section).classList.add('active');
  document.querySelector(`[data-section="${section}"]`).classList.add('active');
  
  // Load section data
  switch(section) {
    case 'dashboard': loadDashboard(); break;
    case 'assets': loadAssets(); break;
    case 'rigs': loadRigs(); break;
    case 'contracts': loadContracts(); break;
    case 'transfers': loadTransfers(); break;
    case 'maintenance': loadMaintenance(); break;
    case 'users': loadUsers(); break;
  }
}

// Load dashboard
async function loadDashboard() {
  const content = document.getElementById('dashboardContent');
  content.innerHTML = '<p>Loading...</p>';
  
  try {
    const [assetsRes, rigsRes, transfersRes] = await Promise.all([
      fetch(`${API_BASE}/assets`, { headers: { 'Authorization': `Bearer ${token}` } }),
      fetch(`${API_BASE}/rigs`, { headers: { 'Authorization': `Bearer ${token}` } }),
      fetch(`${API_BASE}/transfers`, { headers: { 'Authorization': `Bearer ${token}` } })
    ]);
    
    const assets = await assetsRes.json();
    const rigs = await rigsRes.json();
    const transfers = await transfersRes.json();
    
    const assetCount = assets.data?.length || 0;
    const rigCount = rigs.data?.length || 0;
    const pendingTransfers = transfers.data?.filter(t => t.status === 'Pending').length || 0;
    
    content.innerHTML = `
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;">
        <div class="card" style="padding:16px;text-align:center;">
          <div style="font-size:32px;font-weight:700;color:var(--sap-blue);">${assetCount}</div>
          <div style="color:var(--sap-text-muted);">Total Assets</div>
        </div>
        <div class="card" style="padding:16px;text-align:center;">
          <div style="font-size:32px;font-weight:700;color:#2E7D32;">${rigCount}</div>
          <div style="color:var(--sap-text-muted);">Active Rigs</div>
        </div>
        <div class="card" style="padding:16px;text-align:center;">
          <div style="font-size:32px;font-weight:700;color:#EF6C00;">${pendingTransfers}</div>
          <div style="color:var(--sap-text-muted);">Pending Transfers</div>
        </div>
      </div>
    `;
  } catch (err) {
    content.innerHTML = '<p>Error loading dashboard</p>';
  }
}

// Load assets
async function loadAssets() {
  const search = document.getElementById('assetSearch').value;
  const status = document.getElementById('assetStatusFilter').value;
  
  let url = `${API_BASE}/assets?`;
  if (search) url += `&search=${encodeURIComponent(search)}`;
  if (status) url += `&status=${encodeURIComponent(status)}`;
  
  try {
    const res = await fetch(url, { headers: { 'Authorization': `Bearer ${token}` } });
    const data = await res.json();
    
    const tbody = document.getElementById('assetsTable');
    document.getElementById('assetCount').textContent = `(${data.data?.length || 0})`;
    
    if (!data.data || data.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;">No assets found</td></tr>';
      return;
    }
    
    tbody.innerHTML = data.data.map(asset => `
      <tr>
        <td>${asset.asset_id}</td>
        <td>${asset.name}</td>
        <td>${asset.category || '-'}</td>
        <td>${asset.rig_name || '-'}</td>
        <td>${asset.location || '-'}</td>
        <td><span class="badge badge-${asset.status?.toLowerCase()}">${asset.status}</span></td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Error loading assets:', err);
  }
}

// Load rigs
async function loadRigs() {
  try {
    const res = await fetch(`${API_BASE}/rigs`, { headers: { 'Authorization': `Bearer ${token}` } });
    const data = await res.json();
    
    const tbody = document.getElementById('rigsTable');
    tbody.innerHTML = data.data?.map(rig => `
      <tr>
        <td>${rig.id}</td>
        <td>${rig.name}</td>
        <td>${rig.type || '-'}</td>
        <td>${rig.location || '-'}</td>
        <td><span class="badge badge-${rig.status?.toLowerCase()}">${rig.status}</span></td>
      </tr>
    `).join('') || '<tr><td colspan="5">No rigs found</td></tr>';
  } catch (err) {
    console.error('Error loading rigs:', err);
  }
}

// Load contracts
async function loadContracts() {
  try {
    const res = await fetch(`${API_BASE}/contracts`, { headers: { 'Authorization': `Bearer ${token}` } });
    const data = await res.json();
    
    const tbody = document.getElementById('contractsTable');
    tbody.innerHTML = data.data?.map(c => `
      <tr>
        <td>${c.id}</td>
        <td>${c.rig}</td>
        <td>$${(c.value || 0).toLocaleString()}</td>
        <td>${c.start_date || '-'}</td>
        <td>${c.end_date || '-'}</td>
        <td><span class="badge badge-${c.status?.toLowerCase()}">${c.status}</span></td>
      </tr>
    `).join('') || '<tr><td colspan="6">No contracts found</td></tr>';
  } catch (err) {
    console.error('Error loading contracts:', err);
  }
}

// Load transfers
async function loadTransfers() {
  try {
    const res = await fetch(`${API_BASE}/transfers`, { headers: { 'Authorization': `Bearer ${token}` } });
    const data = await res.json();
    
    const tbody = document.getElementById('transfersTable');
    tbody.innerHTML = data.data?.map(t => `
      <tr>
        <td>${t.id}</td>
        <td>${t.asset_name || t.asset_id}</td>
        <td>${t.current_loc || '-'}</td>
        <td>${t.destination}</td>
        <td><span class="badge">${t.status}</span></td>
        <td>${t.request_date || '-'}</td>
      </tr>
    `).join('') || '<tr><td colspan="6">No transfers found</td></tr>';
  } catch (err) {
    console.error('Error loading transfers:', err);
  }
}

// Load maintenance
async function loadMaintenance() {
  try {
    const res = await fetch(`${API_BASE}/maintenance/schedules`, { headers: { 'Authorization': `Bearer ${token}` } });
    const data = await res.json();
    
    const tbody = document.getElementById('maintenanceTable');
    tbody.innerHTML = data.data?.map(m => `
      <tr>
        <td>${m.id}</td>
        <td>${m.asset_name || m.asset_id}</td>
        <td>${m.task?.substring(0, 40) || '-'}</td>
        <td>${m.next_due || '-'}</td>
        <td><span class="badge">${m.priority}</span></td>
        <td><span class="badge badge-${m.status?.toLowerCase()}">${m.status}</span></td>
      </tr>
    `).join('') || '<tr><td colspan="6">No maintenance schedules found</td></tr>';
  } catch (err) {
    console.error('Error loading maintenance:', err);
  }
}

// Load users
async function loadUsers() {
  try {
    const res = await fetch(`${API_BASE}/users`, { headers: { 'Authorization': `Bearer ${token}` } });
    const data = await res.json();
    
    const tbody = document.getElementById('usersTable');
    tbody.innerHTML = data.data?.map(u => `
      <tr>
        <td>${u.name}</td>
        <td>${u.email}</td>
        <td>${u.role}</td>
        <td>${u.dept || '-'}</td>
        <td><span class="badge badge-${u.active ? 'active' : 'inactive'}">${u.active ? 'Active' : 'Inactive'}</span></td>
      </tr>
    `).join('') || '<tr><td colspan="5">No users found</td></tr>';
  } catch (err) {
    console.error('Error loading users:', err);
  }
}

// Placeholder modal functions (to be implemented)
window.showAddAssetModal = () => alert('Add Asset modal - to be implemented');
window.showAddRigModal = () => alert('Add Rig modal - to be implemented');
window.showNewTransferModal = () => alert('New Transfer modal - to be implemented');
window.showAddUserModal = () => alert('Add User modal - to be implemented');
