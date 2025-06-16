<?php
// Simple PHP script to create CAPEX table
$host = 'localhost';
$username = 'redmine';
$password = 'secretPassword';
$database = 'redmine';

echo "Connecting to MySQL database...\n";

try {
    $pdo = new PDO("mysql:host=$host;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "✓ Connected to database: $database\n";
    
    // Drop table if exists
    $pdo->exec("DROP TABLE IF EXISTS capex");
    echo "✓ Dropped existing CAPEX table (if any)\n";
    
    // Create CAPEX table
    $sql = "CREATE TABLE capex (
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
        KEY index_capex_on_year (year),
        KEY index_capex_on_project_id_and_year (project_id, year),
        KEY index_capex_on_project_id_and_tpc_code (project_id, tpc_code)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
    
    $pdo->exec($sql);
    echo "✓ CAPEX table created successfully\n";
    
    // Check if capex_id column exists in purchase_requests
    $stmt = $pdo->query("SHOW COLUMNS FROM purchase_requests LIKE 'capex_id'");
    if ($stmt->rowCount() == 0) {
        // Add capex_id column
        $pdo->exec("ALTER TABLE purchase_requests ADD COLUMN capex_id int(11) NULL");
        $pdo->exec("ALTER TABLE purchase_requests ADD KEY index_purchase_requests_on_capex_id (capex_id)");
        echo "✓ Added capex_id column to purchase_requests\n";
    } else {
        echo "✓ capex_id column already exists in purchase_requests\n";
    }
    
    // Verify table creation
    $stmt = $pdo->query("DESCRIBE capex");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "✓ Verification: CAPEX table created with " . count($columns) . " columns:\n";
    foreach ($columns as $column) {
        echo "  - {$column['Field']} ({$column['Type']})\n";
    }
    
    echo "\n🎉 CAPEX database setup completed successfully!\n";
    echo "You can now access the CAPEX menu in Redmine.\n";
    
} catch (PDOException $e) {
    echo "✗ Error: " . $e->getMessage() . "\n";
}
?>
