<?php
// Simple database test
$output = array();

try {
    // Read database config
    $database_yml = '/opt/redmine/config/database.yml';
    if (file_exists($database_yml)) {
        $output[] = "Database config exists";
        
        // Try to connect to MySQL
        $config = yaml_parse_file($database_yml);
        if (isset($config['production'])) {
            $db_config = $config['production'];
            $output[] = "Found production config";
            
            $host = $db_config['host'] ?? 'localhost';
            $database = $db_config['database'] ?? '';
            $username = $db_config['username'] ?? '';
            $password = $db_config['password'] ?? '';
            
            $mysqli = new mysqli($host, $username, $password, $database);
            
            if ($mysqli->connect_error) {
                $output[] = "Connection failed: " . $mysqli->connect_error;
            } else {
                $output[] = "Database connected successfully";
                
                // Check if capex table exists
                $result = $mysqli->query("SHOW TABLES LIKE 'capex'");
                if ($result && $result->num_rows > 0) {
                    $output[] = "CAPEX table exists";
                    
                    // Get column info
                    $result = $mysqli->query("SHOW COLUMNS FROM capex");
                    $columns = array();
                    while ($row = $result->fetch_assoc()) {
                        $columns[] = $row['Field'];
                    }
                    $output[] = "CAPEX columns: " . implode(', ', $columns);
                } else {
                    $output[] = "CAPEX table does not exist";
                }
                
                // Check purchase_requests table
                $result = $mysqli->query("SHOW TABLES LIKE 'purchase_requests'");
                if ($result && $result->num_rows > 0) {
                    $output[] = "Purchase requests table exists";
                    
                    $result = $mysqli->query("SHOW COLUMNS FROM purchase_requests LIKE 'capex_id'");
                    if ($result && $result->num_rows > 0) {
                        $output[] = "Purchase requests has capex_id column";
                    } else {
                        $output[] = "Purchase requests missing capex_id column";
                    }
                } else {
                    $output[] = "Purchase requests table does not exist";
                }
            }
            
            $mysqli->close();
        }
    } else {
        $output[] = "Database config not found";
    }
} catch (Exception $e) {
    $output[] = "Error: " . $e->getMessage();
}

// Write results
file_put_contents('/tmp/db_test_results.txt', implode("\n", $output));
echo "Database test completed. Results written to /tmp/db_test_results.txt\n";
?>
