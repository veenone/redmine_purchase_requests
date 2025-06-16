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
  KEY idx_project_id (project_id),
  KEY idx_year (year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
