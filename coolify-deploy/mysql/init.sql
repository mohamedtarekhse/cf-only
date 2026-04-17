-- ============================================================================
-- Asset Management System - MySQL Schema
-- Converted from PostgreSQL/Supabase for MySQL 8.0+
-- ============================================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

-- ============================================================================
-- RIGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS rigs (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(100),
  location TEXT,
  depth VARCHAR(50),
  hp INT,
  status VARCHAR(50) DEFAULT 'Active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_rigs_status (status),
  INDEX idx_rigs_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CONTRACTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS contracts (
  id VARCHAR(50) PRIMARY KEY,
  rig VARCHAR(255) NOT NULL,
  value DECIMAL(15,2),
  start_date DATE,
  end_date DATE,
  status VARCHAR(50) DEFAULT 'Active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_contracts_status (status),
  INDEX idx_contracts_dates (start_date, end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- ASSETS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS assets (
  asset_id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(100),
  rig_name VARCHAR(255),
  location VARCHAR(255),
  status VARCHAR(50) DEFAULT 'Active',
  value DECIMAL(15,2),
  acquisition_date DATE,
  serial VARCHAR(100),
  notes TEXT,
  last_inspection DATE,
  inspection_type VARCHAR(100),
  cert_link TEXT,
  client_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_assets_status (status),
  INDEX idx_assets_rig (rig_name),
  INDEX idx_assets_location (location),
  INDEX idx_assets_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CONTRACT_ASSETS TABLE (Junction Table)
-- ============================================================================
CREATE TABLE IF NOT EXISTS contract_assets (
  contract_id VARCHAR(50) NOT NULL,
  asset_id VARCHAR(50) NOT NULL,
  PRIMARY KEY (contract_id, asset_id),
  FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE CASCADE,
  FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
  INDEX idx_contract_assets_asset (asset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- BOM_ITEMS TABLE (Bill of Materials)
-- ============================================================================
CREATE TABLE IF NOT EXISTS bom_items (
  id VARCHAR(50) PRIMARY KEY,
  asset_id VARCHAR(50) NOT NULL,
  parent_id VARCHAR(50),
  name VARCHAR(255) NOT NULL,
  part_no VARCHAR(100),
  type ENUM('Serialized', 'Bulk', 'Assembly') DEFAULT 'Bulk',
  serial VARCHAR(100),
  manufacturer VARCHAR(255),
  qty DECIMAL(15,3) DEFAULT 1,
  uom VARCHAR(20) DEFAULT 'EA',
  unit_cost DECIMAL(15,2),
  lead_time INT DEFAULT 0,
  status VARCHAR(50) DEFAULT 'Active',
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
  INDEX idx_bom_asset (asset_id),
  INDEX idx_bom_parent (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CERTIFICATES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS certificates (
  cert_id VARCHAR(50) PRIMARY KEY,
  asset_id VARCHAR(50) NOT NULL,
  inspection_type VARCHAR(100),
  last_inspection DATE,
  next_inspection DATE,
  validity_days INT,
  alert_days INT DEFAULT 30,
  cert_link TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
  INDEX idx_cert_asset (asset_id),
  INDEX idx_cert_next_inspection (next_inspection)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- MAINTENANCE_SCHEDULES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id VARCHAR(50) PRIMARY KEY,
  asset_id VARCHAR(50) NOT NULL,
  task TEXT NOT NULL,
  type ENUM('Preventive', 'Corrective', 'Predictive', 'Inspection') DEFAULT 'Preventive',
  freq INT DEFAULT 90,
  last_done DATE,
  next_due DATE,
  tech VARCHAR(255),
  hours DECIMAL(10,2),
  cost DECIMAL(15,2),
  priority ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium',
  status ENUM('Scheduled', 'Completed', 'Overdue', 'Due Soon', 'Cancelled') DEFAULT 'Scheduled',
  alert_days INT DEFAULT 7,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
  INDEX idx_maint_asset (asset_id),
  INDEX idx_maint_next_due (next_due),
  INDEX idx_maint_status (status),
  INDEX idx_maint_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- MAINTENANCE_LOGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS maintenance_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  schedule_id VARCHAR(50) NOT NULL,
  completion_date DATE NOT NULL,
  performed_by VARCHAR(255) NOT NULL,
  hours DECIMAL(10,2),
  cost DECIMAL(15,2),
  parts_used TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (schedule_id) REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
  INDEX idx_log_schedule (schedule_id),
  INDEX idx_log_completion (completion_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TRANSFERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS transfers (
  id VARCHAR(50) PRIMARY KEY,
  asset_id VARCHAR(50) NOT NULL,
  asset_name VARCHAR(255),
  current_loc VARCHAR(255),
  destination VARCHAR(255) NOT NULL,
  dest_rig VARCHAR(255),
  priority ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium',
  type VARCHAR(50),
  requested_by VARCHAR(255),
  request_date DATE,
  required_date DATE,
  reason TEXT,
  instructions TEXT,
  status VARCHAR(50) DEFAULT 'Pending',
  supt_approved_by VARCHAR(255),
  supt_approved_date DATE,
  supt_action VARCHAR(20),
  supt_comment TEXT,
  ops_approved_by VARCHAR(255),
  ops_approved_date DATE,
  ops_action VARCHAR(20),
  ops_comment TEXT,
  mgr_approved_by VARCHAR(255),
  mgr_approved_date DATE,
  mgr_action VARCHAR(20),
  mgr_comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_transfers_status (status),
  INDEX idx_transfers_asset (asset_id),
  INDEX idx_transfers_request_date (request_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- APP_USERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS app_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  role ENUM('Admin', 'Manager', 'Superintendent', 'Drilling Manager', 'Asset Manager', 'Maintenance Manager', 'Project Manager', 'Engineer', 'Assistant', 'Viewer', 'Editor') DEFAULT 'Viewer',
  dept VARCHAR(100),
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255),
  color VARCHAR(20) DEFAULT '#0070F2',
  initials VARCHAR(10),
  active BOOLEAN DEFAULT TRUE,
  client_id VARCHAR(100),
  password_changed_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_email (email),
  INDEX idx_users_role (role),
  INDEX idx_users_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- AUTH_LOGIN_EVENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS auth_login_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  email VARCHAR(255) NOT NULL,
  logged_in_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_address VARCHAR(45),
  user_agent TEXT,
  client_id VARCHAR(100),
  status ENUM('success', 'failed', 'locked', 'revoked') DEFAULT 'success',
  FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE SET NULL,
  INDEX idx_login_user (user_id, logged_in_at DESC),
  INDEX idx_login_client (client_id, logged_in_at DESC),
  INDEX idx_login_email (email, logged_in_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- NOTIFICATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  icon VARCHAR(100),
  kind ENUM('warning', 'info', 'error', 'success') DEFAULT 'info',
  title VARCHAR(255) NOT NULL,
  description TEXT,
  time_label VARCHAR(50),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_notifications_kind (kind),
  INDEX idx_notifications_read (is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- INSPECTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS inspections (
  id VARCHAR(50) PRIMARY KEY,
  inspection_type VARCHAR(100),
  rig_name VARCHAR(255),
  start_date DATE,
  end_date DATE,
  inspector VARCHAR(255),
  status VARCHAR(50) DEFAULT 'Scheduled',
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_inspections_type (inspection_type),
  INDEX idx_inspections_rig (rig_name),
  INDEX idx_inspections_dates (start_date, end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PROJECTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS projects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  project_id VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  rig_name VARCHAR(255),
  status VARCHAR(50) DEFAULT 'Active',
  priority ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium',
  budget DECIMAL(15,2),
  spent DECIMAL(15,2) DEFAULT 0,
  start_date DATE,
  end_date DATE,
  manager VARCHAR(255),
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_projects_status (status),
  INDEX idx_projects_rig (rig_name),
  INDEX idx_projects_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- WORKSHOPS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS workshops (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  location VARCHAR(255),
  status VARCHAR(50) DEFAULT 'Active',
  assigned_rig VARCHAR(255),
  capacity INT,
  supervisor VARCHAR(255),
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_workshops_status (status),
  INDEX idx_workshops_rig (assigned_rig)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PUSH_SUBSCRIPTIONS TABLE (for Web Push Notifications)
-- ============================================================================
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  client_id VARCHAR(100),
  endpoint TEXT NOT NULL,
  p256dh VARCHAR(255) NOT NULL,
  auth VARCHAR(255) NOT NULL,
  platform VARCHAR(50),
  user_agent TEXT,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
  INDEX idx_push_user (user_id),
  INDEX idx_push_client (client_id),
  INDEX idx_push_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

COMMIT;
