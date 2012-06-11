<?php

class Database
{
    const TEST_TABLE = "test";
    const ACTIVITY_TABLE = "system_activity";
    const USER = "root";
    const PASSWORD = "ettore";
    const DATABASE = "php_performance";

    private static $db;

    private function __construct() {}

    public static function GetConnection()
    {
        if (!isset(self::$db))
        {
            // Connect to DB
            try {
                self::$db = new PDO("mysql:host=localhost;dbname=". self::DATABASE, self::USER, self::PASSWORD);
                self::$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            } catch (PDOException $e) {
                print "Error: ". $e->getMessage() ."<br />";
                die();
            }
        }

        return self::$db;
    }
}

?>
