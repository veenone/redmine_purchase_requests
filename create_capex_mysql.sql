-- SQL script to create CAPEX table for Redmine Purchase Requests plugin
-- This script will create the capex table and add the foreign key to purchase_requests

USE redmine;

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS capex;

-- Create the capex table
CREATE TABLE capex (
  id int(11) NOT NULL AUTO_INCREMENT,
  project_id int(11) NOT NULL,
  year int(11) NOT NULL,
  description varchar(255) NOT NULL,
  tpc_code varchar(50) NOT NULL,
  total_amount decimal(15,2) NOT NULL,
  currency varchar(3) NOT NULL DEFAULT 'USD',
  q1_amount decimal(15,2) NOT NULL DEFAULT 0.00,
  q2_amount decimal(15,2) NOT NULL DEFAULT 0.00,
  q3_amount decimal(15,2) NOT NULL DEFAULT 0.00,
  q4_amount decimal(15,2) NOT NULL DEFAULT 0.00,
  notes text,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  PRIMARY KEY (id),
  KEY index_capex_on_project_id (project_id),
  KEY index_capex_on_project_id_and_year (project_id, year),
  KEY index_capex_on_project_id_and_tpc_code (project_id, tpc_code),
  KEY index_capex_on_year (year),
  CONSTRAINT fk_capex_project_id FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add capex_id column to purchase_requests if it doesn't exist
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = 'redmine' 
                   AND TABLE_NAME = 'purchase_requests' 
                   AND COLUMN_NAME = 'capex_id');

SET @sql = IF(@col_exists = 0, 
  'ALTER TABLE purchase_requests ADD COLUMN capex_id int(11) NULL, ADD KEY index_purchase_requests_on_capex_id (capex_id), ADD CONSTRAINT fk_purchase_requests_capex_id FOREIGN KEY (capex_id) REFERENCES capex (id) ON DELETE SET NULL',
  'SELECT "capex_id column already exists" as status');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Verify table creation
SELECT 'CAPEX table created successfully' as status;
DESCRIBE capex;
